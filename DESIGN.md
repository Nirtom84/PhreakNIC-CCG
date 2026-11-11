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
- `data/cards.json`: 152 original card definitions plus five Mognet effect/copy definitions. Fields: `id` (file stem, the stable key),
  `name` (printed title), `cost`, `kind` ("Action" | "Permanent"), `subtypes` (e.g.
  "Legendary Hero", "Exploit", "Technology", "Location", "Organization", "Event",
  "FOTTR Hero", "pTFS Hero"), `type_line`, `hack`, `damage`, `text` ({H} = hacking symbol,
  {D} = damage symbol), `image`, `starter`, optional `legendary` and `aliases` metadata, `set` ("2025" for the 104 base definitions including starters; "2026" for the 48 expansion cards).
- Starter cards: `Hacking` (printed name "Hacker", +1 {H}) and `Damage` (printed name "Attack",
  Deal 1 {D}). Each player's starting deck = 8 Hacker + 2 Attack. Starters never go in the center deck.
- Card pools: "2026mog" selects Base Set + Expansion 1 · Mog Variant (short: Mog Variant · PhreakNIC 27), replacing the 48 illustrated cards and all five Botnet copies while retaining 150 center cards; "2025" selects the base game (102 non-starter cards); "2026" selects base plus expansion (150 non-starter cards, the default). GameState.card_pool persists in saves; older saves default to "2026". In-game card naming, bot Hero names and card searches use the selected pool. Cosmetic human avatars may use any Hero.
- Center deck = one copy of every non-starter card in the selected pool. The five "Botnet" files are
  five copies of Botnet.
- `assets/cards/<id>.jpg` (600x820) card faces; `assets/cards/phreaknic_fottr_tcg_card_back.jpg` card back.
- Subtype matching is by word: "Hero" matches "Hero", "Legendary Hero", "FOTTR Hero",
  "pTFS Hero", "Hero Legend", "Legendary pTFS Hero". "Legendary" matches any subtype with that word.
  "FOTTR Hero" = subtype contains FOTTR and Hero. Name matching ("card named X", "with X in its name")
  is case-insensitive against the printed `name` and official aliases. `What is Truth` has every name.

## Official rules (from the rules card) — implement exactly
Setup: each player shuffles 8 Hacker + 2 Attack. Default life is 24 for two players,
or 10 × number of players for three or four. Choose the first player randomly (seeded offline; cryptographic online).
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
  accepts a custom starting life. A random player starts, followed by seat order.
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
Call `setup(seats, card_pool, starting_life, seed, banned = [])`, attach transports, and await
`start()`. Seat dictionaries contain `name`, `hero`, `bot`, and numeric `difficulty`
(0 Script Kiddie, 1 Phreak, 2 Elite). During setup, empty/default bot identities receive unique non-starter Hero names
and IDs from the selected pool, excluding human names (case-insensitive) and Hero
IDs. Independent cryptographic draws select cosmetics without sharing a seed with gameplay. Welcome and snapshots retain these identities.
Only the server runs authoritative randomness. Online engines use Crypto.generate_random_bytes
with unbiased rejection sampling for every bounded choice, including shuffles,
effects, and bot decisions. The numeric setup seed is only an identifier online.
Offline engines retain deterministic seeded randomness. Restore uses stored zone
orders and fresh cryptographic randomness for future choices; no seed replay is needed.
`tokens[seat]` is a cryptographically random credential for direct/loopback use;
the trusted room link installs the seat tokens supplied by its Room. Tokens are
never included in player messages. Production rooms are Cloudflare Durable
Objects, each owning one headless Godot container. Players connect only to the
Room, which authenticates seat tokens and multiplexes their messages over one
trusted room link. Table UI integration remains separate from these transports.

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

When a human prompt opens, every other connected seat receives an event
`waiting` with only `seat` and public `text` ("<name> is choosing…"). Completion
or timeout sends `waiting_done` with only `seat`. Reconnect replays outstanding
waiting indicators after welcome; no prompt IDs, options or cards are included.
The online table displays a non-blocking waiting banner; offline play is unchanged.

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
to the Room Durable Object. Clients reconnect with their persisted tokens. Snapshots
contain private decks/RNG/tokens and must be kept server-side.

