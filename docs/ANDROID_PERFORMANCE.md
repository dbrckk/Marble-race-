# Marble Race — Android 40-marble performance diagnosis

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
2. In the main menu, select **GRAPHICS: BALANCED** and enable **FPS DISPLAY**.
3. Finish a solo race and tap **COPY FPS REPORT**. Paste the report into a note
   or message.
4. Tap **TEST ECONOMY** in the results to replay the same layout with the same
   perk. Copy the second report. **TEST BALANCED** repeats the comparison in
   the other direction. The selected profile also becomes your graphics preference.
5. Repeat on Woodworks, Glacier and Forge. Keep the same camera and follow a
   similar line on both runs. For sustained performance, repeat after 15 minutes
   of play and record the phone model.

### Metrics

- **FPS:** engine-measured rendered frames per second.
- **P95 ms:** 95th percentile of frame intervals. The live overlay uses its
  latest 120 frames. The report uses the whole phase, rounds up to whole
  milliseconds and displays **250+** for its highest bucket.
- **>33.3 ms:** share of frames slower than a 30 FPS frame interval.
- **PHYS / DRAW:** mean of the sampled physics time in milliseconds and render
  draw calls for the phase. A zero value can indicate an unavailable engine
  monitor.

The report covers the start to checkpoint 1, mid-race to checkpoint 3 and
the final sector. Recording ends when the player finishes or is eliminated.
Two additional rows isolate the first five seconds after GO and the 16 m
around the bridge merge. The merge window applies to either route so the
same stretch can be compared after following the same line. A short window
takes a monitor sample on its first measured frame. An unreached phase or
window shows **NO SAMPLES**. Frame intervals are measured with a
monotonic clock, and the first frame after resuming re-establishes the clock
without including the pause. The report counts long foreground stalls.
The live HUD uses a 120-frame window. Race summaries use five fixed-size
histograms. Godot monitor values are sampled about once per second, with a
first sample for each short window.
The feature is opt-in and copies to the clipboard on request.

**Important:** Automated headless regression establishes that the
optimization rejects irrelevant geometry and preserves core behaviors.
It does **not** measure the actual GPU or frame rate of a Redmi 15 5G.
The Android on-device overlay supplies that evidence.

CI runs `tests/performance_budget.gd` plus existing course, full 120-second
AI navigation, real server network, rare item and Android APK signing tests.
