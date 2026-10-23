"""Google Play one-time consumable verification for Marble Race.

Never issue a cosmetic reward without a real Google Developer API purchase
confirmation and consumption. Store no raw purchase token or Google key.
"""
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote

PACKAGE = "com.dbrckk.marble_race"
PRODUCT = "random_skin_6h"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
MAX_BODY = 4096


class PurchaseError(Exception):
    def __init__(self, code: int, message: str):
        self.code = code
        super().__init__(message)


class GooglePlay:
    def __init__(self, service_account: dict):
        # Lazy imports keep the pure service/HTTP regression runnable without
        # credentials, Android SDKs, or network access.
        from google.oauth2 import service_account as google_service_account
        from google.auth.transport.requests import AuthorizedSession
        credentials = google_service_account.Credentials.from_service_account_info(
            service_account, scopes=[SCOPE]
        )
        self.session = AuthorizedSession(credentials)

    @staticmethod
    def _path(token: str) -> str:
        return ("https://androidpublisher.googleapis.com/androidpublisher/v3/"
                f"applications/{PACKAGE}/purchases/products/{PRODUCT}/tokens/"
                + quote(token, safe=""))

    def get(self, token: str) -> dict:
        response = self.session.get(self._path(token), timeout=12)
        if response.status_code == 404:
            raise PurchaseError(422, "Purchase is not recognized by Google Play.")
        if response.status_code != 200:
            raise PurchaseError(503, "Google Play verification is unavailable.")
        body = response.json()
        if not isinstance(body, dict):
            raise PurchaseError(503, "Invalid verification response.")
        return body

    def consume(self, token: str) -> None:
        response = self.session.post(self._path(token) + ":consume", timeout=12)
        if response.status_code not in (200, 204):
            raise PurchaseError(503, "Google Play has not confirmed consumption.")


class Ledger:
    """SQLite uniqueness and durable pending state across app restarts."""
    def __init__(self, path: str):
        location = Path(path).expanduser()
        if not location.is_absolute() or str(location) == ":memory:":
            raise ValueError("Persistent absolute MARBLE_DB_PATH is required")
        location.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(location), timeout=20,
                                    check_same_thread=False)
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.execute("PRAGMA busy_timeout=20000")
        self.conn.execute("CREATE TABLE IF NOT EXISTS purchases ("
                          "digest TEXT PRIMARY KEY, state TEXT NOT NULL CHECK"
                          "(state IN ('pending','granted')), updated INTEGER NOT NULL"
                          " DEFAULT (unixepoch()))")
        self.conn.commit()
        self.lock = threading.RLock()

    def lookup(self, digest: str) -> str | None:
        row = self.conn.execute(
            "SELECT state FROM purchases WHERE digest=?", (digest,)
        ).fetchone()
        return row[0] if row else None

    def reserve(self, digest: str) -> bool:
        with self.conn:
            cur = self.conn.execute(
                "INSERT OR IGNORE INTO purchases(digest,state) VALUES(?,'pending')",
                (digest,),
            )
        return cur.rowcount == 1

    def complete(self, digest: str) -> None:
        with self.conn:
            cur = self.conn.execute(
                "UPDATE purchases SET state='granted',updated=unixepoch() "
                "WHERE digest=? AND state='pending'", (digest,)
            )
            if cur.rowcount != 1:
                raise PurchaseError(409, "Purchase cannot be claimed again.")


class PurchaseService:
    def __init__(self, ledger: Ledger, play: GooglePlay):
        self.ledger, self.play = ledger, play

    @staticmethod
    def _validate_payload(payload: object) -> str:
        if not isinstance(payload, dict):
            raise PurchaseError(400, "Invalid purchase payload.")
        if payload.get("package_name") != PACKAGE or (
            payload.get("product_id") != PRODUCT
        ):
            raise PurchaseError(422, "This product is not available.")
        token = payload.get("purchase_token")
        if not isinstance(token, str) or not (12 <= len(token) <= 2048) or (
            any(c.isspace() or ord(c) < 33 or ord(c) > 126 for c in token)
        ):
            raise PurchaseError(400, "Invalid purchase token.")
        return token

    def verify(self, payload: object) -> dict:
        token = self._validate_payload(payload)
        digest = hashlib.sha256(token.encode("utf-8")).hexdigest()
        # One lock serializes the entire verify/consume flow in this process.
        # A single persistent backend replica is required in production.
        with self.ledger.lock:
            state = self.ledger.lookup(digest)
            if state == "granted":
                raise PurchaseError(409, "Purchase already redeemed.")
            receipt = self.play.get(token)
            if receipt.get("purchaseState") != 0:
                # Google values: 0 PURCHASED, 1 CANCELED, 2 PENDING.
                raise PurchaseError(422, "Purchase is not completed.")
            if receipt.get("productId", PRODUCT) != PRODUCT:
                raise PurchaseError(422, "Wrong Google Play product.")
            consumption = receipt.get("consumptionState")
            if consumption not in (0, 1):
                raise PurchaseError(503, "Missing Google Play consumption state.")
            if consumption == 1:
                # Recovery after a crash between consuming a purchase at
                # Google and marking it complete locally: safe ONLY for a
                # previously durably reserved token.
                if state != "pending":
                    raise PurchaseError(409, "Purchase already consumed.")
            else:
                if state is None and not self.ledger.reserve(digest):
                    raise PurchaseError(409, "Purchase already reserved.")
                self.play.consume(token)
            self.ledger.complete(digest)
            return {"ok": True, "consumed": True, "product_id": PRODUCT,
                    "token_sha256": digest}


class Handler(BaseHTTPRequestHandler):
    service: PurchaseService

    def _json(self, status: int, obj: dict) -> None:
        data = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        if self.path == "/healthz":
            self._json(200, {"ok": True})
        else:
            self._json(404, {"ok": False})

    def do_POST(self) -> None:
        if self.path != "/verify":
            self._json(404, {"ok": False})
            return
        try:
            length = int(self.headers.get("Content-Length", "-1"))
            if length < 1 or length > MAX_BODY:
                raise PurchaseError(413, "Invalid purchase payload size.")
            payload = json.loads(self.rfile.read(length))
            self._json(200, self.service.verify(payload))
        except (ValueError, UnicodeError, json.JSONDecodeError):
            self._json(400, {"ok": False, "error": "Malformed JSON."})
        except PurchaseError as error:
            self._json(error.code, {"ok": False, "error": str(error)})
        except Exception:
            # Never leak purchase tokens, response bodies, or service-account
            # material into responses or server access logs.
            self._json(503, {"ok": False,
                             "error": "Purchase verification unavailable."})

    def log_message(self, _format: str, *_args: object) -> None:
        # Do not log untrusted requests or purchase identifiers.
        return


def main() -> None:
    key_json = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "")
    db_path = os.environ.get("MARBLE_DB_PATH", "")
    if not key_json or not db_path:
        raise RuntimeError("Refusing to start without Google Play service "
                           "account credentials and persistent MARBLE_DB_PATH")
    credentials = json.loads(key_json)
    if not isinstance(credentials, dict) or credentials.get("type") != "service_account":
        raise RuntimeError("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is invalid")
    ledger = Ledger(db_path)
    Handler.service = PurchaseService(ledger, GooglePlay(credentials))
    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
