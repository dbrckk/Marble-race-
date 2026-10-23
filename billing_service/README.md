# Marble Race — trusted Google Play purchases

The app sends a **Google Play purchase token** from an actual, completed
consumable purchase to `POST /verify`. The service checks the Google Play
Developer API, rejects pending, canceled, unknown, already consumed or
incorrect products, consumes the valid purchase via the official API, and
returns exactly the receipt contract accepted by `monetization_bridge.gd`.

This service **never** generates a skin by itself. The mobile app grants
one randomized 6-hour cosmetic only after an authenticated, consumed reply.

## Required configuration

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: **secret**, complete Google service
  account JSON with appropriate Android Publisher permissions to the app.
- `MARBLE_DB_PATH=/data/purchases.sqlite3`: persistent SQLite database
  under a mounted, writable, **durable volume**.
- `PORT`: HTTP listening port, defaults to 8080; terminate TLS at the
  hosting provider and set `MARBLE_PLAY_VERIFY_URL=https://<your-domain>/verify`.

Deploy with a **single replica** and a persistent volume. Do not deploy
without either of the two required variables. Back up the volume securely.
A horizontally scaled deployment requires replacing SQLite with a shared
transactional database and distributed lock.

Build from the **repository root** with
`docker build -f billing_service/Dockerfile -t marble-billing .`.
Host this service separately from the multiplayer relay.

Grant `androidpublisher` access in Google Play Console; do not upload the
service account JSON into GitHub, an Android package, or the conversation.

## Properties

- No raw token is written to SQLite or HTTP logs; SHA-256 identifies a
  purchase while the actual token is only sent to Google.
- A token is durably reserved before consumption; if a Google response is
  lost after the purchase is consumed, a subsequent retry can safely
  complete **only** that previously reserved token.
- After completion, all further attempts return HTTP 409 without reward.
- There is no client-controlled amount, product, duration or arbitrary
  package selection.
- Requests are bounded to 4096 bytes, no sensitive error details or tokens
  leak in JSON responses. The endpoint intentionally has no CORS headers.
- This is an exchange of possession of a real Play token; do not publicly
  advertise the endpoint as an account-free entitlement sync system. Keep
  HTTPS, host abuse protection and backend monitoring in front of it.

## QA

`python3 -m unittest discover -s billing_service -p 'test_*.py' -v`

Automated fake-Google tests cover successful, invalid, duplicate, pending,
already consumed, Google outage, process-restart, lost consume response,
ten concurrent redemptions and HTTP response semantics. **They do not
replace an actual licensed Google Play test purchase in the internal track.**

The endpoint must remain off for the public build until live Play API
permissions, receipt validation, durable storage, cancellation/refund
handling, privacy disclosures and restore/reinstall tests are verified.
