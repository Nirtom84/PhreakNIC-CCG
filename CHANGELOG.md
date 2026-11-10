# Changelog

## v0.05 — Touch controls, save & resume, Hero avatars
First version with downloads for **Windows, Linux and Android** on the release page.

**Touch screens (Android)**
- Tap to play, buy and press buttons. Press and hold any card (hand, Center Row, permanents, reserved, opponent cards, dialogs) to see it full size; tap anywhere to close it. A long press never plays or buys the card.
- Tap a card name in the Network Log to see the card.
- Drag a finger to scroll the log, the rules, the Hero list, card dialogs and the rows on the table. A drag never presses the button it started on.
- Android Back button: closes the open card, menu or dialog (acting as Cancel), otherwise opens the in-game menu. It no longer quits the app.
- The table now uses the full width of wide phone screens (20:9) and fits taller screens (4:3, 16:10) without cutting anything off.

**In-game menu, save and resume**
- The **Menu** button opens a drop-down menu instead of throwing the game away: sound, volume, visual effects, auto-end turn and bot speed can be changed mid-game, plus **Rules**, **Save game**, **Main menu** and **Exit game**.
- Save a game against the bots at any point on your turn. The game also saves automatically at the start of each of your turns, when you leave, and when a phone puts the app in the background.
- **Resume game** on the main menu continues exactly where you left off, network log included.

**Quality of life**
- **Auto-end turn**: when you have nothing left to do (nothing playable, affordable or reservable, and no abilities to use), your turn ends by itself after a moment. Switch it off on the main menu or in the in-game menu.
- The Network Log is compact: one line per entry, no blank lines between them.
- The buy/reserve popup is a small centered dialog that shows the card you clicked, instead of a nearly full-screen panel. All choice dialogs now size to their content.

**Hero avatars**
- On the main menu, type a handle or press **Pick a Hero** to play as one of the Hero cards. A Hero's card art becomes your avatar; typed names get the FOTTR logo.
- Avatars show next to the turn banner, in the turn announcement, and in your and your opponent's panels. Bots show the art of the Hero they're named after and never take your Hero.

**For testers**
- README has download links and install steps for each platform, and GitHub Issues has **Bug report** and **Card or rules problem** forms.

## v0.04 — Visual overhaul and player handles
**New look**
- Neon hacker-con style throughout: animated katakana "matrix rain" and circuit-grid background, vignette and light CRT scanlines (can be turned off with the new **Visual effects** switch on the main menu).
- Bundled fonts so the game looks the same everywhere: JetBrains Mono for text, Noto Sans Mono Condensed Black for headings, Droid Sans Japanese for the katakana (licenses in `assets/fonts/`).
- HUD-style panels with glowing borders, corner brackets and title tabs; themed buttons, switches, sliders, scrollbars and dropdowns.
- Main menu: glowing, glitching PhreakNIC title, floating card back with a pulsing halo, typewriter tagline, difficulty picked from three tiles (Script Kiddie / Phreak / 31337 Elite), 2/3/4 player buttons (3 and 4 still "soon"), labeled volume slider.
- Table: cards sit on outlined slots with drop shadows; playable hand cards glow green, affordable center cards glow amber, hover glows cyan. Life and hacking shown in framed gauges (life turns amber then red as it drops). A turn band slides in at the start of each turn. Opponent permanents are shown larger.
- Network log looks like a terminal; reveal messages read naturally ("bitwize reveals Hacker, Venaul…") and empty reveals are skipped.
- Decision dialogs dim the table and open with a short animation; selected cards get a glow and a check badge.
- Game over screen: **ACCESS GRANTED** when you win, **CONNECTION TERMINATED** when you lose.

**Player handle**
- Enter the name you want to go by on the main menu (**// YOUR HANDLE**, up to 16 characters, remembered between games). It is used in your status panel, the network log, the turn band, player choices and the game over screen. Bots never take the same name as you. Leave it blank to be called "You".

**Fixes**
- Card names containing square brackets ("[Restaurant Name] Restaurant") now display correctly in the log, captions and dialogs.

## v0.03 — Hero-named bots and a visible opponent discard pile
- Bots are named after a random Hero card each game (for example "r0nk", "O.P.R.A.H.", "Elonka"); no two bots share a name.
- The opponent panel shows their deck and discard counts, the top card of their discard pile face up, and a **Discard** button to browse the whole pile.
- Leftover bot card spotlights fade out 1.5 seconds into your turn, and queued spotlights are dropped, so they never hide the Center Row while you're buying.

## v0.02 — Credits, rules page, sound and card previews
- Main menu credits the creators of the original FOTTR TCG: 5ud0, bitwize & crook3dfingers (FOTTR), and shows the game version.
- The Rules screen is one written-out page instead of pictures of the rules cards.
- Sound effects: retro chiptune sounds for playing, buying, reserving, damage, life gain, ICE, shuffles, turn start, win/lose and buttons, with a volume slider and mute (main menu) and a mute button on the table. Sounds are generated by `tools/make_sounds.py`.
- Hover a card name in the Network Log to see the full card.
- Cards a bot plays, buys or reserves are shown large on screen for 5 seconds.
- Card names in the log are underlined links.

## v0.01 — First playable version
- Single player against a computer bot with three difficulty levels: **Script Kiddie**, **Phreak** and **31337 Elite**.
- All 152 cards from the PhreakNIC set implemented (cost, type and rules text transcribed from the card art), using the original card images.
- Full rules from the rules card: starting decks of 8 Hacker + 2 Attack, 10 life per player, Center Deck and Center Row, buying with hacking, reserving, ICE counters, damage prevention, elimination.
- Rulings for situations the printed rules don't cover are documented in RULES_NOTES.md.
- Game table: center row, your hand, permanents with ability buttons, reserved cards, life and hacking readouts, network log, card zoom on hover or right-click.
- The engine supports 2–4 players; 3 and 4 player games are shown as "coming soon" in the menu.
- Headless test suites: 300-game bot simulation, rules scenarios, UI smoke test and UI/engine state sync.
