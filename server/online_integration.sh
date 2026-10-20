#!/usr/bin/env bash
set -euo pipefail
GODOT_BIN="${GODOT_BIN:-godot}"
ROOT="${GAME_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_DIR="${NETWORK_LOG_DIR:-/tmp/marble-online-qa}"
mkdir -p "$LOG_DIR"
PORT=28999
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT
PORT="$PORT" "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_server.gd > "$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
sleep 2
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="ws://127.0.0.1:$PORT" --mode=public > "$LOG_DIR/client1.log" 2>&1 &
pids+=("$!")
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="ws://127.0.0.1:$PORT" --mode=public > "$LOG_DIR/client2.log" 2>&1 &
pids+=("$!")
set +e
wait "${pids[1]}"; client1=$?
wait "${pids[2]}"; client2=$?
wait "${pids[0]}"; server=$?
set -e
cat "$LOG_DIR/server.log"
cat "$LOG_DIR/client1.log"
cat "$LOG_DIR/client2.log"
test "$server" -eq 0 && test "$client1" -eq 0 && test "$client2" -eq 0
grep -Fq ONLINE_SERVER_PASS "$LOG_DIR/server.log"
grep -Fq ONLINE_CLIENT_PASS "$LOG_DIR/client1.log"
grep -Fq ONLINE_CLIENT_PASS "$LOG_DIR/client2.log"
echo "WORLDWIDE_PROTOCOL_E2E_PASS: 1 dedicated server, 2 independent clients"
