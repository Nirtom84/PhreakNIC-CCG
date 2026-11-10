# Rules and implementation notes

`DESIGN.md` and the printed JSON text are authoritative. All 152 ids have an
individual handler in `scripts/core/effects.gd`; continuous, purchase, start/end,
play, combo, prevention, and activated effects share the corresponding hooks.
There are no intentionally partial card implementations. The bots use bounded
heuristics rather than exhaustive game-tree search.

## Specified house rules

- Hacking is a shared purchase/ability pool and expires at end of turn.
- Purchases and acquisitions go to discard unless specified otherwise. Acquiring
  means gaining without paying; a free purchase is still a purchase.
- Reserve allows one card per turn, only before any purchase/acquisition, and
  blocks subsequent purchases/acquisitions. Tips and tricks lifts the two ordering
  restrictions for that turn; the one-reservation limit remains.
- Permanents stay in their controller's play area. Discarding one returns it to
  its owner's discard. Changing control preserves ownership. Explicitly moving
  someone else's card into your discard transfers ownership and counts as gaining.
  A reserve is outside play and has no abilities.
- Only permanents are in play. Actions are tracked as played this turn. Subtypes
  match whole words, names match printed names without case sensitivity, and
  What is Truth has every name (including substring/name checks).
- Damage hits all living opponents. Life loss uses prevention but is not dealing
  damage. Encapsulation and Phreaknic Network prevent before ICE; the defending
  decider chooses ICE order. Bots choose fewest counters first. Overflow continues
  to life; final-counter triggers resolve immediately. Walmart stays with zero
  counters because it has no printed final-counter discard ability.
- Cost reductions stack, clamp to zero, and apply to center and reserved cards.
- Empty center deck leaves empty row slots. Removed cards share one face-up zone.
- Eliminations happen during effects. Controlled permanents go to their owners'
  discards; other cards remain in their zones. An eliminated active player's turn
  ends. A simultaneous group of life losses determines its winner after the
  whole group; if nobody survives it is a draw.
- Lowes Shopping Cart wins on counter 25; The Juice loses on counter 5, before
  dealing that turn's Juice damage. TOCTOU can replace either kind of elimination.
- Center-row Rickroll is bought for zero at turn start, before other actions,
  counting as buying even under another card's purchase prohibition.
- Once-per-turn and repeatable paid permanent abilities are controller activations
  on their turn. Nashville 2600's removal payment is available to every active
  player. Usage resets each turn, including on a permanent stolen during that turn.
- Options, optional effects, card/player selection, and numbers all use awaited
  decider calls. Invalid card subsets are clamped to legal, distinct candidates.
- Jenny spends an affordable amount from 8, 6, 7, 5, 3, 0, 9 and deals that amount.
- Oprah Wonka's next seat splits its selected cards into two piles; empty piles
  are allowed. Elite greedily balances the value of the two piles.
- TOCTOU removes itself, sets life to 1, and interrupts the current effect for an
  immediate full turn. Its extra turns resolve before resuming. The interrupted
  player's hacking, played history, turn flags, and activation usage resume;
  physical zone changes during the interruption persist. Human reaction turns
  wait for `end_turn`; bot reaction turns use the same bounded bot driver.
- Grass leaves at the end of its controller's next turn after its play turn.
- The Rick Astley art list is the single `CardEffects.RICK_ART` constant: Rick
  Astley, Rickroll, Never Gonna Give You Up, Never Gonna Let You Down.
- Etch-a-Sketch resolves an opponent's discarded action without moving that source.
- Treasure Hunters searches from the top of the center deck for the printed cost,
  acquires nothing if absent, and shuffles the deck either way.

## Additional readings of ambiguous text

