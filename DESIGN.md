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
  {D} = damage symbol), `image`, `starter`, optional `legendary` and `aliases` metadata, `set` ("2025" for the 104 base definitions including starters; "2026" for the 48 expansion cards).
- Starter cards: `Hacking` (printed name "Hacker", +1 {H}) and `Damage` (printed name "Attack",
  Deal 1 {D}). Each player's starting deck = 8 Hacker + 2 Attack. Starters never go in the center deck.
- Card pools: "2025" selects the base game (102 non-starter cards); "2026" selects base plus expansion (150 non-starter cards, the default). GameState.card_pool persists in saves; older saves default to "2026". In-game card naming, bot Hero names and card searches use the selected pool. Cosmetic human avatars may use any Hero.
- Center deck = one copy of every non-starter card in the selected pool. The five "Botnet" files are
  five copies of Botnet.
- `assets/cards/<id>.jpg` (600x820) card faces; `assets/cards/phreaknic_fottr_tcg_card_back.jpg` card back.
- Subtype matching is by word: "Hero" matches "Hero", "Legendary Hero", "FOTTR Hero",
  "pTFS Hero", "Hero Legend", "Legendary pTFS Hero". "Legendary" matches any subtype with that word.
  "FOTTR Hero" = subtype contains FOTTR and Hero. Name matching ("card named X", "with X in its name")
  is case-insensitive against the printed `name` and official aliases. `What is Truth` has every name.

## Official rules (from the rules card) — implement exactly
Setup: each player shuffles 8 Hacker + 2 Attack. Default life is 24 for two players,
or 10 × number of players for three or four. Choose the first player with the seeded RNG.
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

## House interpretations / official rulings

[reference/rules.md](reference/rules.md) is authoritative: bitwize's research
combines the printed rules, official errata v1.1, confirmed rulings and adopted
defaults. [RULES_NOTES.md](RULES_NOTES.md) records implementation limits only.

- Default life is 24 for two players and 10 × players for three or four; setup
  accepts a custom starting life. A seeded random player starts, followed by seat order.
- The active player orders simultaneous effects, including the forced Rickroll
  buy and permanent triggers. A pending permanent trigger disappears if its source leaves play.
- The defender allocates each prevented point among ICE and other prevention.
  Prevention is mandatory; overflow reaches life. Final-counter text still resolves.
- Buying (including buying for free) triggers buy effects; acquiring without buying
  does not. Buying prohibitions block the forced Rickroll buy, but permit acquisitions.
- A departing permanent goes to its controller's discard. Elimination removes
  controlled permanents from the game and returns reserves under the Center Deck;
  empty Center Row slots refill immediately. Simultaneous elimination of everyone is a draw.
- Name checks include official aliases (`_NASKEY` = `_NSAKEY`); Rick Astley's
  printed Hero Legend type counts as Legendary Hero. What is Truth has every name.
- DeMartian/m8trix and "this turn" combinations work in either order; Mog's Ice
  Cream and Walmart require their named partner to have been played earlier.
- Etch-a-Sketch copies text while keeping its identity and ignoring copied play
  restrictions. "This card" moves Etch itself. The Book's attached Actions play
  in the controller's chosen order. Oprah Wonka uses the next living splitter.

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

## Online play (core)

`scripts/net/game_server.gd` owns the authoritative engine for a room of 2–4 seats.
Call `setup(seats, card_pool, starting_life, seed)`, attach transports, and await
`start()`. Seat dictionaries contain `name`, `hero`, `bot`, and numeric `difficulty`
(0 Script Kiddie, 1 Phreak, 2 Elite). Only the server uses the seeded game RNG.
`tokens[seat]` is a cryptographically random credential to distribute through a
future trusted lobby; tokens are never included in player messages. A room runs
in process today; WebSockets, hosting, lobby credentials, and table UI integration
are future work.

`NetTransport` exposes `send(Dictionary)`, `received(Dictionary)`, `closed`, and
`close()`. `LoopbackTransport.pair()` returns connected endpoints, JSON round trips
every send, and delivers on the next process frame. `pair(false)` permits explicit
`pump()` calls. Closing either endpoint disconnects both. Integral JSON numbers
are normalized recursively on receipt. Visible card UIDs are action targets;
clients cannot submit engine objects or change authoritative state.

The protocol uses dictionaries with a `t` field:

| Direction | Type | Fields |
| --- | --- | --- |
| Client → server | `hello` | `seat`, `token`, `version` |
| Client → server | `action` | `kind`: `play`, `buy`, `reserve`, `activate`, `end_turn`, `play_all`, or `play_basics`; card actions require `uid`; activate accepts `index` (default 0) |
| Client → server | `answer` | `id` (prompt ID), `value` |
| Server → client | `welcome` | `seat`, `seats` (public name/hero/bot/difficulty records), `version`, `card_pool`, `starting_life` |
| Server → client | `view` | `state` (NetView envelope below) |
| Server → client | `prompt` | `id`, `kind`, `text`, kind-specific fields below |
| Server → client | `prompt_done` | `id` |
| Server → client | `log` | `text`, `seat` (active seat at emission) |
| Server → client | `event` | `kind`, kind-specific fields below |
| Server → client | `game_over` | `winner` (seat, or -1 for a draw) |
| Server → client | `error` | `reason` |

