# Marble Race 1.33 — Android 40-marble performance diagnosis

The game simulates **40 real rigid bodies** at the original 60 Hz physics tick.
The 1.33 update is an **algorithmic reduction** in unnecessary work rather
than a reduction in marble count, physics precision, object detail, collision
geometry or fidelity.

## Gameplay-preserving optimizations

- **Shortcut:** the physics-only reward check is evaluated for racers
  in the conservative `-88.0 <= z <= -46.5` band. The first portal,
  all biome takeoffs and the reward gate are within this interval.
  Far-away racers no longer sample the curved bypass point function.
- **Course zones:** 5 biome effects perform a cheap longitudinal reject
  before full three-dimensional checks. The vent circle has the same
  exact radius-squared test and the ice/boost ribbons retain their
  original dimensions.
- **Moving hazards:** a real crossing-position and height gate runs
  *before* formatting an event+player dictionary key. Reward eligibility,
  impulses and authority are unchanged.
- **Rare items:** human eligibility is checked once per physics tick,
  reusing an array. Each of the four item positions tests only
  eligible local/remote human racers, never the other 39 AI marbles.
  Dedicated server permissions are checked live on every tick.
- **Race HUD:** one actual standings sort now supplies both the
  player's rank and the top-three leaderboard instead of sorting
  the 40 marbles twice.

## Measure on a real Android device

1. Install an APK using the safe update precautions in
   [ANDROID_UPDATES.md](ANDROID_UPDATES.md).
2. Open the in-game FPS setting and enable the **FPS overlay**.
3. Start a race with 40 marbles, wait several seconds and examine
   the performance readout below FPS.
4. Record readings on **Woodworks**, **Glacier** and **Forge**,
   including the crowded opening, moving obstacles and the last third
   of the run. Capture screenshots if performance is uneven.

### Metrics

- **FPS:** engine-measured rendered frames per second.
- **P95 ms:** 95th percentile of the latest 120 valid rendered frame
  intervals. Around 16.7 ms corresponds to 60 fps pacing, and
  33.3 ms to 30 fps pacing. Large values reveal stutter even if
  average FPS looks acceptable.
- **PHYS ms:** Godot's reported cost for the physics step, converted
  from seconds to milliseconds.
- **DRAW:** render draw calls reported by Godot. A value of zero can
  indicate unavailable monitor data, for example in headless builds.

Reports sample engine monitors only about once per second, keep no
more than 120 frame intervals in memory and never send data online.
Diagnostics are disabled when the FPS overlay is hidden. Paused or
backgrounded frame intervals longer than 250 ms are excluded to avoid
mislabeling app-background events as race frame stutter.

**Important:** Automated headless regression establishes that the
optimization rejects irrelevant geometry and preserves core behaviors.
It does **not** measure the actual GPU or frame rate of a Redmi 15 5G.
The Android on-device overlay supplies that evidence.

CI runs `tests/performance_budget.gd` plus existing course, full 120-second
AI navigation, real server network, rare item and Android APK signing tests.
Release candidate: **1.33.0-rc**, version code **47**.
