# Star-list review — Marble Race v1.11 RC

Source: the user's own `dbrckk/star-list` catalog, inspected at commit `4a3a180` on 2026-10-20 using `scripts/recommend.py` and catalog inspection. This file documents *recommendations*, not imported code.

## Relevant saved GitHub projects

| Source in star-list | Finding | Decision |
|---|---|---|
| `godotengine/godot` | Core Godot 3D, Godot 4 API and physics features | **Already used; retain Godot** |
| `godotengine/godot-demo-projects` | Examples for engine visuals, gameplay and cross-platform testing | Reference for production Godot techniques |
| `Calinou/awesome-godot` | Curated Godot tools/extensions | Future targeted tool reviews |
| `heroiclabs/nakama` | Server-side realtime matchmaking / social services | **Future candidate** if multiple rooms, accounts or regional matchmaking are needed; not silently installed |
| `lettier/3d-game-shaders-for-beginners` | Classic shader explanations | Reference for lightweight glass/Fresnel/material effects; not a drop-in Godot shader |
| `google/filament` | High-performance 3D renderer | Not a practical drop-in for an existing Godot Android app |
| `Donchitos/Claude-Code-Game-Studios` | Agent-supported game creation workflow | Optional production inspiration, not runtime dependency |

## Implemented as a result of this review

**Personal best ghost:** a deterministic, offline, non-physical playback system in `scripts/best_ghost.gd`, using a low-poly transparent mesh, 10 Hz position sampling, interpolation and bounded local storage. This was implemented with built-in Godot APIs rather than adding dependencies to the Android app.

## Pending for a public launch

- **Global matchmaking scale:** currently one room per Render process. Nakama could replace the custom matchmaking gateway only after planning migration, billing and stateful deployment.
- **Mobile device QA:** check glass shader, gameplay feel, fps and heat on actual Android hardware.
- **Dedicated production signing and Play Console:** existing debug APK is not a Play Store release AAB.
