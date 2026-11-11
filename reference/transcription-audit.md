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

## 2026 Mog Variant (2026-11-10)

All 48 supplied 600×820 JPEGs were opened individually with the image viewer. Name, cost, type line, hacking/damage symbols, rules, flavor, and Legendary type markers were read visually. Flavor small caps are normalized to sentence case. No unreadable text was found. `reference/mog_cards_2026.json` records the complete transcription.

| Mog card | Original effect ID | Rules |
|---|---|---|
| MOGTAU | `TOCTOU` | IDENTICAL |
| Mog Cardboard Cutout | `NotLarry Cardboard Cutout` | IDENTICAL |
| Mog Crumpton | `Tyler Crumpton` | IDENTICAL |
| Mog Filler | `Filler` | IDENTICAL |
| Mog Fun Police | `Talks Fun Police` | IDENTICAL |
| Mog Pooping in the Dark | `Pooping in the Dark` | IDENTICAL |
| Mog Should Have Preregistered | `Should have Preregistered` | IDENTICAL |
| Mog Wonka | `Oprah Wonka` | IDENTICAL |
| MogAlphaWolf | `zalphaWolf` | IDENTICAL |
| MogMyst | `PhreakMyst` | IDENTICAL |
| Mogdy | `randy` | IDENTICAL |
| Mogmart Parking Lot | `Walmart Parking Lot` | IDENTICAL |
| Mognaul | `Venaul` | IDENTICAL |
| Mognet | `Botnet` | DIFFERENT |
| Mog’s AI Camry | `AI Bens AI Camry` | IDENTICAL |
| Mog's CTF Bangers | `CTF Bangers` | IDENTICAL |
| Mog’s Candy Factory | `Candy Factory` | IDENTICAL |
| Mog’s Clarion Inn Chandeliers | `Clarion Inn Chandeliers` | IDENTICAL |
| Mog's Clarion Inn Closet | `Clarion Inn Closet` | IDENTICAL |
| Mog’s Desk | `Kevin's Desk` | IDENTICAL |
| Mog's Disassembled Sink | `Disassembled Sink` | IDENTICAL |
| Mog’s Etch-a-Sketch Skillz | `Etch-a-Sketch Skillz` | IDENTICAL |
| Mog's Lemon Custard Ice Cream | `Mog's Ice Cream` | IDENTICAL |
| Mog’s Lowes Shopping Cart | `Lowes Shopping Cart` | IDENTICAL |
| Mog’s Makeshift Lectern | `Makeshift Lectern` | IDENTICAL |
| Mog's OSINT for Dummies | `OSINT for Dummies` | IDENTICAL |
| Mog's Pancake Breakfast | `Mogs Pancake Breakfast` | IDENTICAL |
| Mog’s PhreakNIC | `PhreakNIC` | IDENTICAL |
| Mog's Speakers Needed | `Speakers Needed` | IDENTICAL |
| Mog’s White Python Boots | `White Python Boots` | IDENTICAL |
| MogsterL | `JousterL` | IDENTICAL |
| MogsyBacchus | `tipsybacchus` | IDENTICAL |
| Mogvious | `Nuvious` | IDENTICAL |
| Mogwarez | `hardwarez` | IDENTICAL |
| Payphone Karaoke | `Payphone Karaoke` | IDENTICAL |
| Rookie Numbers | `Rookie Numbers` | IDENTICAL |
| Still not Mog | `Still Not Spock` | IDENTICAL |
| Tennessee Department of Mog | `Tennessee Department of Health` | IDENTICAL |
| The Big Mogger | `The Big Dipper` | IDENTICAL |
| The Mog | `The Book` | IDENTICAL |
| Tips and tricks for Windows and Mog | `Tips and tricks for Windows OS and Office365` | IDENTICAL |
| Touch Mog | `Touch Grass` | IDENTICAL |
| Treasure Moggers | `Treasure Hunters` | IDENTICAL |
| Under New Mogagement | `Under New Management` | IDENTICAL |
| Where's Mog?! | `Wheres Apache` | IDENTICAL |
| Who is Mog? | `What is Truth` | IDENTICAL |
| [Mog’s Restaurant Name] Restaurant | `[Restaurant Name] Restaurant` | IDENTICAL |
| pTFMOG | `pTFS` | IDENTICAL |

Mognet replaces all five physical Botnet copies (`Botnet`, `Botnet1`–`Botnet4`) with `Mognet`, `Mognet1`–`Mognet4`. Both pools retain 150 center cards and two starter definitions.

Only rules difference:

- Original: `Once per turn, gain +1 {H} for each card named "Botnet" you control.`
- Mog: `Once per turn, gain +1 {H} for each card named "Mognet" you control.`
- Implementation: separate Mognet effect IDs and once-per-turn activation count Mognet names, including What is Truth's all-names rule. Botnet Takeover retains its printed Botnet condition and does not acquire Mognet.

### Original name scan

`assets/cards/Touch Grass.jpg` was opened: the title is **Grass**, not Touch Grass. `reference/cards_transcribed.json` also says Grass; `data/cards.json` is correct and was left unchanged for this card. All 152 original data names were compared with the reference transcription by image stem; no mismatches or additional truncations were found. File stems are stable IDs, not necessarily printed titles.
