# Playable UI

Launch from the project directory:

```
~/.local/bin/godot4.7.1 --path .
```

On a clean checkout, import first with `--headless --editor --import --quit`.
In restricted environments set `XDG_DATA_HOME=/tmp/phreak-godot-data` and
`XDG_CONFIG_HOME=/tmp/phreak-godot-config`.

The main scene is `scenes/menu.tscn`; `scenes/table.tscn` also runs directly.
`menu.gd`'s `PLAYER_COUNTS` enables 3/4-player menu choices in one line.
Table `player_count`, `difficulty`, `scripted_decider`, and `auto_drive` can be
configured before adding the scene to the tree. Production uses HumanDecider;
UI smoke tests supply deterministic answers and drive the same action handlers.

Left-click hand cards to play, market cards for buy/reserve choices, and your
sideways reserved cards to buy. Green/gold tints mark legal plays/purchases.
Right-click or hold the pointer over a card to inspect; move away to dismiss.
Permanents expose legal engine abilities and counter totals. Hands and permanent
rows scroll horizontally; the overall table scrolls vertically when crowded.
Discard and removed piles open browsable image grids. Engine decisions use a
blocking modal, including human decisions requested during bot turns.

BotPlayer.action_delay defaults to zero; only the table enables pacing. The speed
switch takes effect for the next bot turn. Movement feedback is a brief fade on
arriving visible cards and a banner pulse, rather than a full travel animation.

Verification:

```
~/.local/bin/godot4.7.1 --headless --path . -s tests/sim.gd
~/.local/bin/godot4.7.1 --headless --path . -s tests/ui_smoke.gd
~/.local/bin/godot4.7.1 --headless --path . --quit-after 600
~/.local/bin/godot4.7.1 --headless --path . res://scenes/table.tscn --quit-after 600
```
