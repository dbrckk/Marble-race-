#!/usr/bin/env bash
set -euo pipefail
GODOT_BIN="${GODOT_BIN:-godot}"
ROOT="${GAME_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_DIR="${NETWORK_LOG_DIR:-/tmp/marble-online-qa}"
mkdir -p "$LOG_DIR"
PORT="${PORT:-28999}"
client_args=()
server_marker=ONLINE_SERVER_PASS
client_marker=ONLINE_CLIENT_PASS
if [[ -n "${GLACIER_ONLINE_LAYOUT:-}" ]]; then
  client_args+=(--glacier-cut-in)
  server_marker=GLACIER_ONLINE_SERVER_PASS
  client_marker=GLACIER_ONLINE_CLIENT_PASS
fi
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT
PORT="$PORT" "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_server.gd > "$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
for _ in {1..40}; do
  grep -Fq ONLINE_SERVER_TEST_READY "$LOG_DIR/server.log" && break
  sleep 0.10
done
if ! grep -Fq ONLINE_SERVER_TEST_READY "$LOG_DIR/server.log"; then
  cat "$LOG_DIR/server.log"
  exit 1
fi
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="ws://127.0.0.1:$PORT" --mode=public "${client_args[@]}" > "$LOG_DIR/client1.log" 2>&1 &
pids+=("$!")
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/online_client.gd -- --url="ws://127.0.0.1:$PORT" --mode=public "${client_args[@]}" > "$LOG_DIR/client2.log" 2>&1 &
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
grep -Fq "$server_marker" "$LOG_DIR/server.log"
grep -Fq "$client_marker" "$LOG_DIR/client1.log"
grep -Fq "$client_marker" "$LOG_DIR/client2.log"
if [[ -n "${GLACIER_ONLINE_LAYOUT:-}" ]]; then
  echo "GLACIER_ONLINE_E2E_PASS: layout $GLACIER_ONLINE_LAYOUT, 1 dedicated server, 2 independent clients"
else
  echo "WORLDWIDE_PROTOCOL_E2E_PASS: 1 dedicated server, 2 independent clients"
fi
