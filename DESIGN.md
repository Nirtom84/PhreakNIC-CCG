# PhreakNIC CCG (FOTTR TCG) — Godot design spec

Godot 4.7, GDScript only (typed GDScript where practical). Target 1920x1080, stretch mode
`canvas_items`, aspect `expand`. Binary on this machine: `~/.local/bin/godot4.7.1`.

## Goals
- Single human vs computer bot. 2 players now; **the engine must support 2–4 players**
  (any mix of human/bot seats) so 3–4 players can be switched on later without engine changes.
- 3 bot difficulty levels, named after hacker levels:
  1. **Script Kiddie** (easy)
  2. **Phreak** (medium)
  3. **31337 Elite** (hard)
- The card images already contain art and rules text: the UI shows the images, and the engine
  implements each card's text as code.

## Data
- `data/cards.json`: one entry per unique card (152). Fields: `id` (file stem, the stable key),
  `name` (printed title), `cost`, `kind` ("Action" | "Permanent"), `subtypes` (e.g.
  "Legendary Hero", "Exploit", "Technology", "Location", "Organization", "Event",
  "FOTTR Hero", "pTFS Hero"), `type_line`, `hack`, `damage`, `text` ({H} = hacking symbol,
  {D} = damage symbol), `image`, `starter`.
- Starter cards: `Hacking` (printed name "Hacker", +1 {H}) and `Damage` (printed name "Attack",
  Deal 1 {D}). Each player's starting deck = 8 Hacker + 2 Attack. Starters never go in the center deck.
- Center deck = one copy of every non-starter card (150 cards). The five "Botnet" files are
  five copies of Botnet.
- `assets/cards/<id>.jpg` (600x820) card faces; `assets/cards/phreaknic_fottr_tcg_card_back.jpg` card back.
- Subtype matching is by word: "Hero" matches "Hero", "Legendary Hero", "FOTTR Hero",
  "pTFS Hero", "Hero Legend", "Legendary pTFS Hero". "Legendary" matches any subtype with that word.
  "FOTTR Hero" = subtype contains FOTTR and Hero. Name matching ("card named X", "with X in its name")
  is case-insensitive against the printed `name`. `What is Truth` has every name.

## Official rules (from the rules card) — implement exactly
Setup: each player shuffles 8 Hacker + 2 Attack. Each player's life = 10 × number of players.
Shuffle the rest = Center Deck. Deal 5 face up = Center Row. Each player draws 5.
Turn: play any number of cards from hand, in any order. Played actions go to the discard pile
immediately after resolving. Damage {D} reduces the life of **all other players**. Hacking {H}
is spent to buy cards from the center row; cost = upper-left number. Whenever a card leaves the
center row, refill that slot from the center deck immediately. End of turn: discard the rest of
the hand, draw 5. Play passes clockwise (seat order). Drawing from an empty deck: shuffle the
discard pile into the deck first. Zero life = out of the game. Last player alive wins.
Reserving: instead of buying or otherwise acquiring anything on the turn, a player may reserve
one card: take it from the center row (slot refills) into their own reserve area. Only that
player may buy it later (from their reserve, paying its cost); it stays until purchased.
A reserved card is not in play and does nothing. Reserving is not buying or acquiring.
Additional: if several sources would prevent damage, their controller chooses the order.
Losing life is the same as taking damage, and prevention prevents life loss.

## House interpretations (rules gaps) — put these in `RULES_NOTES.md` too
- Unspent {H} is lost at end of turn. Spending {H} for an ability uses the same pool.
- Bought / acquired cards go to the buyer's discard pile unless a card says otherwise.
  "Acquire" = gain without paying. Buying for free counts as buying.
- Reserve: at most one reserve per turn, only if nothing was bought or acquired yet this turn,
  and after reserving you can't buy or acquire for the rest of the turn (Tips and tricks lifts both limits for that turn).
- Permanents: when played they go into the controller's play area (not the discard pile) and
  stay until a card removes them. "Discard a permanent" = put it in its owner's discard pile.
  "Control" = in your play area. Gaining control moves the permanent into your play area; if
  it later leaves play it goes to its **owner's** discard pile (track `owner` and `controller`).
- "In play" = permanents in any play area. Action cards are only "played this turn".
- ICE counters: when a player with ICE locations would take damage, each point of damage
  removes one counter instead. Damage beyond the counters available passes on to the next
  prevention source, then to life. Order: Military-Grade Card Encapsulation / Phreaknic
  Network (prevent all) first, then ICE locations in the order the controller picks (bots and
  the default UI order: fewest counters first). A location that runs out of counters triggers its
  "when you remove the last counter" text.
- "Each player loses 1 life" (r0nk, Air Conditioning, etc.) and "lose N life" are damage for prevention purposes,
  but are not "dealing damage" for CTF Bangers or Dick Van Dyke Stamp.
