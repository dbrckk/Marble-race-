# v1.41 — Racecraft: physical slipstream (solo)

## Player experience

Following a **moving rival ahead, in the same lane and at the same
physical elevation**, creates a small aerodynamic advantage. Keeping that
position for approximately half a second engages **DRAFT** beside the turbo
meter, with a subtle one-shot original audio cue.

- The effect uses the actual 40 Godot rigid-body positions and forward
  velocities. A racer behind, beside, far away, stopped, eliminated or on a
  separate elevated bridge does **not** qualify.
- The eligible corridor is **2.2–10 m** longitudinally, **under 1.65 m**
  laterally and **under 1.30 m** vertically. The benefit tapers smoothly at
  the edges and at low speeds.
- Following another marble grants at most **0.095 extra turbo-energy units
  per second** while not boosting (on top of the normal 0.08/s recharge),
  and at most **1.85 m/s²** of small extra forward acceleration via genuine
  `RigidBody3D.apply_central_force`. The usual 24 m/s speed limiter stays
  effective.
- DRAFT appears only once the sustained positional lock is meaningful.
  The sound and brief race moment have a **4.5 s cooldown**, without new
  downloadable audio, continuous channels, realtime lights or physics
  objects. All visuals use the existing touch-safe HUD.
- Every new race resets the human turbo meter to **100%**, and starting a
  new race or returning to the menu discards any prior draft engagement.

## Multiplayer and determinism

This ability is currently **solo only**. Dedicated-server rooms and client
replicas do not apply its extra force or refill the standalone local turbo
meter. It never steers AI competitors, bypasses rare-item server validation
or changes finish times by scripting positions. Supporting per-user
server-side boost meters in multiplayer would need a separate authoritative
implementation and synchronization; enabling drafting only on clients is
specifically prohibited.

## Mobile performance / validation

The sampler visits at most **39 competitors every ~0.14 s**, not every
physics tick. The broad phase rejects out-of-range marbles before costly
processing. No extra draw calls are needed for drafting; it reuses a race
HUD label and one existing sound channel.

`tests/slipstream.gd` is a mandatory Android CI step and verifies each
of the three worlds, lock timing, physical 3D eligibility, turbo refill,
client-side non-authority, replay reset and sampling budget. Full-course
Godot physics, Android arm64 APK export/signature and connected server tests
are unchanged release requirements.

This is an Android **debug release candidate**, not a production-signed
Play Store AAB. Performance, battery, screen readability, acoustic balance
and collision feel must also be checked on an actual Android phone.
