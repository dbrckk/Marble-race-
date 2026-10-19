# Marble Race — 15 production-critical design concepts

Baseline: Godot 4.5.1 GL Compatibility, Android arm64, physics-driven 40-racer races.
Priorities follow the order below. A checked implementation is a real code path, not a mock.
These are engineering acceptance criteria, not a claim that subjective quality or device FPS are fully verified.

| # | Concept | Production implementation and location | Verification |
|---|---|---|---|
| 1 | **Fair physical collisions** | 40 real RigidBody3D marbles, fixed-tick forces, continuous collision detection (`scripts/marble.gd`) | Smoke + long-race physics |
| 2 | **Recoverable obstacle jams** | New forward-progress watchdog, increasing centerward/upward impulse with bounded strength; no teleport (`scripts/marble.gd`) | Long-race: player reached finish after ~56.5 s; classified marbles disable their collision masks |
| 3 | **Meaningful skill-based steering** | New speed-sensitive lateral force; analog smooth input retained (`marble.gd`, `game.gd`, `touch_controls.gd`) | Multitouch + physics |
| 4 | **Believable opponent behavior** | New deterministic bounded AI lane goals and velocity damping instead of constant near-zero drifting (`marble.gd`) | 40 competitors advance under collisions |
| 5 | **Predictive follow camera** | New damped camera look-ahead based on linear velocity, with bounded collision shake (`game.gd`) | Godot render and smoke |
| 6 | **Readable glass shader** | Fresnel-style shell and candy internal veins; new quality-sensitive secondary highlight and sparkle density (`shaders/marble.gdshader`) | GLSL import under GL Compatibility |
| 7 | **Mobile GPU scalability** | 3 quality profiles, sphere LOD and shader quality uniform, optional MSAA (`game.gd`, `marble.gd`) | Existing profile smoke + import |
| 8 | **Efficient long course rendering** | Instanced wooden planks/rails and cached mesh resources (`track_surface.gd`) | 648 grouped track parts in smoke |
| 9 | **Physical obstacle readability** | Edge baffles, moving hammers, slalom and contrasting lacquered collider details (`game.gd`, `obstacle_finish.gd`) | Course and feasibility tests |
| 10 | **Stable tactile presentation** | Independent touch pointers for steering/boost, dead zone, handedness, sensitivity, input cleanup (`touch_controls.gd`) | Touch regression |
| 11 | **Impact feedback hierarchy** | New speed-tier vibration duration and capped screen shake, separate impact sounds (`audio.gd`, `game.gd`) | Headless smoke + real device remains |
| 12 | **Adaptive musical tension** | Speed-dependent wind and percussion, finish fanfare and positional Foley (`audio.gd`) | Audio resource import; ear QA pending |
| 13 | **Clear race HUD** | New km/h unit, danger flash after collision and low-boost color warning (`hud.gd`) | Smoke + screenshot review |
| 14 | **Persistent championship** | Three unlockable circuits, best results, stars, practice separation (`career.gd`) | Career and end-to-end tests |
| 15 | **Deterministic, shippable QA** | Full physics, rendering, touch, feasibility, career, end-to-end and Android signing workflow (`.github/workflows/verify.yml`) | CI + local APK signature |

## Performance decisions

- Never create a real-time shadow-casting light per marble; one batch of contact shadows suffices.
- Keep opaque glass shading for GL Compatibility and Android stability.
- Treat AI and recovery as **forces**, never replace actual race positions.
- Clamp costly effects by quality profile; prefer material instancing over hundreds of independent draw calls.
- Avoid continuous UI rebuilds; race UI refresh is already throttled to roughly 9 Hz.
- Do not claim measured Android FPS from Mesa software rendering.

## Ship gates

Godot parser/import, smoke, touch controls, course feasibility, three-course progression,
full physical race, rendering capture and Android debug APK signature must pass.
The debug APK is a release-candidate test artifact, not a Play Store-signed production AAB.


### Regression found by GitHub Actions and fixed

The first v1.1 pipeline exposed an OS-dependent stall a few centimeters before the
finish threshold. Root cause: **finished marbles were frozen but still retained
collision layers and masks**. They accumulated into a physical barricade on the
finish stripe. Fix: finished racers remain ranked and visible, while their collision
layer and collision mask are deferred to 0; resets restore the original layer/mask.
The physical finish position is unchanged. The 110-second long-run now asserts
the player's **actual finished** state, so this regression can no longer pass
merely because the marble advanced past 100 meters.
