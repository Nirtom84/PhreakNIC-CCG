# FOTTR TCG (PhreakNIC) — Confirmed Rules

Sources, in priority order:
1. Errata v1.1 (https://tcg.fottr.io/, copy in `errata-v1.1.html`)
2. Printed rules card (`RulesCardFront.jpg`, `RulesCardBack.jpg`)
3. Rules inferred from card text and confirmed by the designer on 2026-11-09 (marked *[confirmed]*)

Card text: `cards_transcribed.json` (152 cards: 104 in the Base Set, 48 in Expansion 1; see Card sets below). The errata was written for the Base Set; Expansion 1 has no official errata yet. `{H}` = Hacking, `{D}` = Damage.

## Card sets

| Set | Released at | Year | Cards |
|---|---|---|---|
| **Base Set** | PhreakNIC 26 | 2025 | 104: the Hacker and Attack starter cards, plus 102 Center Deck cards (including 4 Botnets) |
| **Expansion 1** | PhreakNIC 27 | 2026 | 48 Center Deck cards (including 1 Botnet) |

- Each set was released at the PhreakNIC shown. *[confirmed]* Its cards print that name ("PhreakNIC 26" or "PhreakNIC 27") on the card edge, which is how to tell the sets apart on the physical cards.
- The years are taken from the web addresses of the two card pages. The designer has not confirmed them.
- More expansions are planned. Every card records its set (`set` in `cards_transcribed.json`; the list of sets is in `sets.json`).
- The Base Set is always used. It holds the starter cards and the rules card.
- *[default]* Each expansion can be included or left out when a game is set up. Every set is included unless the host switches one off.
- Cards may name cards from another set (Walmart Parking Lot in Expansion 1 names heartsh8ped from the Base Set). If the other set isn't in the game, the reference simply never matches.
- "Botnet" is the only name printed in both sets. All five Botnets are the same card for rules purposes.

## Components

- **Starting cards (Base Set):** Hacker (cost 0, Action, +1 {H}) and Attack (cost 0, Action, deal 1 {D}). Each player gets 8 Hacker + 2 Attack.
- **Center Deck:** every non-starter card from the sets in use, one copy per card image.
  - Base Set only: 102 cards.
  - Base Set + Expansion 1: 150 cards (5 Botnets). *[confirmed]*

## Setup

The game is for 2–4 players. *[confirmed]*

1. Each player shuffles their 10-card starting deck.
2. Starting life = 10 × number of players. Errata recommends **24 in a two-player game**. Starting life is a game setting.
3. Shuffle the Center Deck; deal 5 face up as the **Center Row**.
4. Each player draws 5.

## Card anatomy

- **Cost:** number in the upper-left (paid in {H}).
- **Type line:** `Supertype - [Legendary] [Group] Subtype`.
  - Supertypes: **Action** (immediate effect, then discarded) and **Permanent** (stays in play with ongoing effects).
  - Subtypes: Hero, Exploit, Event, Location, Technology, Organization.
  - Groups within Hero: FOTTR Hero, pTFS Hero. A "FOTTR Hero" is a Hero.
  - **Legendary** is a tag with no inherent rules; only some card effects care about it (e.g. PhreakNIC).
- Frame color follows subtype: Hero blue, Exploit red, Event purple, Technology olive, Location green, Organization teal, starters black.

## Turn

- On your turn you may, in any order and as often as able:
  - **Play** any card from your hand. Actions: do everything the card says, then put it in your discard pile. Permanents: put into play in front of you. No limit on permanents in play.
  - **Buy** a Center Row card (or one of your reserved cards) by spending {H} equal to its cost. Bought cards go to your discard pile unless an effect says otherwise. No limit on the number of buys.
  - **Use abilities** of your permanents ("once per turn", "as often as you like on your turn").
- **Hacking** accumulates through your turn and can be spent any time during your turn. Unspent {H} is lost at end of turn.
- **Damage** ({D}) reduces the life of **all other players** by the amount dealt, unless a card says otherwise (e.g. CRT LAN Party).
- Whenever a card leaves the Center Row, immediately refill that slot from the Center Deck.
- **End of turn:** discard your remaining hand, draw 5, play passes clockwise.
- If you need to draw but your deck is empty, shuffle your discard pile to form a new deck.

## Reserving

- Instead of buying or otherwise acquiring anything this turn, you may reserve one Center Row card: place it sideways in your play area. Only you may buy it later.
- At most one reservation per turn; no limit on total reserved cards.
- You don't have to buy your reserved cards before buying from the center.
- A reserved card is not bought, not in play, and does nothing. Reserving is not buying or acquiring.
- Tips and tricks for Windows and Office365 lets you reserve even if you buy that turn.

## Life, damage, prevention

- Losing life is treated as taking damage; anything that prevents damage prevents life loss. ICE counters must absorb life loss just like damage; you cannot choose to lose life instead.
- If multiple sources would prevent damage, their controller chooses which one prevents each point.
- **ICE counters** (Locations): "when you would take damage, remove that many counters instead." Prevention is point by point: damage beyond the remaining counters goes through to your life (or to another prevention source). *[confirmed]*
- A player at 0 life is out. Last player alive wins.
- Alternate results: Lowes Shopping Cart with 25+ counters wins; adding a 5th counter to The Juice loses.

## Timing

- Extra turns (Time Travel, TOCTOU Photo-Finish) are full turns and re-run every "beginning of your turn" effect.
- When two effects trigger at the same time, the player whose turn it is chooses the order.
- "Once per turn" and "as often as you like" abilities on permanents can only be used **on the controller's own turn**. *[confirmed]*
- Start-of-turn discards happen before you can use the card: if Tableskirts or Unattended Phone is discarded at the start of your turn, you get no {H} from it that turn.
- Botnet: each Botnet's ability is used separately; each gives +1 {H} per Botnet you control (3 Botnets → +3 each → 9 total). *[confirmed]*
- "If a card named X is played this turn" / "If you play X this turn": order does not matter. The bonus applies once both cards have been played that turn, regardless of which came first (bitwize/crook3dfingers/5ud0, Reps4Thor/Nirtom, Never Gonna Give/Let). *[confirmed]*

## Buying vs. acquiring

- Buying = paying a card's cost (possibly 0 via "for free") to take it. Buying is one form of acquiring.
- "Acquire" (benthephreak, itsamenathan, Treasure Hunters, O.P.R.A.H., etc.) = gain a card without buying. Acquired cards go to your discard pile unless an effect says otherwise.
- Acquiring does **not** trigger "When you buy this card" or "whenever a player buys" effects, and is still allowed while buying is forbidden (Grass, PhreakMyst). *[confirmed]*
- "Buy … for free" **is** a buy and does trigger buy effects.

## Zones and control

- Zones: each player's deck, hand, discard pile, play area (permanents), reserved cards; shared Center Deck, Center Row, and a shared face-up **Removed from the game** pile (Clarion Inn Chandeliers can retrieve from it).
- A permanent whose control changes (AI Fingers, Kevin's Desk) goes to its **controller's** discard pile when it leaves play. *[confirmed]*
- Eliminated player: their permanents are removed from the game; their reserved cards go to the bottom of the Center Deck. *[confirmed]*
- Empty Center Deck: Center Row slots that can't be refilled stay empty; play continues. *[confirmed]* If cards later return to the Center Deck (an eliminated player's reserved cards), they are dealt into the empty slots at once. *[default]*

## Card-specific rulings

- **_NASKEY:** printed name is a misprint for **_NSAKEY**; cards referencing "_NSAKEY" apply to it. (errata)
- **Jenny:** pay the chosen {H} amount (8, 6, 7, 5, 3, 0, or 9) when you play it to deal that much damage. (errata)
- **F.O.T.T.R. Greatest Hits Volume 2:** cards with Rick Astley in the art are Rick Astley, Rickroll, Never Gonna Give You Up, Never Gonna Let You Down. *[confirmed]*
- **Payphone Dave:** references map to Payphone ("Pay Phone"), You've Got Mail ("Reverse Shell"), Shell Speech ("Shell Speak"). *[confirmed]*
- **BONY:** "…in its name from for free" reads as "from the Center Row for free". *[confirmed]*
- **Rick Astley:** type "Hero Legend" is treated as **Legendary Hero**. *[confirmed]*
- **Walmart Parking Lot:** played as printed. It has no "discard when the last counter is removed" line, so it stays in play with 0 counters. *[confirmed]*
- **Clarion Inn Storage Closet:** "2 ICE counter" = 2 ICE counters. *[confirmed]*
- **Super r0nk:** "add {H}" = +1 {H}. *[confirmed]*
- **Lowes Shopping Cart:** "pay {H}" = pay 1 {H} per counter. *[confirmed]*
- **Never Gonna Let You Down:** "+2 {D}" = deal 2 {D}.

## Public and hidden information *[default]*

- **Public:** the Center Row; the number of cards in the Center Deck; each player's life, permanents (with counters and attached cards), reserved cards, discard pile (every card, browsable), hand size and deck size; the removed-from-the-game pile; Hacking generated this turn.
- **Hidden:** each player's hand, the order of every player's deck, and the order of the Center Deck.
- "Reveal" effects show the revealed cards to all players.

## Rulings from the 2026-11-09 review

These came out of a second pass over all 152 cards.

- **Rulings 1–8 were confirmed by the designer on 2026-11-09.**
- **Rulings 9–25 are working defaults.** The designer asked for defaults on all remaining questions, so the game uses them, and any of them can still be overturned.
- Items marked *[default]* elsewhere in this file have the same standing as rulings 9–25.

### Rulings that change how the game plays *[confirmed]*

- **Ruling 1. Same-turn reshuffles.** Played Actions go to the discard pile immediately, so if your deck runs out mid-turn they are shuffled back in and can be drawn and played again the same turn. Very thin decks can loop without limit: a deck of just Brimstone and Elevator Noises gives unlimited Hacking and damage, because each one draws the other back. (The errata says an Action does everything it says before it goes to the discard pile, so a card can never draw itself.) Played exactly as printed, with no limit.
- **Ruling 2. Absorbing with ICE is mandatory.** When you would take damage and have ICE, counters must absorb it. You only choose *which* source absorbs each point. Damage reaches your life only when no prevention is left.
- **Ruling 3. Rickroll.** If Rickroll is in the Center Row when a turn starts, that player buys it automatically as a start-of-turn effect. It is a real buy: it triggers Powered-On Taser Maintenance and counts as having bought a card (so no reserving that turn, PhreakMyst can't be played, and Zenthere's bonus is lost). If buying is forbidden (Grass), nothing happens. When a played Rickroll replaces a bought card, it moves from the discard pile into that Center Row slot and no card is dealt from the Center Deck.
- **Ruling 4. Hardware Hacking Village.** "Technology cards cost 1 less" applies only to its controller.
- **Ruling 5. DeMartian and m8trix.** Both bonuses apply whichever card is played first (DeMartian yields 2 more Hacking, m8trix deals 2 more damage). By contrast, "if you've played X this turn" (Mog's Lemon Custard Ice Cream, Walmart Parking Lot) requires X to have been played earlier that turn.
- **Ruling 6. CTF Bangers.** Adds 1 to each instance of {D} dealt by one of your permanents (The Juice with 3 counters deals 4, not 6). It does not change "lose life" effects (Powered-On Taser Maintenance, Clarion Inn Air Conditioning, F.O.T.T.R. Greatest Hits Volume 2).
- **Ruling 7. Simultaneous elimination.** If every remaining player is eliminated at the same time, the game is a draw.
- **Ruling 8. Reserving and acquiring.** You can't reserve if you have bought or acquired a card this turn. After reserving you can't buy, and effects that would make you acquire a card do nothing (unless Tips and tricks is in effect).

### Card-level rulings *[defaults]*

- **Ruling 9. Etch-a-Sketch Skillz** copies only the effect text of the chosen Action. Any self-reference in the copied text (the printed name or "this card") means Etch-a-Sketch Skillz. It doesn't take the copied card's name or type, and it ignores that card's play restrictions.
- **Ruling 10. Costs in card text** ("costs 4 or less", "costs that amount", "equal to that card's cost") use the printed cost and ignore discounts.
- **Ruling 11. Oprah Wonka.** "The player to your left" is the next living player in turn order. A pile may be empty. Shuffle your deck afterwards. With fewer than five cards in deck and discard combined, take them all.
- **Ruling 12. Name matching** ignores case. "Named X" means the whole name is X; "X in its name" means the name contains X. What is Truth? passes every name test, including ones that hurt its owner (Rookie Numbers' "Mog" check, Even More Logo's "_NSAKEY" restriction).
- **Ruling 13. "Cannot be played on the same turn as"** (Even More Logo, Nirtom Unleashed) works both ways: whichever card would come second can't be played. In general "can't" beats "must" and "may".
- **Ruling 14. "In play" with no owner named** means any player's side (_NSAKEY and The Juice, The Tone Whisperer and Payphone, pouipoui, AV Guy).
- **Ruling 15. Corporate Retreat.** "More life than another player" means more than at least one other living player.
- **Ruling 16. Payphone Karaoke.** Choose two different options.
- **Ruling 17. CRT LAN Party.** An opponent with an empty deck shuffles their discard pile first; an opponent with no cards at all is skipped; all opponents tied for the lowest cost take 3.
- **Ruling 18. Zenthere, Mind Goblin** is checked at the end of your turn, before you discard your hand.
- **Ruling 19. The Book.** Attaching is mandatory if you have an Action in hand. Attached Actions are played in the order you choose (they count as played for triggers and combos) and stay attached unless their own text moves them.
- **Ruling 20. "Buy … for free"** effects work on a matching card in the Center Row or among your reserved cards.
- **Ruling 21. Kevin's Desk** is mandatory when any permanent is in play (you may choose one you already control).
- **Ruling 22. TOCTOU Photo-Finish** also saves you from The Juice's "you lose the game".
- **Ruling 23. Altk3y** may take any player's permanent with "phone" in its name (Payphone, Unattended Phone).
- **Ruling 24. First player** is chosen at random; turn order follows seat order.
- **Ruling 25. Start-of-turn effects** (including the Rickroll buy) count as simultaneous, so the active player picks their order.

## Rulings from the designers, 2026-11-10

See the [full designer rulings](rulings-2026-11-10.md) for details.

1. Extra turns re-run every beginning-of-turn effect.
2. O.P.R.A.H.'s Center Deck draws count as acquiring.
3. The Book must attach an Action if able; attached Actions replay each turn, staying attached when illegal to play that turn.
4. Nuvious and Still Not Spock may discard an opponent's permanent in play.
5. Botnet Takeover takes all Botnets in play, including opponents', into your discard pile.
6. Self-references in copied text mean Etch-a-Sketch Skillz, including when removing itself.
7. I've got the Logs damages only opponents who reveal the named card, for its printed cost.
8. With MGCE and ICE, the defender chooses prevention and may preserve ICE counters.
9. Treasure Hunters spends the chosen {H} even if no matching cost is found.
10. Fore04, Fellowship and pTFS offer one bought-Hero destination, chosen by the controller.
11. ICE-counter abilities are usable only on their controller's own turn.
12. A stolen Juice keeps its counters; the new controller ticks it and loses on its fifth counter.
13. Nashville 2600 discards your other permanents too and prevents everyone from playing permanents.
14. Logs deals one separate hit per revealer; remove Logs if anyone reveals, otherwise draw one.
15. ICE mandatorily absorbs all life loss just like damage.
16. TOCTOU can break a simultaneous-elimination draw; interrupted extra turns can nest.
17. Clarion Inn Air Conditioning also drains its controller on their own turn.
18. What is Truth? always counts as revealing the card named by Logs.