Run `tests/net_checks.gd` headlessly with temporary `XDG_DATA_HOME` (and temporary
`XDG_CONFIG_HOME` for editor operations). It exercises JSON loopback games,
redaction, illegal actions, every decider method, timeouts, takeover/reconnect,
private draws, reaction turns, and snapshot/restore with card conservation.

### Room link and dedicated server

Run the exported container with:

```sh
build/server/phreaknic-server.x86_64 --headless -- --server --port 8080
```

`--server` in `OS.get_cmdline_user_args()` switches the menu to
`scenes/server.tscn` before constructing the menu. Normal startup is unchanged.
`scripts/net/server.gd` selects port 8080, overridden by `PORT`, then by
`--port N` after `--`. `LinkServer` listens on `0.0.0.0`. Plain HTTP
`GET /health` returns `HTTP/1.1 200 OK` with body `ok` once listening. The Room
opens `ws://container:8080/link`; there is only one room link. A newly accepted
link closes the previous link and disconnects its virtual seats without resetting
the game. The Room sends `connect` again for currently connected players.
Listening, link up/down, setup/restore and game over each log a line to stdout.

GDScript TCP streams cannot peek or unread a parsed request. `LinkServer` parses
the HTTP headers, handles health/404 itself, and relays `/link` through a private
loopback TCP bridge, replaying the headers to `WebSocketPeer.accept_stream()`.
Godot owns the WebSocket handshake, text framing, fragmentation and control frames;
no custom WebSocket codec is used. The bridge accepts only loopback connections
and never exposes another public port. HTTP handshakes have a 10-second timeout
and 16 KiB header limit. Link buffers accommodate authoritative snapshots.

All link messages are JSON text, one dictionary per frame, with a `t` field.
Integral JSON values are normalized recursively. The container trusts the link:
the Room alone authenticates player sockets and supplies the authenticated seat.

| Room → container | Fields and behavior |
| --- | --- |
| `setup` | `room`, `seats: [{name, hero, bot, difficulty, token}]`, `card_pool`, `starting_life`, `seed`, optional `banned`; creates and starts a new authoritative game. Human seats have `bot: false` and a token; bots have an empty token. |
| `restore` | `room`, `snapshot`; calls `GameServer.restore` on the last stored authoritative checkpoint. |
| `connect` | `seat`, `version`; creates a virtual NetTransport and submits hello with the stored seat token. A version mismatch sends that seat `error` with `reason: "version"`, `need: <server version>`. |
| `disconnect` | `seat`; closes its virtual transport, starting existing disconnect/takeover timers. |
| `from` | `seat`, `msg`; forwards only `action` or `answer` from that authenticated seat. |
| `ping` | no other fields; replies `pong`. |

| Container → Room | Fields and behavior |
| --- | --- |
| `ready` | `version`; once per accepted link. |
| `to` | `seat`, `msg`; private GameServer welcome/view/prompt/prompt_done/log/event/game_over/error for that seat only. |
| `snapshot` | `data`; full authoritative save after each completed action at a safe point. The Room replaces its stored snapshot; never forward this message to players. |
| `over` | `winner`; winning seat or -1 for a draw. |
| `pong` | no other fields. |

Link loss leaves the GameServer processing: bots continue and disconnected humans
are taken over after the existing 120-second timeout. Restore rebuilds the same
seat tokens from the checkpoint and resumes without starting the turn again.
If a container dies during an action, the Room restores its last safe snapshot
and reconnects players.

`WebSocketTransport` is the client NetTransport. Call `connect_to(url)` and
`poll()` from the owning Node's `_process`, then attach the NetClient after its
`connected` signal. It sends JSON text and emits normalized `received`, one
`closed` per connection, and exposes `error`, `close_code`, and `close_reason`.
Use `wss://` with a valid hostname/certificate for browser production exports;
it uses Godot's browser WebSocket implementation without custom headers.

