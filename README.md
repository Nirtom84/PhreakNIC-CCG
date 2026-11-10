# PhreakNIC CCG

A digital version of the **FOTTR TCG: PhreakNIC** deck-building card game, built with Godot 4.7. Version **0.04**.

Original FOTTR TCG created by 5ud0, bitwize & crook3dfingers (FOTTR).

![Mid-game table](docs/screenshot_midgame.png)

![Main menu](docs/screenshot_menu.png)

_Screenshots are from the current version and are refreshed with every release._

## Play
```bash
godot4.7.1 --path .
```
Pick an opponent and start. Click a hand card to play it, click a center-row card to buy or reserve it,
click your reserved card to buy it, use the buttons on your permanents for their abilities, then **End Turn**.
Hover or right-click any card to zoom.

### Bot difficulty
| Level | Plays like |
|---|---|
| Script Kiddie | Plays everything, buys the priciest card it can, random choices |
| Phreak | Values cards, plays draw first, makes sensible choices, uses paid abilities |
| 31337 Elite | Adds lethal checks, deck thinning, reserving/denying cards and combo hunting |

2 players today; the engine already supports 2–4 seats (3–4 player tables are disabled in the menu for now).

## Rules
The official rules are on the in-game Rules screen (scrollable written rules). Gaps the cards don't cover are
documented in [RULES_NOTES.md](RULES_NOTES.md). Design and architecture: [DESIGN.md](DESIGN.md).

## Project layout
- `data/cards.json` — all 152 cards (cost, type, rules text), transcribed from the card art
- `assets/cards/` — 600px card faces and the card back
- `scripts/core/` — rules engine (`rules.gd`), one effect handler per card (`effects.gd`)
- `scripts/ai/` — bots and difficulty levels
- `scripts/ui/`, `scenes/` — menu and game table

## Sound
Retro sounds have menu volume/mute controls and a table mute button. Regenerate the WAV files from the project root with `python3 tools/make_sounds.py`.

## Building Linux, Windows and Android versions
```bash
tools/build_all.sh            # all three, into build/
tools/build_all.sh android    # or just one: linux | windows | android
```
- **Linux**: `build/linux/PhreakNIC-CCG-v<version>.x86_64` — a single file, run it directly.
- **Windows**: `build/windows/PhreakNIC-CCG-v<version>.exe` — a single file, double-click it.
- **Android**: `build/android/PhreakNIC-CCG-v<version>-debug.apk` — install with `adb install` or by copying it to the phone (allow "install unknown apps"). It is signed with the standard debug key; publishing on Google Play needs a release keystore.

One-time setup on the build machine: Godot 4.7.1 export templates in `~/.local/share/godot/export_templates/4.7.1.stable/`, JDK 17 (`~/.local/opt/jdk-17`), and the Android SDK in `~/Android/Sdk` with `platform-tools`, `build-tools;36.1.0` and `platforms;android-36`. Export settings live in `export_presets.cfg`.

## Tests
```bash
godot4.7.1 --headless --path . -s tests/sim.gd           # 300 bot-vs-bot games, 2-4 players
godot4.7.1 --headless --path . -s tests/rules_checks.gd  # focused rules scenarios
godot4.7.1 --headless --path . -s tests/ui_smoke.gd      # table UI drives full turns
godot4.7.1 --headless --path . -s tests/ui_state_sync.gd # UI always matches engine state
godot4.7.1 --path . -s tools/screenshot.gd --resolution 1920x1080 -- out.png 8   # rendered screenshot
```

## Visuals and fonts
Neon HUD panels, terminal backgrounds and bundled fonts require no system fonts. The menu’s Visual effects switch disables animated backgrounds and decorative effects and is saved with sound settings. Card artwork is unchanged.

Fonts in `assets/fonts/`: JetBrains Mono Nerd Font (regular/bold, SIL Open Font License; `LICENSE-JetBrainsMono-OFL.txt`), Noto Sans Mono Condensed Black (`LICENSE-NotoSansMono.txt`), and Droid Sans Japanese (Apache 2.0; `NOTICE-DroidSansJapanese-Apache.txt`). The matrix background uses lightweight procedural glyphs.
