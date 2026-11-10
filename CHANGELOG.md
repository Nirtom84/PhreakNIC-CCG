# Changelog

## v0.10 — Online polish
**Online play gets the neon HUD treatment.**
- **Online home and room lobby:** panels, avatars, clearer seat status, larger touch controls and an easier-to-read room code. Copying an invite shows a confirmation.
- **Your online identity:** set your handle and pick a Hero right on the online screen, using the same Hero picker as the main menu.
- **Open games:** see the host, seats, bot difficulties, card set and starting life before joining, with a friendly message when no games are open.
- **Ready to start:** the lobby explains when human seats still need filling and shows progress while the game server starts.
- **Bot identities:** online bots get unique Hero names and avatars from the selected card set, kept when the server restores a game.
- **Waiting for friends:** a small banner shows who is choosing, without revealing their cards or choices.
- **Versions:** creating or joining a room checks the server's current game version and links to the update when needed.
- **Server updates:** games in progress carry on through server updates. If an update means a game can't be resumed, players are told instead of being left waiting.

**At the table**
- **IN EFFECT:** warnings above the Center Row explain cards that change the rules for everyone (Nashville 2600, Touch Grass, Clarion Inn Air Conditioning and more), show who controls them, and open the card sheet. A banner also appears when one comes into play.
- **Nashville 2600:** the sheet explains why your permanents can't be played, and anyone can pay 6 Hacking on their turn to remove it, whoever controls it.
- **Smarter bots:** Phreak and 31337 Elite spend leftover Hacking to remove Nashville 2600 when it blocks a permanent in their hand.

## v0.09 — Online play
**Play against other people online.** The game now has an official server at online-01.phreaknic-ccg.net.
- **Play online** on the main menu:
  - **Open games:** browse public games with an open seat and join one.
  - **Create game:** set up a public or invite-only room with 2–4 seats; each seat is an open human seat or a bot (Script Kiddie / Phreak / 31337 Elite). Pick the card set and starting life.
  - **Join by code:** type a friend's four-character code.
  - **The room lobby** shows the code and an invite link (`phreaknic-ccg.net/join/CODE` opens the browser version straight into the room). The host can add or remove bots, change settings and start.
- **Fair play:** the server runs every game with the same rules engine as single-player. Your game only receives what you're allowed to see: other players' hands and every deck's order stay on the server.
- **Dropped connections:** your game reconnects by itself. **Leave game** keeps your seat, and **Resume online game** on the main menu takes you back. If you're away for 2 minutes, a bot plays for you until you return. A card question nobody answers within 45 seconds is answered for you.
- **Saving:** the server saves after every move, so a game survives a server restart.
- **Versions:** online games need everyone on the same version of the game. An older game says so and links to the latest release.
- **Coverage:** online play works in the Windows, Linux and Android apps and in the browser version.

**Also new**
- **The browser version's main menu** has **Get the app** links for Windows, Linux and Android, and for all releases.
- **The web game now lives at https://phreaknic-ccg.net,** served from Cloudflare. The GitHub Pages copy stays as a mirror.
- **Android:** the app now asks for Internet access, needed for online play.

**Known rough edges** (polish planned for v0.10):
- The online screens are plain next to the rest of the game.
- Online bots are named "Bot".

## v0.08 — Official rules, card sheet and 3–4 player games
This is now the **official** digital version of the FOTTR TCG. bitwize, one of the game's creators, handed over his rules research: the printed rules, the official errata v1.1 and the designer's rulings, plus an audited card transcription. The game now follows them (see `reference/rules.md`).

**Card fixes**
- **CRT LAN Party** costs 4 (it was wrongly 1).
- **Never Gonna Let You Down** now deals its 2 damage.
- **Rick Astley** counts as a Legendary Hero.
- **_NASKEY** counts as _NSAKEY (official errata), including Even More Logo's restriction.

**Rules now matching the official rulings**
- **Starting life:** 24 in a 2-player game, 10 per player with 3–4. You can also pick 20, 30 or 40 on the main menu.
- **First player:** chosen at random.
- **Simultaneous effects:** when several happen at once (for example start-of-turn effects and a forced Rickroll buy), the player whose turn it is chooses the order.
- **Damage prevention:** when you have more ICE than damage, you choose which cards absorb it, with − and + buttons. Absorbing is still mandatory.
- **Taken permanents:** a permanent you took control of goes to *your* discard pile when it leaves play.
- **Elimination:** an eliminated player's permanents are removed from the game, and their reserved cards go to the bottom of the Center Deck.
- **Specific cards:**
  - The forced Rickroll buy is blocked by "can't buy" effects such as Grass.
  - DeMartian and m8trix boost each other in either order, while Mog's Ice Cream needs Rookie Numbers played first.
  - BONY's free buy is from the Center Row only.
  - Etch-a-Sketch copies only the text.
  - Oprah Wonka is split by the next player still in the game.
  - You choose the order The Book's cards resolve in.

**Playing**
- **3 and 4 player games:** you against 1–3 bots.
- **Card sheet:** click or tap a Center Row or reserved card to see it full size. It shows the set, type, cost, the rules as readable text, any combo partners, and **Buy** / **Reserve** buttons with hints. Long-press, right-click or a log link opens it read-only.
- **Play Basics** plays only your Hackers and Attacks.
- **End Turn** asks before ending while you still have moves. Switch it off with **Confirm end turn**.
- **Banners** explain things such as who goes first, a forced Rickroll buy, an elimination, or "No moves left".
- **Report a bug** on the main menu and in the in-game menu opens a GitHub bug report already filled in with the version, platform and your last moves. Submitting it needs a free GitHub account.
- **Set names** now match the cards: **Base Set · PhreakNIC 26** and **Expansion 1 · PhreakNIC 27**.
- **Fixes:**
  - Dialogs size themselves to their contents.
  - Dialogs stay above the bot's card previews.
  - The "start a new game?" question has finger-sized buttons.
  - The log says "You go first".

## v0.07 — Play in your browser
- **[Play in your browser](https://nirtom84.github.io/PhreakNIC-CCG/)** on GitHub Pages: no install, runs on computers and phones. iPhone owners can play in Safari instead of needing an app. Tested in Chrome so far.
- In a browser:
  - **Saves and settings:** kept in that browser.
  - **Leaving:** closing or switching away from the tab saves your game on your turn, the same way the phone app does.
  - **Phones:** a phone held upright shows "Turn your phone sideways", since the game plays in landscape. Touch controls switch on automatically in phone browsers.
  - **Quit and Exit:** hidden, because a web page can't close itself.
- The loading screen uses the game's dark background and the FOTTR logo, instead of the Godot logo, on every platform.
- Smaller downloads everywhere: card images are now stored as compressed WebP instead of lossless, cutting the card art in the game from about 45 MB to about 16 MB.

## v0.06 — Choose your card set: PhreakNIC 2025 or 2026
- New **Card set** choice on the main menu:
  - **PhreakNIC 2025**: the base game, a 102-card Center Deck.
  - **PhreakNIC 2026**: the base game plus the 48 cards of the 2026 expansion, a 150-card Center Deck. This is what earlier versions played.
- Your choice is remembered between games.
- In a 2025 game, only base cards appear:
  - in the Center Deck;
  - in bot names (bots are named after base-set Heroes);
  - in "name a card" choices such as I've got the Logs.
- The table shows the set next to the Center Deck count, and **Resume game** shows it in the save description.
- Saved games remember their card set. A game saved with v0.05 resumes as a 2026 game.
- Card sets follow the official FOTTR card lists. The 2026 expansion includes a fifth Botnet; the base game has four.

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
