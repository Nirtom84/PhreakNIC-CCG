# Card transcription audit (2026-11-09)

`cards_transcribed.json` was checked a second time, independently of the first transcription.

## What was checked

| Check | Coverage | Result |
|---|---|---|
| Card name and cost, by eye against the title bar | All 152 cards | All match |
| Type line and set code, against Apple Vision OCR of the full-size image | All 152 cards | All match (2 set codes unreadable by OCR) |
| Rules text, word by word against OCR | All 152 cards | 119 identical; 33 differed only where OCR dropped words next to an icon or picked up art |
| Rules text, by eye | 43 cards: 30 of the 33 above (the other three are duplicate Botnet cards whose OCR output was identical to the Botnet that was checked), Treasure Hunters, and 12 complex cards (Rickroll, TOCTOU Photo-Finish, The Book, pTFS, Walmart Parking Lot, Never Gonna Let You Down, F.O.T.T.R. Greatest Hits Volume 2, Restaurant, Kevin's Desk, Grass, Phreaknic Network, The Juice) | All match |
| Hacking vs Damage icons, by colour detection in the text box | All 152 cards | All match after reviewing 29 flagged cards by eye or by blob position |

## Findings

- No errors in names, costs, type lines or rules text.
- Walmart Parking Lot really has no "discard when the last counter is removed" line.
- Never Gonna Let You Down really prints "+2" with the red Damage icon.
- Expansion 1 cards use a smaller inline Hacking icon inside sentences (AI Ben's AI Camry, White Python Boots, Lowes Shopping Cart).
- The audit covered both sets: 104 Base Set cards (printed "PhreakNIC 26") and 48 Expansion 1 cards (printed "PhreakNIC 27").

## Not checked

- Flavor text (not used by the rules).
- Capitalization inside small-caps text.

## Errata

https://tcg.fottr.io/ was re-downloaded on 2026-11-09 and is identical to `errata-v1.1.html`. The site returns that same page for every path, so there are no other pages. All 13 errata items are reflected in `rules.md`.
