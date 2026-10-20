#!/usr/bin/env bash
# Manual end-to-end check over an actual public WSS endpoint, not localhost.
set -euo pipefail
ROOT="${GAME_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
GODOT_BIN="${GODOT_BIN:-godot}"
URL="${WORLD_URL:-$(tr -d '\r\n' < "$ROOT/config/online_server.txt")}"
LOG_DIR="${PUBLIC_NETWORK_LOG_DIR:-/tmp/marble-public-online-qa}"
mkdir -p "$LOG_DIR"
if [[ "$URL" != wss://* ]]; then
  echo "Refusing non-TLS public WebSocket endpoint: $URL" >&2
  exit 3
fi
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
timeout 150s "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="$URL" --mode=public > "$LOG_DIR/client1.log" 2>&1 &
pids+=("$!")
timeout 150s "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="$URL" --mode=public > "$LOG_DIR/client2.log" 2>&1 &
pids+=("$!")
set +e
wait "${pids[0]}"; result1=$?
wait "${pids[1]}"; result2=$?
set -e
for i in 1 2; do
  grep -E 'ONLINE_CLIENT|ERROR:|SCRIPT ERROR:' "$LOG_DIR/client$i.log" | tail -12 || true
done
if [[ "$result1" -ne 0 || "$result2" -ne 0 ]]; then
  echo "PUBLIC_WSS_E2E_FAIL exits=$result1,$result2" >&2
  exit 1
fi
grep -Fq "ONLINE_CLIENT_PASS" "$LOG_DIR/client1.log"
grep -Fq "ONLINE_CLIENT_PASS" "$LOG_DIR/client2.log"
echo "PUBLIC_WSS_E2E_PASS: two remote clients completed secure authoritative match at $URL"
