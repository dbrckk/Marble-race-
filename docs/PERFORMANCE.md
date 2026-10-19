# Marble Race: measured renderer optimization — v0.10

These results were measured in the **same software OpenGL environment** (Godot 4.5.1, Mesa llvmpipe, Compatibility renderer) on the same 40-marble course. Both samples were recorded using `tests/render_benchmark.gd` during an active race after 50 render frames.

| Measured metric | v0.9 baseline | v0.10 optimized | Approximate reduction |
|---|---:|---:|---:|
| Draw calls per render frame | 2,865 | 903 | **68.5%** |
| Scene nodes | 3,325 | 2,159 | **35.1%** |
| Rendered primitives per frame | 579,494 | 359,472 | **38.0%** |
| Active physics objects | 50 | 50 | unchanged |
| Software renderer FPS snapshot | 4 | 5 | not an Android estimate |

**What changed:** 648 track components now render as grouped GPU instances. Additional decorative chevrons and lane indicators render in two batches. The physical colliders remain independent and continue to participate in Godot's collision solver.

**Caveats:** Draw calls are scene- and camera-dependent. These measurements cannot establish a numeric FPS improvement on an Android GPU; the software renderer uses a different driver and does not reflect battery consumption, GPU throttling, touch latency or thermals. Geometry grouping can also reduce per-instance frustum culling, so a real device test is essential.

**Validation:** Godot's smoke, dual-finger control, long-course race tests and the Android debug APK's v2/v3 signature passed. The GL Compatibility screenshots are produced by the actual engine, not AI illustrations.

## Check on Android

1. Install the v0.10 debug APK and launch **QUICK PLAY**.
2. In the menu enable **FPS DISPLAY**.
3. Compare **ECONOMY**, **BALANCED** and **ULTRA** in the same camera/view, once after the device warms up.
4. Check any stutter near gates, control latency under simultaneous boost and steering, heat and battery use. Prefer **BALANCED** for normal play if Ultra is unstable.
5. If reporting a bug, include approximate in-game location and whether the frame rate drops below 30 FPS.

The independent scripts can be rerun using:

```sh
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/touch_controls.gd
godot --headless --fixed-fps 60 --path . --script res://tests/race_diagnostic.gd
# For a graphical software-OpenGL baseline, run with xvfb-run and a real display:
xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tests/render_benchmark.gd
```
