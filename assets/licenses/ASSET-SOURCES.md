# Third-party asset licensing (offline game)

Only the following third-party files ship with the game. All other game code, 3D geometry, procedural textures, icon and synthesized soundtrack/tones are original to this repository.

| Assets used | Source | License |
|---|---|---|
| `assets/audio/sfx/glass_*.ogg`, `wood_*.ogg`, `plank.ogg`, `bell.ogg` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds), as mirrored with source attribution in [GeorgeQLe/assets-sfx-combat](https://github.com/GeorgeQLe/assets-sfx-combat) | Creative Commons Zero **CC0 1.0** |
| `assets/audio/sfx/ui_click.ogg`, `ui_select.ogg` | [Kenney UI Audio](https://kenney.nl/assets/ui-audio), mirrored in [Calinou/kenney-ui-audio](https://github.com/Calinou/kenney-ui-audio) | **CC0 1.0**, see `Kenney-UI-CC0.txt` |
| `assets/fonts/Rajdhani-Bold.ttf` and `Rajdhani-Medium.ttf` | [Google Fonts: Rajdhani](https://github.com/google/fonts/tree/main/ofl/rajdhani) | **SIL Open Font License 1.1**, see `Rajdhani-OFL.txt` |

Kenney CC0 does not require attribution but we credit the maker. The font has an attribution/license preservation requirement. If replacing a source sample, verify its license before publishing.

Music and tonal cues were algorithmically authored for this game by `tools/generate_assets.py` (no copyrighted commercial tracks or soundalikes).


### Original v0.8 rubber bumper sounds

`assets/audio/sfx/bumper_soft.ogg` and `assets/audio/sfx/bumper_hard.ogg` are original algorithmically synthesized sounds, reproducible using `tools/generate_bump_sounds.py`. They are not redistributions of third-party audio.

### Original v0.10 satin lacquer map

`assets/textures/lacquer_micro.png` is an original deterministic procedural texture. Recreate it with `tools/generate_lacquer_micro.py`; no third-party sample/image assets are included.
