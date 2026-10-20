#!/usr/bin/env python3
"""Production HTTP health + WebSocket pass-through for the Godot authority.

Render health probes are plain HTTP; Godot's WebSocketMultiplayerPeer expects
Upgrade headers. This small stdlib-only gateway avoids failed HTTP handshakes
flooding Godot logs. It does not inspect WebSocket frames or simulate races.
"""
from __future__ import annotations

import asyncio
import json
import os
import signal
from contextlib import suppress

PUBLIC_PORT = int(os.environ.get("PORT", "8080"))
BACKEND_PORT = int(os.environ.get("GODOT_INTERNAL_PORT", "8081"))
MAX_HEADER_BYTES = 16384
READ_TIMEOUT = 8.0


async def backend_connect():
    return await asyncio.wait_for(asyncio.open_connection("127.0.0.1", BACKEND_PORT), 2.5)


async def send_http(writer, status: int, payload: dict) -> None:
    body = (json.dumps(payload, separators=(",", ":")) + "\n").encode("ascii")
    reason = {200: "OK", 400: "Bad Request", 404: "Not Found",
              431: "Request Header Fields Too Large", 503: "Service Unavailable"}[status]
    writer.write(
        f"HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\n"
        f"Content-Length: {len(body)}\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n".encode("ascii") + body
    )
    await writer.drain()


async def transfer(reader, writer) -> None:
    while True:
        chunk = await reader.read(65536)
        if not chunk:
            break
        writer.write(chunk)
        await writer.drain()


async def handle_client(reader, writer) -> None:
    backend_writer = None
    try:
        header = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), READ_TIMEOUT)
        if len(header) > MAX_HEADER_BYTES:
            await send_http(writer, 431, {"error": "headers too large"})
            return
        try:
            lines = header.decode("latin-1").split("\r\n")
            request = lines[0].split(" ")
            method, path = request[0], request[1]
            fields = {}
            for line in lines[1:]:
                if ":" in line:
                    key, val = line.split(":", 1)
                    fields[key.lower().strip()] = val.strip().lower()
        except (ValueError, IndexError, UnicodeDecodeError):
            await send_http(writer, 400, {"error": "malformed request"})
            return

        is_upgrade = (fields.get("upgrade", "") == "websocket"
                      and "upgrade" in [piece.strip() for piece in fields.get("connection", "").split(",")])
        if not is_upgrade:
            if method != "GET" or path not in ("/health", "/healthz"):
                await send_http(writer, 404, {"error": "not found"})
                return
            try:
                back_reader, backend_writer = await backend_connect()
                backend_writer.close()
                await backend_writer.wait_closed()
                backend_writer = None
                await send_http(writer, 200, {"status": "ok", "service": "marble-race"})
            except (OSError, TimeoutError):
                await send_http(writer, 503, {"status": "unavailable"})
            return

        try:
            back_reader, backend_writer = await backend_connect()
        except (OSError, TimeoutError):
            await send_http(writer, 503, {"error": "game server starting"})
            return

        # Forward the byte-exact WebSocket upgrade request, including any cookies
        # or subprotocol headers. Only Godot completes the actual handshake.
        backend_writer.write(header)
        await backend_writer.drain()
        up = asyncio.create_task(transfer(reader, backend_writer))
        down = asyncio.create_task(transfer(back_reader, writer))
        done, pending = await asyncio.wait((up, down), return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()
        for task in (up, down):
            with suppress(asyncio.CancelledError, OSError, ConnectionError):
                await task
    except (asyncio.IncompleteReadError, TimeoutError, asyncio.LimitOverrunError):
        with suppress(OSError, ConnectionError):
            await send_http(writer, 400, {"error": "invalid or incomplete HTTP request"})
    except (ConnectionError, OSError):
        pass
    finally:
        if backend_writer is not None:
            backend_writer.close()
            with suppress(OSError, ConnectionError):
                await backend_writer.wait_closed()
        writer.close()
        with suppress(OSError, ConnectionError):
            await writer.wait_closed()


async def serve() -> int:
    if PUBLIC_PORT == BACKEND_PORT or not (1024 <= PUBLIC_PORT <= 65535 and 1024 <= BACKEND_PORT <= 65535):
        raise ValueError("Public and internal ports must be different and valid")
    godot = os.environ.get("GODOT_BIN", "godot")
    path = os.environ.get("GAME_DIR", "/game")
    env = dict(os.environ, PORT=str(BACKEND_PORT))
    process = await asyncio.create_subprocess_exec(
        godot, "--headless", "--path", path, "--script", "res://server/dedicated.gd",
        env=env,
    )
    server = await asyncio.start_server(handle_client, "0.0.0.0", PUBLIC_PORT, limit=MAX_HEADER_BYTES)
    print(f"WORLD_GATEWAY_READY public={PUBLIC_PORT} internal={BACKEND_PORT} health=/health", flush=True)
    shutdown = asyncio.Event()
    loop = asyncio.get_running_loop()
    with suppress(NotImplementedError):
        loop.add_signal_handler(signal.SIGTERM, shutdown.set)
        loop.add_signal_handler(signal.SIGINT, shutdown.set)
    wait_for_child = asyncio.create_task(process.wait())
    wait_for_signal = asyncio.create_task(shutdown.wait())
    try:
        async with server:
            await asyncio.wait((wait_for_child,wait_for_signal),
                               return_when=asyncio.FIRST_COMPLETED)
            if process.returncode is not None:
                print(f"WORLD_GATEWAY_GODOT_EXIT exit_code={process.returncode}", flush=True)
                return process.returncode
            return 0 # normal container stop
    finally:
        server.close()
        await server.wait_closed()
        wait_for_signal.cancel()
        if process.returncode is None:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), timeout=4)
            except TimeoutError:
                process.kill()
                await process.wait()
        wait_for_child.cancel()


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(serve()))
    except KeyboardInterrupt:
        raise SystemExit(130)