- Cost reductions stack and never go below 0. "Hero cards cost 1 less" etc. apply to center row and reserved cards.
- Center deck empty: the slot stays empty. Removed-from-game cards go to a shared `removed` zone (face up).
- Elimination: a player at 0 or less life is out immediately, mid-effect; their cards stay
  where they are but do nothing (permanents they control are removed from play to their owner's discard). If the active player dies, their turn ends.
  If all remaining players die at once, the active player wins if alive, otherwise it is a draw.
- Win/lose by card: Lowes Shopping Cart 25 counters → that player wins. The Juice 5th counter
  → that player loses (eliminated).
- Rickroll in the center row at the start of a player's turn: that player must buy it (cost 0,
  pay normally after reductions) before doing anything else; this counts as buying (so they can't reserve that turn).
- "Once per turn" permanent abilities and "as often as you like" paid abilities are
  **activated** by the controller on their turn (UI button on the permanent; bots decide).
  Triggered abilities ("at the beginning of your turn", "whenever ...") resolve automatically,
  asking for choices only when needed.
- "Choose one / choose two" and "you may" are player decisions (human: dialog; bot: AI).
- Jenny: "Pay 8, 6, 7, 5, 3, 0, or 9" — pay that much {H} from the pool, deal that much damage.
- Oprah Wonka: the player to the left (next seat) splits the five cards into two piles.
- TOCTOU: reaction, checked whenever the holder would be eliminated.
- Touch Grass "end of your next turn": removed at the end of the controller's next turn after the one it was played on.
- FOTTR Greatest Hits Vol 2 "a card with Rick Astley in the art": the cards Rick Astley,
  Rickroll, Never Gonna Give You Up, Never Gonna Let You Down count. Keep this list in one constant.
- Etch-a-Sketch: choose an action card in another player's discard pile; resolve its effect as if
  you played it (the copied card stays where it is).
- Treasure Hunters: if no card of that cost is found, nothing is acquired; shuffle the center deck afterward either way.

## Architecture (keep engine and UI separate)
```
project.godot
data/cards.json
scripts/
  core/card_db.gd          # autoload "CardDB": loads cards.json, lookup by id, subtype/name helpers
  core/card_instance.gd    # RefCounted: uid, card id, owner, controller, counters, attached cards, flags
  core/player_state.gd     # deck, hand, discard, play_area (permanents), reserve, life, alive, seat, is_bot, difficulty
  core/game_state.gd       # zones (center_deck, center_row[5], removed), players, turn state, rng(seed), log
  core/rules.gd            # GameEngine: turn flow, play/buy/reserve/activate, damage & prevention, draw, win check
  core/effects.gd          # per-card effect handlers keyed by card id (one function per card) + triggers
  core/decider.gd          # abstract decision interface (see below)
  ai/bot_decider.gd        # bot implementation with the 3 difficulties
  ai/bot_player.gd         # drives a bot's whole turn (play order, buys, reserve, activations)
  ui/...                   # scenes + scripts for menu and table
tests/
  sim.gd                   # headless: runs N bot-vs-bot games for 2, 3 and 4 players, all difficulties
```
### Decisions
All engine choices go through one async interface so the same engine serves humans and bots:
```gdscript
# Every function is awaited by the engine (bots return immediately; the UI shows a dialog and awaits a signal).
func choose_option(player, prompt: String, options: Array[String]) -> int
func choose_options(player, prompt: String, options: Array[String], count: int) -> Array[int]
func choose_cards(player, prompt: String, cards: Array, min_n: int, max_n: int) -> Array   # returns subset of CardInstances
func choose_player(player, prompt: String, players: Array) -> PlayerState
func choose_number(player, prompt: String, allowed: Array[int]) -> int
func confirm(player, prompt: String) -> bool   # "you may ..."
func name_a_card(player, prompt: String) -> String   # card id (I've got the Logs)
```
`GameEngine` holds one decider per player. The engine emits signals the UI listens to
(`state_changed`, `log_message(text)`, `card_moved(card, from_zone, to_zone)`,
`damage_dealt(source_player, target_player, amount)`, `turn_started(player)`, `game_over(winner)`)
so the UI never mutates state directly; it calls engine actions:
`play_card(player, card)`, `buy_card(player, card)` (center row or own reserve),
`reserve_card(player, card)`, `activate(player, permanent, ability_index)`,
`end_turn(player)`, and query helpers `can_play`, `can_buy`, `effective_cost`, `can_reserve`,
`activatable_abilities(player, permanent) -> Array[{index, label, enabled}]`.

### Bots
- **Script Kiddie**: plays every card in hand in hand order, buys the most expensive affordable card
  (random tie-break), random choices for options, never uses reserve, uses activations only if free.
- **Phreak**: card-value heuristic (damage ≈ 1.0/pt, hack ≈ 0.9/pt, draw ≈ 1.2/card, life ≈ 0.5/pt,
  ICE ≈ 0.6/counter, permanents valued by expected turns in play); plays draw cards first, then the rest;
  sensible choices (discards lowest value, removes starter Hackers/Attacks with remove effects late game,
  never discards own useful permanents); spends leftover {H} on paid abilities.
- **31337 Elite**: everything Phreak does plus: lethal check (if reachable damage ≥ opponent's
  effective life including ICE/prevention, go all-in on damage); deck thinning; reserve a strong
  card it can afford next turn when it can't buy anything good now; denies strong cards to the
  opponent by reserving; picks combos (FOTTR heroes trio, Botnets, Never Gonna pair, Nirtom +
  Reps4Thor, DeMartian + m8trix); smart prevention ordering; smart Oprah Wonka splits.
- Bots must never stall: each bot turn is bounded (e.g. max 200 actions) then ends the turn.

### Tests (must pass headless)
`godot4.7.1 --headless --path . -s tests/sim.gd` runs ≥200 full bot games (mix of 2/3/4 players and
difficulties, fixed seeds) with no script errors, every game ends (turn cap 200 → counted as draw),
prints win rates by difficulty (Elite should beat Script Kiddie clearly), card conservation checks
(total cards across all zones constant, apart from cards created by nothing), and per-card "played at least once" coverage.