The additional `Server` Linux export preset is dedicated-server, x86_64, with
embedded PCK at `build/server/phreaknic-server.x86_64`. It retains the Linux
include/exclude filters and additionally excludes `cloudflare/*`. Resource
stripping uses Godot's dedicated-server defaults, retaining scripts and data.
`tools/build_all.sh server` exports it with `--export-release`; the default target
list is unchanged. Export templates must be installed in the selected XDG data
home (a symlink to the installed templates is sufficient).

Run `tests/link_checks.gd` headlessly with temporary `XDG_DATA_HOME`. It simulates
the Room over a real localhost WebSocket, multiplexes scripted NetClients,
checks HTTP health, private views/events, snapshots, mid-game container restore,
version errors, replacement links and takeover without clients. When the exported
binary exists it also launches it as a subprocess and probes `/health`. A sandbox
that denies TCP socket creation reports the network suite as skipped.

### Online player UI

`OnlineAPI` is the single address/REST boundary: `HTTPRequest` works on desktop,
Android and web. Address precedence is `PHREAKNIC_SERVER`, `game/online_server`
in settings, then the production HTTPS service. It also validates invite codes,
parses `/join/CODE` and `?join=CODE`, translates REST failures and stores the private
`game/online_seat` credential dictionary (`server`, `code`, `seat`, `token`).
`Sfx.save()` preserves these extra ConfigFile keys. Credentials never enter invites
or logs. The website redirects invite paths to the root query so export assets
resolve normally. Native clients use the code field.

`scripts/ui/online.gd` presents a viewport-fitted UIStyle browser with internally scrolling panels, a creation form and live
room lobby, using the menu's identity and configuration. REST is injectable via
`api.request(method, path, body)`; public rooms refresh every five seconds while
browsing. Room messages supply seats and host controls. Starting waits for the
first game view before constructing the existing table.

`OnlineSession` owns one `NetClient` and a polled `WebSocketTransport`. Production
sockets authenticate with the room token URL and use `NetClient.bind_transport`,
which never sends hello. Direct server tests retain `connect_to` and its hello.
The session handles room/server/over lifecycle messages and reconnects at 1, 2,
4, 8, then at most 15 seconds, reusing the stored credential. The transport factory
is injectable for offline room-layer tests. The session moves from lobby to table
without closing the socket. A welcome retires stale prompts before retransmission.

`table.gd` selects its existing local engine or the client's mirror at setup.
`human_seat` selects the bottom hand, rig, names, turn labels, queries and effects.
Online action branches send protocol messages and never run mirror rules. Prompt
payloads use the existing decision/search/prevention dialogs; card choices become
UIDs and player choices become seat numbers. `prompt_done` closes an open dialog
without answering again. Mirror views redraw the table, logs retain their card
links, and events drive transient effects. Availability requires a ready view and
no pending prompt; auto-end and confirmation share the offline UI flow. Online
mode cannot save/autosave or remove an offline save. Leaving disconnects while
retaining the resumable credential; terminal messages clear it.

`tests/online_ui_checks.gd` injects REST and a tiny room layer over JSON loopback
transports connected to a real in-process GameServer, exercising the actual table
and dialogs without HTTP or socket access. Like other UI tests it backs up settings
and the offline save. Run every Godot command with temporary `XDG_DATA_HOME`.

`addons/online_export` registers an Android-only EditorExportPlugin override for
`permissions/internet`, enabled in project.godot. This grants network access to APKs
without modifying export_presets.cfg; other export platforms receive no overrides.
The debug APK's manifest is checked with Android SDK `aapt dump permissions`.

### Online polish UI

Online home uses a fixed viewport layout over the network background: a status
strip and title, create/join panels on the left and an internally scrolling open
room list on the right. The lobby has a room/invite panel with seat avatars and
badges, plus host settings and readiness feedback. Controls are at least 56 px
high. Internal panel scrolling supports 1920×1080, 2400×1080 and 1920×1440 without
scrolling the page. Copying an invite shows a brief toast; startup has an animated
indicator. The injectable REST/session interfaces remain available to UI tests.