- "If ... is played this turn" combinations (the FOTTR trio, Reps4Thor, Never
  Gonna pair, Mog's Ice Cream) work in either order, once per instance played.
  Replaying an instance through The Book creates a new play occurrence.
  DeMartian/m8trix production modifiers and Super r0nk's "whenever" apply to
  subsequent plays; they do not retroactively refund resources or damage.
- "You may buy a card ... for free this turn" grants one free-buy token per play.
  It expires with the turn and is automatically used for the next matching buy.
  Payphone Dave grants one token usable for any of its three intended cards.
  Fellowship/pTFS and Walmart's conditional permission are ongoing free prices.
- The first NSAKEY card is printed `_NASKEY`, while the other is `_NSAKEY,
  Juiced`. Even More Logo's literal `_NSAKEY` name restriction matches the
  latter; the differing spelling on the former is preserved.
- Payphone Dave's "Pay Phone", "Reverse Shell", and "Shell Speak" refer to
  Payphone, You've Got Mail (file id Reverse Shell), and Shell Speech.
- A copied action's self-reference moves/removes the copying card. Thus copying
  Drunk Riddler removes Etch-a-Sketch, while the physical Drunk Riddler stays put.
  Copied play identity is used for name/subtype triggers and play restrictions.
  Etch-a-Sketch does not target itself, avoiding recursive copying without a base
  action. Its copied effect also counts as a play for the turn's combinations.
- Restaurant copies a chosen location's rules and initial ICE quantity, not its
  current counter total, ownership, attachments, or activation usage. Its copied
  name and rules apply while in play; its physical stable id is unchanged.
- The Book must attach an action when one is available, then attempts each stored
  action. Normal action cleanup leaves attachments attached; explicit self-moving
  text can detach one. A play restriction can postpone a stored action's play.
  Book/pTFS attachments go to the departing permanent's controller's discard
  ("your discard"), even if the permanent itself returns to a different owner.
- If multiple purchase destinations apply, the controller gets a decider choice
  for each in play-area order until accepting one; that destination wins.
- A purchased-card trigger resolves before destination replacement and opposing
  Taser triggers. A just-bought card is present in discard for its own trigger;
  G4nd4lf's "another card" excludes itself.
- Kevin's Desk may choose itself or another already-controlled permanent. No
  counters or attachments reset on a control change.
- A multi-target printed damage instruction is one amount per target; each CTF
  Bangers increases a permanent source's amount by one. Hotel Roof Chair Toss's
  separately printed additional damage is a second instruction.
- Draw/reveal instructions stop if no cards remain after any permitted reshuffle.
  O.P.R.A.H.'s direct center draws are acquisitions into hand, not ordinary draws.
- All-player life loss, including proudF00F, is treated as simultaneous for win
  determination. Prevention and TOCTOU still resolve seat by seat.

## Engine integration and test reproduction

Add `GameEngine` to the tree, call `setup([difficulty, ...], seed, deciders)`, then
`await start_turn()`. Difficulty `-1` marks a human seat; provide its `Decider`
subclass. Each player has their own decider. `end_turn` advances and starts the
next turn automatically; listen to `turn_started`/`state_changed` and drive the
next bot with `await BotPlayer.new(engine).take_turn(player)`. No UI is included.
Public action methods reject reentry while a choice is pending (`engine.busy`).
Await play, buy, activate, and end; reserve is synchronous. Query helpers are
read-only. An optional `turn_driver` callable can drive bot reaction turns.

Run `~/.local/bin/godot4.7.1 --headless --path . -s tests/sim.gd` after the initial
editor import. The sim runs focused rules scenarios, then 300 fixed-seed games:
120 Elite/Kiddie duels with alternating seats, 60 Phreak duels against the other
two levels, 60 three-player, and 60 four-player.
It checks original uid/id conservation after each state update and turn, reports
natural versus capped draws, and fails if Elite wins fewer than 60% of duels.
Append `-- --coverage` to print the play count for every card id.

In a sandbox that cannot write the normal Godot user directory, prefix the run
with `XDG_DATA_HOME=/tmp/phreak-godot-data`. This changes only Godot's writable
runtime-data location. The tests require no network, textures, or scenes.

- Card sets: PhreakNIC 2025 uses the base Center Deck of 102 cards. PhreakNIC 2026 adds the 48 expansion cards (150 total). Starter decks stay the same.