A hello must match `application/config/version` exactly and authenticate a human
seat. Failure returns an error without authenticating. A new connection with the
same token replaces the old connection. Reconnect sends welcome, a fresh full
view, any outstanding prompt, and game_over if applicable. Answer IDs are random,
room-private pending requests bound to their seat; invalid/stale answers leave the
request pending. Actions must be legal under engine queries, on the sender's
active turn, with no pending decision or action at that reaction depth. Engine
busy state and nested human TOCTOU reaction turns are respected. The shared
`GameEngine.play_all` implementation retains the local UI's 200-action bound.

Prompt kinds match every Decider method. `choose_option` has `options` and returns
an option index. `choose_options` adds `count` and returns distinct indices.
`choose_cards` has `cards`, `min`, `max` and returns distinct UIDs. Prompt card
records have `uid`, `id`, `owner`, `controller`, `counters` and go only to the
choosing seat, including cards an effect specifically permits that seat to inspect.
`choose_player` has `players` (seat numbers) and returns a seat. `choose_number`
has `allowed` and returns a member. `confirm` returns a Boolean. `name_a_card` has
`card_pool` and returns a card ID in that pool. `allocate_prevention` has `amount`
and `sources` (`card` record or null, `capacity`, `full`, `name`), and returns
nonnegative point counts in source order, totaling mandatory prevention.
Simultaneous triggers and attached Action ordering use `choose_option` through
the existing engine, rather than introducing a second ordering API.

Events: `damage_dealt` has `source`, `target`, `amount`; `turn_started`,
`turn_ended`, and `eliminated` have `seat`; `played`, `bought`, `reserved`, and
`draw` have `seat`, `uid`, `id`; `ice_counter_removed` has `uid`. Draw events go
only to the hand's owner. No generic move events expose deck or hand identities.
Engine logs describe public actions and explicit reveals; ordinary draws are not
logged. Explicit engine play/buy/reserve signals also cover attached Action plays and
mandatory start-of-turn buys, without labeling acquisitions as purchases. Events are transient; views are the source of truth.

`NetView.build(engine, seat)` reuses SaveGame's reference/object dictionary codec
but explicitly selects public state. The envelope contains `state`, `objects`,
`seat`, `ready` (server availability for this seat), and `counts` (`center_deck`,
`players: [{deck, hand}]`). It includes all life/alive/hacking, public zones,
counters, attachments, owner/controller, flags, played history, turn state,
configuration and winner; only the receiver's hand has real cards. Each hidden
physical zone contains the appropriate number of `hidden` CardInstances with
fresh cryptographically random negative UIDs for every view. Even if a played
card has subsequently returned to a deck, its physical deck entry is a new
placeholder. Hidden object references in flags are masked too. Authoritative
RNG, logs, coverage, initial card identities, and UID allocation state are omitted.
The RNG seed/state never enters a player envelope. The `hidden` CardDB fallback
is outside the real card catalog so it cannot enter setup pools or affect save
content signatures.

`NetView.apply` reconstructs a mirror GameState without invoking authoritative
save validation (a redacted state intentionally cannot satisfy conservation).
`NetClient` owns a mirror engine solely for rendering and queries; it never runs
rules on that engine. It exposes view_changed, prompt(id, data), prompt_done(id),
log(text), event(data), game_over, error(reason), and message_received(message).
`send_action` and `answer` send protocol messages. Its optional `scripted` mode
uses only mirror state and prompt payloads to select bounded actions and BotDecider
choices. This test policy is deliberately simpler than the authoritative bot;
existing bot strategy is unchanged. Views coalesce to at most one per process
frame per connection, with a deferred latest view if the connection already got
one that frame. Prompts and events need not wait for a view.

The server's injectable `clock` Callable returns monotonic seconds. After 45
seconds a pending human prompt is answered with a fresh Phreak BotDecider, using
the original engine arguments. At 120 seconds disconnected, the seat uses
Phreak BotDecider/BotPlayer until authenticated reconnect, including reaction
turns. Reconnection cancels takeover driving at the next completed action; an
already resolving rules action must finish. The bot driver's optional continuation
and completed-action callbacks do not change its default behavior or strategy.

After a completed safe human action or bot action, `snapshot(data)` emits a full
authoritative SaveGame snapshot plus public seats, private seat tokens, protocol
version, and card-catalog signature. `last_snapshot` holds the latest checkpoint.
Snapshots never go to transports. The same engine safety conditions as local
saving apply: idle, no resolving cards, reactions or simultaneous effects; online
saving allows any active seat and the terminal state. No coroutine/prompt stack
is serialized. `restore(snapshot)` validates the SaveGame, catalog and version,
restores RNG and object identities, rebuilds deciders, and resumes at that safe
point without starting the turn twice. If a container dies during an action,
recovery returns to the last completed safe checkpoint. Storage/durability belongs
to the future host. Clients reconnect with their persisted tokens. Snapshots
contain private decks/RNG/tokens and must be kept server-side.

Run `tests/net_checks.gd` headlessly with temporary `XDG_DATA_HOME` (and temporary
`XDG_CONFIG_HOME` for editor operations). It exercises JSON loopback games,
redaction, illegal actions, every decider method, timeouts, takeover/reconnect,
private draws, reaction turns, and snapshot/restore with card conservation.
