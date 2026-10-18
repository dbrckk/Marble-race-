# Marble Race: Lost Tracks

An original, offline-first **3D Android marble racing game** inspired by Meticulai Games' *Lost Marbles* visual reference.

Built with **Godot 4.5**, physics-driven 40-racer tournament, procedural glass marble shader, wooden tabletop racecourse with colorful modular sidewalls, kinetic rotating paddles, posts, slalom, 6 gameplay perks, touch steering, rechargeable boost, selectable 3D cameras, results, and leaderboard.

## Run

Open `project.godot` in Godot 4.5.x and press F6/F5, or run:

```bash
godot --path . --editor --quit
godot --path . --script res://tests/smoke.gd --headless
godot --path .
```

## Controls

Android landscape: tap **QUICK PLAY**, select a perk, tap **START RACE**. Hold **LEFT/RIGHT** to influence a marble's travel, hold **BOOST**, tap **CAMERA** to cycle views. Keyboard: A/D or arrows, Space for boost, C for camera. Physical collisions determine the outcome.

## Build Android

Install Godot 4.5.1 stable, matching **Android export templates**, Android SDK (platform 35, build-tools), JDK 17+, and configure editor paths. In Godot: **Project → Export → Add Android**, package identifier `com.dbrckk.marble_race`, export APK for device QA or signed AAB for Play Store. **A release keystore must be supplied by the publisher**; do not commit private keys.

## Verification

`tests/smoke.gd` asserts course creation, 40 racers, perk physics, unique starts, countdown, rigidbody motion, camera, boost and navigation. Headless smoke test passes on Godot 4.5.1.

## Scope and attribution

Original code, original generated geometry, and original shader. No original game's proprietary assets are bundled. Reference video: https://x.com/MeticulAi/status/2111568537684955500. This is an independent inspired work, not an official Meticulai product.

**Status:** initial playable prototype with passing Godot automated smoke checks; real-device rendering, performance, controls and signed Android packaging are not yet validated.
