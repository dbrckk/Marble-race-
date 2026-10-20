# Marble Race — star-list review (2026-10-20)

Catalog source: `dbrckk/star-list` (current `main`, `catalog.json`,
`stacks.json`, `RECOMMENDER.md`). Queries run using its actual
`scripts/recommend.py`; the catalog is a shortlist, not dependency approval.

## Recommended resources and decision

| Repository | Relevance | Decision |
| --- | --- | --- |
| `godotengine/godot-demo-projects` | Open Godot gameplay, VFX and physics samples | **Study reference examples** and adapt implementation, after checking each asset's terms. Keep Godot 4 Compatibility renderer. |
| `godotengine/godot` | Core mobile engine | **Keep current engine** (Godot 4.5.1); upgrade only after Android test matrix. |
| `Coding-Solo/godot-mcp` | Editor automation and reproducible scene reviews | **Optional build tooling**, not a required runtime component. |
| `heroiclabs/nakama` | Backend accounts, persistence and large-room matchmaking | **Evaluate later** if concurrency needs justify hosting/database overhead; do not replace working WebSocket physics authority without a migration plan. |
| `Calinou/awesome-godot` | Community directory | **Research only**; review third-party licenses and maintenance before integrating. |
| `KenneyNL/Starter-Kit-3D-Platformer` | Input/gamefeel and layout ideas | **Reference patterns** only; unrelated platformer gameplay should not be transplanted blindly. |

## Applied in this version

The **Godot Gameplay and VFX** stack guided prioritizing engine-native quality
budgets, not adding an untested external shader or plugin. A measured AUTO
graphics profile is integrated with the existing cached meshes, sphere LOD,
shadow settings, effects and current settings persistence.

This does **not** claim the listed repos are bundled with this game or that
reading a repository's description constitutes independent license review.

## Next priorities

- Verify effective AUTO changes and heat on a physical Android device, target a
  sustained 55–60 FPS in typical races.
- Test WebSocket matchmaking after server cold start, with two real Android
  devices on separate networks.
- Improve course readability and challenge through measured playtesting rather
  than more decorative geometry.
- Expand beyond one dedicated multiplayer room only with server capacity and
  concurrency tests.
