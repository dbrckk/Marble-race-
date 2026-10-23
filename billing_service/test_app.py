"""Offline contract and crash-recovery tests; no Google credentials needed."""
import hashlib
import json
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from billing_service.app import Handler, Ledger, PACKAGE, PRODUCT, PurchaseError, PurchaseService


class FakePlay:
    def __init__(self):
        self.receipts = {}
        self.consumed = []
        self.fail_after_consuming = False
        self.unavailable = False

    def get(self, token):
        if self.unavailable:
            raise PurchaseError(503, "Google is temporarily unavailable")
        if token not in self.receipts:
            raise PurchaseError(422, "Unknown purchase")
        return dict(self.receipts[token])

    def consume(self, token):
        self.consumed.append(token)
        self.receipts[token]["consumptionState"] = 1
        if self.fail_after_consuming:
            self.fail_after_consuming = False
            raise PurchaseError(503, "Response lost after Google consumption")


class VerificationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = str(Path(self.tmp.name) / "play.sqlite3")
        self.play = FakePlay()
        self.ledger = Ledger(self.path)
        self.svc = PurchaseService(self.ledger, self.play)
        self.token = "RealisticPurchaseToken-1abc:XYZ"
        self.payload = {"product_id": PRODUCT, "package_name": PACKAGE,
                        "purchase_token": self.token}
        self.play.receipts[self.token] = {
            "purchaseState": 0, "consumptionState": 0, "productId": PRODUCT,
        }

    def tearDown(self):
        self.ledger.conn.close()
        self.tmp.cleanup()

    def check_refused(self, payload, status):
        with self.assertRaises(PurchaseError) as ex:
            self.svc.verify(payload)
        self.assertEqual(ex.exception.code, status)

    def test_true_google_purchase_exactly_once(self):
        receipt = self.svc.verify(self.payload)
        self.assertEqual(receipt, {
            "ok": True, "consumed": True, "product_id": PRODUCT,
            "token_sha256": hashlib.sha256(self.token.encode()).hexdigest(),
        })
        self.assertEqual(self.play.consumed, [self.token])
        self.check_refused(self.payload, 409)
        self.assertEqual(len(self.play.consumed), 1)

    def test_not_pending_refunded_canceled_or_wrong_product(self):
        for state in (1, 2, -1, None):
            self.play.receipts[self.token]["purchaseState"] = state
            self.check_refused(self.payload, 422)
        self.play.receipts[self.token]["purchaseState"] = 0
        self.play.receipts[self.token]["productId"] = "other_product"
        self.check_refused(self.payload, 422)
        self.assertEqual(self.play.consumed, [])

    def test_refuse_wrong_package_product_invalid_token_and_consumed_elsewhere(self):
        self.check_refused({**self.payload, "package_name": "fake.package"}, 422)
        self.check_refused({**self.payload, "product_id": "other"}, 422)
        self.check_refused({**self.payload, "purchase_token": "short"}, 400)
        self.check_refused({**self.payload, "purchase_token": "long" + chr(10) + "secretxyz"}, 400)
        self.play.receipts[self.token]["consumptionState"] = 1
        self.check_refused(self.payload, 409)
        self.assertEqual(self.play.consumed, [])

    def test_retry_after_lost_google_consume_response(self):
        self.play.fail_after_consuming = True
        self.check_refused(self.payload, 503)
        digest = hashlib.sha256(self.token.encode()).hexdigest()
        self.assertEqual(self.ledger.lookup(digest), "pending")
        recovered = self.svc.verify(self.payload)
        self.assertTrue(recovered["ok"])
        self.assertEqual(self.play.consumed, [self.token])
        self.check_refused(self.payload, 409)

    def test_google_outage_no_reward_or_reservation(self):
        self.play.unavailable = True
        self.check_refused(self.payload, 503)
        self.assertIsNone(self.ledger.lookup(hashlib.sha256(
            self.token.encode()).hexdigest()))
        self.play.unavailable = False
        self.assertTrue(self.svc.verify(self.payload)["consumed"])

    def test_persistence_prevents_redemption_after_restart(self):
        self.svc.verify(self.payload)
        second = Ledger(self.path)
        try:
            fresh = PurchaseService(second, self.play)
            with self.assertRaises(PurchaseError) as error:
                fresh.verify(self.payload)
            self.assertEqual(error.exception.code, 409)
        finally:
            second.conn.close()

    def test_simultaneous_requests_only_one_consumption(self):
        statuses = []
        lock = threading.Lock()

        def redeem():
            try:
                self.svc.verify(self.payload)
                status = 200
            except PurchaseError as error:
                status = error.code
            with lock:
                statuses.append(status)

        threads = [threading.Thread(target=redeem) for _ in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=5)
        self.assertEqual(statuses.count(200), 1)
        self.assertEqual(statuses.count(409), 9)
        self.assertEqual(len(self.play.consumed), 1)

    def test_http_contract_no_token_leak(self):
        class TestHandler(Handler):
            service = self.svc

        server = ThreadingHTTPServer(("127.0.0.1", 0), TestHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        address = "http://127.0.0.1:%d" % server.server_port
        try:
            with urlopen(address + "/healthz", timeout=3) as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(json.loads(response.read())["ok"], True)
            data = json.dumps(self.payload).encode()
            request = Request(address + "/verify", data=data, method="POST",
                              headers={"Content-Type": "application/json"})
            with urlopen(request, timeout=3) as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(response.headers["Cache-Control"], "no-store")
                self.assertNotIn(self.token, response.read().decode())
            with self.assertRaises(HTTPError) as retry:
                urlopen(request, timeout=3)
            self.assertEqual(retry.exception.code, 409)
            with self.assertRaises(HTTPError) as huge:
                urlopen(Request(address + "/verify", data=b"X" * 5000,
                                method="POST"), timeout=3)
            self.assertEqual(huge.exception.code, 413)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=4)


if __name__ == "__main__":
    unittest.main()
