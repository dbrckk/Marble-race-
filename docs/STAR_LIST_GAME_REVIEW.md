# Marble Race — star-list integration review (2026-10-20)

Source: `dbrckk/star-list`, `catalog.json` on `main` at commit
`68ca68f6121e4bcce8a33af0293a4294e5658219` (999 indexed repositories).
This is a compatibility and licensing review, not permission to copy all assets
from another project. No external source files or licensed artwork are bundled by
this review. The existing Godot 4.5.1 GL Compatibility architecture is retained.

| Catalog source | Catalog license | Decision for Android Marble Race |
|---|---|---|
| [Godot demo projects](https://github.com/godotengine/godot-demo-projects) | MIT | **Reference**: authoritative Godot engine patterns and rendering / scene test examples; adapt native mechanisms only |
| [GDQuest Godot Shaders](https://github.com/gdquest-demos/godot-shaders) | MIT | **Reference**: study material visual effects and budget them for GL Compatibility; do not import costly fullscreen shaders without mobile profiling |
| [Kenney Starter Kit 3D Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | MIT (repo metadata) | **Later**: audit gameplay feedback, asset provenance and license per file before importing any art; camera and controls already custom |
| [GodotFirebase](https://github.com/GodotNuts/GodotFirebase) | MIT | **Defer**: Firebase changes deployment/privacy/costs; unnecessary for anonymous dedicated-match authority |
| [GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves) | MIT | **Reject for now**: FFT ocean waves do not fit a wooden marble racing game and increase mobile GPU load |
| [godot-mcp](https://github.com/Coding-Solo/godot-mcp) | MIT | **Optional tooling**: no runtime benefit; headless Godot smoke, network simulations and Android CI already present |
| [OpenLiberty](https://github.com/openfw-game/OpenLiberty) | MIT (repo metadata) | **Reject**: unrelated open-world game architecture; imported GTA-world assets can have separate rights issues |

## Findings applied in the v1.9 product pass

1. **Keep engine-native, lightweight behavior** instead of integrating heavy
   third-party Godot modules. The client now reports actual server round-trip
   latency and disconnects from a stalled match, preserving its offline gameplay.
2. **Inspect every layer of production networking**: dedicated Godot physics remains
   authoritative; a 100%-Python-standard-library HTTP/WebSocket edge process
   answers Render's health probes without feeding them into Godot's WebSocket
   parser, and tunnels actual WebSocket upgrades byte-for-byte.
3. **Reproducible playtests**: use 2 real Godot processes against the game server,
   plus bounded unit regressions for latency, failed admission and missing
   snapshots. Existing 3-course and Android tests remain the release gate.
4. **Mobile budget before gratuitous effects**: the GL Compatibility rendering
   pipeline remains unchanged until actual Android FPS/battery measurements
   justify additional shader features.

## Next adoption criteria

Only import a third-party component when it provides a measurable win for gameplay,
performance or art quality, has a verified source-file license, works with Godot 4.5.1
and GL Compatibility, does not add a non-free service dependency, and passes Android
CI plus a real-device acceptance test. Favor custom shader demonstrations and
license-clean visual resources for subsequent aesthetic work, not Unity/Roblox plugins.

Known separate roadmap item: multiple simultaneous dedicated-server rooms. Today's
single-instance online matchmaking still supports one room with up to four humans.
A network-quality meter or gateway does **not** remove that concurrency limit.