The Worker checks create/join client versions against optional `GAME_VERSION`
before room allocation or seat claims (409 `error:version`, `need:GAME_VERSION`).
Unset/empty keeps the previous behavior, including the room's locked join version.
`tools/deploy_online.sh` supplies project.godot's config/version in deploy and dev.

### Version 0.11 security hardening

Connected humans get a private idle warning after 120 seconds on their own turn.
At 180 seconds a Phreak bot finishes that turn, then returns control. Accepted
actions reset the deadline; other traffic does not. Prompts retain their separate
45 second fallback. Three consecutive idle turns cause full bot takeover. The
server's injectable monotonic clock controls both timers.

Authoritative online logs retain at most 200 entries and 64 KiB of UTF-8 text,
including before checkpoints. Snapshots remain bounded across long games.
Oprah Wonka's search choices are sorted by card identity rather than deck order.
Treasure Hunters and Speakers Needed explicitly reveal top cards as their rules
require; neither is a hidden-zone search option leak. Network structure checks
bound depth, node count and strings before recursive normalization or dispatch.
Save files are capped at 2 MiB; settings and remembered online seats at 64 KiB,
with type/range checks before use. Bug report logs replace human opponents' names.

### Version 0.12 party settings and room closure

Party leaders can ban center-deck cards before setup, offline from the menu or
online from creation and host settings. The picker supports name search, touch
scrolling, background art loading and right-click/long-press inspection. Selecting
a printed card bans every physical copy (including all Botnets); starters cannot
be banned. At least **40 center-deck cards before dealing** must remain: five in
the initial row and at least 35 for refills. This is a house safety floor, not a
change to card effects. Bots use the resulting deck normally.

Offline settings retain separate lists for 2025 and 2026. GameState.banned stores
normalized physical IDs; save validation accounts for omitted cards and old saves
default to no bans. Online room `banned` accepts at most 150 unique printable IDs
of at most 64 characters; the Worker checks shape, while GameServer filters IDs
against the selected center pool and refuses setup below the floor. Room broadcasts,
container setup, public game views and authoritative snapshots preserve the list.
Changing an online pool clears bans. Public summaries expose `banned_count` and
every lobby seat can inspect the list; only the host can edit. The table's Banned
button beside the center deck opens the same read-only list.

Before start, the host's confirmed Close room action sends lobby `leave`. The
Worker sends `room_closed` with `reason: host_left`, closes sockets with 4002
`closed`, removes the room listing and stored room, and increments daily
`rooms.closed_by_host`. An unannounced host disconnect starts a persisted 60-second
alarm deadline; reconnect cancels it. Code reuse resets lifecycle state. Started
games retain their existing disconnect/reconnect behavior. Clients handle either
the message or close code by forgetting the seat, stopping retries and returning
to online home with “The host closed the room.”

### Version 0.13 variant and online identity

`reference/mog_cards_2026.json` records all 48 visually transcribed Mog images. CardDB builds isolated catalogs per pool: identical rules retain stable effect IDs while their name, image and flavor change. Mognet has five new physical-copy IDs with its own once-per-turn activation counting Mognet. The UI selects its presentation catalog; engine catalogs remain independent. Bans and saved pool settings support all three pools.

Invite links open a Join game CODE panel with the editable YOU identity and avatar. No join request is sent until the player presses Join as their handle (or Join anyway for the default identity). Code/list joins prompt once when the handle is empty/You and no Hero is selected. Hero-less identities retain the FOTTR logo.

GameServer diagnostics keep stdout and emit a diagnostic signal to LinkServer, which sends `{t:"diag",text}` at most 120 times per minute per container room, marking the last permitted line muted. The Room logs string payloads only as `room CODE: TEXT`, truncated to 300 characters, without sending diagnostics to clients.
