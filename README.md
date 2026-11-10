# PhreakNIC CCG

A digital version of the **FOTTR TCG: PhreakNIC** deck-building card game, built with Godot 4.7. Version **0.06**.

Original FOTTR TCG created by 5ud0, bitwize & crook3dfingers (FOTTR).

![Mid-game table](docs/screenshot_midgame.png)

![Main menu](docs/screenshot_menu.png)

_Screenshots are from the current version and are refreshed with every release._

## Download & play (alpha)
The game is in **alpha testing**. Grab the latest build from the [Releases page](https://github.com/Nirtom84/PhreakNIC-CCG/releases/latest):

| Platform | Download | How to run |
|---|---|---|
| Windows 10/11 (64-bit) | [PhreakNIC-CCG-windows.zip](https://github.com/Nirtom84/PhreakNIC-CCG/releases/latest/download/PhreakNIC-CCG-windows.zip) | Unzip and double-click the `.exe`. The app isn't code-signed yet, so Windows SmartScreen may warn you: choose **More info → Run anyway**. |
| Linux (x86_64) | [PhreakNIC-CCG-linux.zip](https://github.com/Nirtom84/PhreakNIC-CCG/releases/latest/download/PhreakNIC-CCG-linux.zip) | Unzip and run the `.x86_64` file. If it won't start, make it executable: `chmod +x PhreakNIC-CCG-*.x86_64`. |
| Android 7.0+ (64-bit) | [PhreakNIC-CCG-android.apk](https://github.com/Nirtom84/PhreakNIC-CCG/releases/latest/download/PhreakNIC-CCG-android.apk) | Open the file on your phone and allow your browser or file manager to install unknown apps. Plays in landscape. |

Pick an opponent and start. Click a hand card to play it, click a center-row card to buy or reserve it,
click your reserved card to buy it, use the buttons on your permanents for their abilities, then **End Turn**.
Hover or right-click any card to zoom. On a touch screen: tap to play or buy, press and hold any card to read it, drag to scroll.
Your turn ends by itself once you have nothing left to do (switch **Auto-end turn** off if you'd rather press End Turn).
**Menu** (or Back / Escape) opens the in-game menu: options, rules, **Save game**, **Main menu** and **Exit**. The game also saves at the start of each of your turns and when you leave, and **Resume game** on the main menu picks it up again.
On the main menu you can type a handle or **Pick a Hero** to play as one of the Hero cards, with their art as your avatar.
Under **Card set**, choose **PhreakNIC 2025** (the base game, 102 cards) or **PhreakNIC 2026** (base game plus the 48-card 2026 expansion, 150 cards).

### Found a bug?
Please [open an issue](https://github.com/Nirtom84/PhreakNIC-CCG/issues/new/choose) and pick **Bug report** or **Card or rules problem**. Include the version from the bottom-right corner of the main menu, your platform, and the Network Log lines or a screenshot if you can.

### Run from source
Install [Godot 4.7](https://godotengine.org/download) and run from the project folder:
```bash
godot4.7.1 --path .
```

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
- `data/cards.json` — all 152 cards (cost, type, rules text, and `set`: 2025 base or 2026 expansion), transcribed from the card art
- `assets/cards/` — 600px card faces and the card back
- `scripts/core/` — rules engine (`rules.gd`), one effect handler per card (`effects.gd`)
- `scripts/ai/` — bots and difficulty levels
- `scripts/ui/`, `scenes/` — menu and game table

## Sound
Retro sounds have menu volume/mute controls and a table mute button. Regenerate the WAV files from the project root with `python3 tools/make_sounds.py`.

## Building Linux, Windows and Android versions
```bash
tools/build_all.sh            # all three, into build/, then packaged into build/release/
tools/build_all.sh android    # or just one: linux | windows | android
tools/build_all.sh release    # zip the builds under stable names in build/release/ for a GitHub Release
```
- **Linux**: `build/linux/PhreakNIC-CCG-v<version>.x86_64` — a single file, run it directly.
- **Windows**: `build/windows/PhreakNIC-CCG-v<version>.exe` — a single file, double-click it.
- **Android**: `build/android/PhreakNIC-CCG-v<version>-debug.apk` — install with `adb install` or by copying it to the phone (allow "install unknown apps"). It is signed with the standard debug key; publishing on Google Play needs a release keystore.

One-time setup on the build machine: Godot 4.7.1 export templates in `~/.local/share/godot/export_templates/4.7.1.stable/`, JDK 17 (`~/.local/opt/jdk-17`), and the Android SDK in `~/Android/Sdk` with `platform-tools`, `build-tools;36.1.0` and `platforms;android-36`. Export settings live in `export_presets.cfg`.

## Tests
```bash
godot4.7.1 --headless --path . -s tests/sim.gd           # 300 bot-vs-bot games (both card sets, 2-4 players) plus the focused rules scenarios
godot4.7.1 --headless --path . -s tests/ui_smoke.gd      # table UI drives full turns
godot4.7.1 --headless --path . -s tests/ui_state_sync.gd # UI always matches engine state
godot4.7.1 --headless --path . -s tests/touch_checks.gd  # taps, long-press, drag scrolling, Back button
godot4.7.1 --headless --path . -s tests/v05_checks.gd    # auto-end turn, dialog sizing, wide screens, Hero avatars
godot4.7.1 --headless --path . -s tests/save_checks.gd   # save/resume round trips and the in-game menu
godot4.7.1 --headless --path . -s tests/v06_checks.gd    # 2025 / 2026 card sets
godot4.7.1 --path . -s tools/screenshot.gd --resolution 1920x1080 -- out.png 8   # rendered screenshot
```

## Visuals and fonts
Neon HUD panels, terminal backgrounds and bundled fonts require no system fonts. The menu’s Visual effects switch disables animated backgrounds and decorative effects and is saved with sound settings. Card artwork is unchanged.

Fonts in `assets/fonts/`: JetBrains Mono Nerd Font (regular/bold, SIL Open Font License; `LICENSE-JetBrainsMono-OFL.txt`), Noto Sans Mono Condensed Black (`LICENSE-NotoSansMono.txt`), and Droid Sans Japanese (Apache 2.0; `NOTICE-DroidSansJapanese-Apache.txt`). The matrix background uses lightweight procedural glyphs.
