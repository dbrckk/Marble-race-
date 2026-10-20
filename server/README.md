
# Worldwide Marble Race — Dedicated Godot Server

This is a headless, server-authoritative physics process. Android clients do NOT host games. The same WebSocket server receives clients globally once deployed on a public HTTPS endpoint.

## Live production endpoint (Render, free)

A working free Render service has been deployed in the Frankfurt region:
- Service: `marble-race-global`
- Public secure address: `wss://marble-race-global.onrender.com`
- GitHub source: `dbrckk/Marble-race-` (branch `main`)
- Container: `server/Dockerfile`, port 8080
- Two independent Godot client processes have successfully exchanged commands and authoritative snapshots through the **public TLS endpoint**; these tests were run from the same external developer host and are not a cross-country handset certification.

Free Render web services may spin down after inactivity, causing cold starts and occasional matchmaking delays. They have limited CPU/RAM and must not be advertised as a 24/7 worldwide scalable service. One room per process supports 2–4 human players. Running many rooms or ensuring low-latency across continents requires an appropriately sized dedicated deployment, regional matchmaking, and load testing.

To validate the public service from a workstation, run:

```bash
GODOT_BIN=/path/to/Godot_v4.5.1-stable_linux.x86_64 \
GAME_DIR=. bash server/public_integration.sh
```

## Alternative deployment on Railway

1. Deploy GitHub repository dbrckk/Marble-race-, branch main.
2. Use the root railway.json, which builds server/Dockerfile.
3. Create a Railway public HTTPS domain routed to port 8080, and confirm its WebSocket URL wss://YOUR-DOMAIN.up.railway.app.
4. Set that address in config/online_server.txt before exporting Android, or enter it into the WORLDWIDE ONLINE RACES lobby.
5. Connect two or more players from any Internet network, including mobile data.

PORT is supplied by the container environment (default 8080).

Railway Free has limited included compute credits and can suspend the service when exhausted. This setup is not a guarantee of permanent free hosting.

## Test locally

Use Godot 4.5.1 with the Compatibility renderer.

  GODOT_BIN=/path/to/godot GAME_DIR=. bash server/online_integration.sh

This starts one dedicated host and two independent clients and verifies actual WebSocket networking, assigned marbles, physics authority and controls. For manually running the server:

  PORT=8080 godot --headless --path . --script res://server/dedicated.gd

Public mobile connections must use encrypted wss:// URLs; unencrypted ws:// is accepted only for localhost development.

## Capacity and behavior

- One live room per server process, maximum four human participants, up to 40 simulated marbles.
- Quick Match selects a public room. A private room is opened by one player and joined by the code of that room.
- Remaining marbles are AI-controlled, and AI takes over on a player's disconnect.
- Player commands are bound to the remote peer and rate-limited to 50 Hz.
- World physics and finishing order are computed only by the server.
- Online game results do not write to offline career save files.

## Planned post-beta changes

Multiple concurrent rooms, server selection by region, elastic scaling, better mobile jitter compensation, reconnect tokens, account identity and network telemetry are not implemented yet.

### v1.9: HTTP health and WebSocket gateway

The production Docker image now starts `python3 -u server/edge_gateway.py`
instead of launching Godot directly on the public port. The gateway:

- Listens on `$PORT` (Render, default 8080) for HTTPS-terminated proxy traffic.
- Starts the headless Godot authority on `$GODOT_INTERNAL_PORT` (default 8081).
- Returns `200 {"status":"ok",...}` for `GET /health` when Godot is
  accepting TCP connections, and 503 during backend initialization.
- Passes through validated WebSocket upgrade headers and payload streams,
  without decoding player controls or authoring game state.
- Bounds header size/read time and terminates the Godot child on shutdown.

Use `GET https://marble-race-global.onrender.com/health` to check readiness.
`server/test_edge_gateway.sh` verifies HTTP 200/404, two real WebSocket
clients playing via the gateway, and absence of HTTP-handshake errors.

To run locally:

```bash
PORT=8080 GODOT_INTERNAL_PORT=8081 GODOT_BIN=/path/to/godot \
  GAME_DIR=. python3 -u server/edge_gateway.py
```

Runtime needs Python 3 standard library only; no database required.

### Runtime dependency correction (v1.9 RC hotfix)

Ubuntu's `python3-minimal` omits optional parts of the Python 3 standard
library, including `asyncio`. The production image now installs the full
Ubuntu `python3` package, asserts that its gateway imports succeed during
`docker build`, and is built again in GitHub Actions before APK upload.

### v1.12 RC — Fairer rematches and input fail-safe

- The authoritative server clears a player's steering and turbo after 650 ms without an accepted input packet, avoiding indefinitely stuck commands after a network stall. Valid new packets immediately resume control.
- Completed rooms with two or more connected players automatically play WOODWORKS, SWITCHBACK, and GAUNTLET in sequence. All connected clients rebuild the correct physical geometry, independent of offline career unlocks.
- When the final player disconnects, the next room restarts at WOODWORKS. The deployment still supports only one simultaneous room per server process.
