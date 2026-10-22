# Android rendering budget — Marble Race

## v1.34: static course dressing GPU batching

The 216-metre, three-biome race retains **40 rigid-body marbles**, the same
racing rails and collision geometry, and all original brass, dark-metal, wood,
flag-staff and start/finish decorations.

Previously, the non-colliding structural ornaments in `scripts/course_dressing.gd`
were drawn as **44 individual BoxMesh/MeshInstance3D objects**. The current
implementation records the same original world positions, sizes, tilt angles
and Material references, and instantiates them through **MultiMeshInstance3D**
clusters keyed by shared material and distance along the course.

- Every former box remains a geometrically equivalent unit-cube instance
  transformed by the original box scale, tilt and translation.
- Material groups remain independent: metallic brass, dark support, walnut and
  finish plates retain their own shading.
- Groups are divided into roughly 72-metre course intervals. This is important:
  a single GPU batch covering the entire course would unnecessarily defeat
  distance/frustum culling from the follow camera.
- Physical rails, ramps, shortcuts, baffles and hazards are **not changed**.
- Animated silk pennants, globe pins, numbered section labels and the 36-piece
  main decorative rail-strip GPU batch remain separate, unchanged.
- The entire optional dressing is hidden in ECONOMY and retained in BALANCED
  and ULTRA, as before.

This reduces the number of structural decoration *render objects*; actual GPU
draw-call reduction, frame pacing, battery use and thermal throttling must
still be measured on a physical Android phone. Headless CI **cannot prove**
a particular phone will reach 60 FPS.

## How to collect useful Redmi 15 5G measurements

1. Start Marble Race with the graphics setting **AUTO** or **BALANCED**.
2. Enable the built-in FPS diagnostic display.
3. Race the same circuit layout with 40 marbles, including the crowded start,
   moving hazards, shortcut and final straight.
4. Compare the FPS, frame-time **P95**, **SLOW %** (frames above 33.3 ms),
   physics milliseconds and draw calls. Different layouts, heat or background
   processes can alter a measurement.
5. Repeat in ECONOMY. A large improvement implicates drawing/shadows;
   comparable slowdown in both modes suggests simulation/CPU or phone throttling.

The diagnostics are on-device only. No remote server collects this information.
`tests/static_dressing_batches.gd` blocks Android packaging if ornaments
disappear, become individual draw objects again, or break ECONOMY visibility.
