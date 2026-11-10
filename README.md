# PhreakNIC CCG

A digital version of the **FOTTR TCG: PhreakNIC** deck-building card game, built with Godot 4.7.

![Mid-game](docs/screenshot_midgame.png)

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
The official rules are on the in-game Rules screen (the two rules cards). Gaps the cards don't cover are
documented in [RULES_NOTES.md](RULES_NOTES.md). Design and architecture: [DESIGN.md](DESIGN.md).

## Project layout
- `data/cards.json` — all 152 cards (cost, type, rules text), transcribed from the card art
- `assets/cards/` — 600px card faces and the card back
- `scripts/core/` — rules engine (`rules.gd`), one effect handler per card (`effects.gd`)
- `scripts/ai/` — bots and difficulty levels
- `scripts/ui/`, `scenes/` — menu and game table

## Tests
```bash
godot4.7.1 --headless --path . -s tests/sim.gd           # 300 bot-vs-bot games, 2-4 players
godot4.7.1 --headless --path . -s tests/rules_checks.gd  # focused rules scenarios
godot4.7.1 --headless --path . -s tests/ui_smoke.gd      # table UI drives full turns
godot4.7.1 --headless --path . -s tests/ui_state_sync.gd # UI always matches engine state
godot4.7.1 --path . -s tools/screenshot.gd --resolution 1920x1080 -- out.png 8   # rendered screenshot
```
