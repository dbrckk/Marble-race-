#!/usr/bin/env bash
set -euo pipefail
ROOT="${GAME_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
G="${GODOT_BIN:-godot}"
PORT="${GATEWAY_TEST_PORT:-29027}"
INTERNAL="${GATEWAY_TEST_INTERNAL:-29028}"
DIR="${GATEWAY_LOG_DIR:-${TMPDIR:-/tmp}/marble-gateway-check}"
mkdir -p "$DIR"
GODOT_BIN="$G" GAME_DIR="$ROOT" PORT="$PORT" GODOT_INTERNAL_PORT="$INTERNAL" python3 -u "$ROOT/server/edge_gateway.py" > "$DIR/server.log" 2>&1 &
SERVER=$!
pids=("$SERVER")
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
ready=0
for t in $(seq 1 35); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" >"$DIR/health.json"; then
    ready=1;break
  fi
  sleep 1
done
if [[ $ready != 1 ]]; then tail -35 "$DIR/server.log";exit 1;fi
grep -Fq '"status":"ok"' "$DIR/health.json"
# Probe must be 404 for unknown HTTP routes, without invoking Godot's WS parser.
status=$(curl --silent -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/not-a-websocket")
test "$status" = "404"
echo "EDGE_HTTP_HEALTH_PASS: healthy=200 unknown=404"
timeout 70s "$G" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="ws://127.0.0.1:$PORT" --mode=public > "$DIR/client1.log" 2>&1 &
pids+=("$!")
timeout 70s "$G" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="ws://127.0.0.1:$PORT" --mode=public > "$DIR/client2.log" 2>&1 &
pids+=("$!")
wait "${pids[1]}"
wait "${pids[2]}"
grep -F "ONLINE_CLIENT_PASS" "$DIR/client1.log"
grep -F "ONLINE_CLIENT_PASS" "$DIR/client2.log"
if grep -E "Missing or invalid header|Not enough response headers" "$DIR/server.log"; then
 echo "Unwanted Godot HTTP handshake errors";exit 1
fi
echo "EDGE_WEBSOCKET_PROXY_PASS: public HTTP gateway + 2 real Godot clients"
