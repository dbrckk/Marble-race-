
# Worldwide Marble Race — Dedicated Godot Server

This is a headless, server-authoritative physics process. Android clients do NOT host games. The same WebSocket server receives clients globally once deployed on a public HTTPS endpoint.

## Deploy on Railway

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
