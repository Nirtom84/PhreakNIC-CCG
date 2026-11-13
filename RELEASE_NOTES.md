# Release Notes

## v0.25 — Custom decks (experimental)
**Build your own Center Deck**
- New **Decks (experimental)** screen on the main menu. A custom deck replaces the shared Center Deck that everyone buys from. Each player still starts with 8 Hacker and 2 Attack.
- Deck rules: 60 to 200 cards; up to 4 copies of a card; Legendary cards up to 2 (Rick Astley counts as Legendary). Every printing counts toward the same card: Mog Variants mix freely with the originals, and Botnet and Mognet share their 4. Hacker and Attack can't go in a deck.
- Search and filter by type, cost and set, and add or remove copies. The deck panel shows the total and anything that breaks a rule. Unfinished decks can be kept as drafts.
- Two starter decks to play or copy: **Tag Team** (Nirtom & Reps4Thor) and **Greatest Hits** (the FOTTR crew).

**Share decks**
- **Copy deck code** gives a short code to paste into Discord. **Import** accepts a code or a deck file.
- **Download deck** saves a `.phreakdeck.json` file.

**Play with them**
- Offline: choose **Custom deck (experimental)** under Card set. The ban list doesn't apply.
- Online: the host picks **Custom decks (experimental)** and each player may submit a deck. If more than one player submits, everyone's deck rolls a **D20**; the highest roll's deck is played and ties re-roll. The rolls appear in the game log for everyone.
- Custom-deck games have their own **Experimental decks** tab in Stats and don't count toward your lifetime stats.

## v0.24 — Fix: Menu button after a game
**Fix**
- At the end of an offline game, the **Menu** button on the summary opened the in-game menu behind the summary instead of leaving. It now goes straight back to the main menu, and is labelled **Main menu**.

## v0.23 — Soundtrack by bitwize
**Music**
- The game now has a full chiptune soundtrack composed by **bitwize**: 16 looping themes and two stings, replacing the single placeholder loop.
- The music follows the game, using bitwize's cue sheet:
  - **Main Theme** on the menu, rules page and Hero picker; **PhreakNIC** in the online lobby.
  - **Starter Deck** while everyone is healthy. The Center Row theme takes over when any player drops to 10 life or below, and its tenser second half at 5 or below.
  - Permanents bring their own themes while they are in play: The Fellowship of the Token Ring, the Botnet cards, The Clarion Inn, Nashville 2600, The Juice, Military-Grade Card Encapsulation, pTFS and CTF Bangers. With several in play the themes take turns.
  - Playing **O.P.R.A.H.**, **Oprah Wonka** or **PhreakNIC** plays that card's theme for the rest of the turn.
  - **Time Travel** plays through the extra turn, and **TOCTOU** cuts in when it saves a player.
  - The Clarion Inn theme plays its collapse ending when the Inn leaves play.
  - A win plays **Access Granted**; a loss plays **Connection Terminated**.
- Tracks crossfade, and the Music slider in Settings controls the volume as before.
- Online games play the same cues. The music only reacts to what every player can see, never to hidden cards.

**Download size**
- The soundtrack adds about 20 MB to the Windows, Linux and Android downloads.
- The browser version does not download it up front: each track is fetched the first time it plays, so the first load is no bigger than before.

**Credits**
- Music by bitwize. The main menu footer now says so.

## v0.22 — Phone fix: buy reserved cards
**Fix (phones)**
- On the phone layout, **Open board** only showed your rig and reserved cards: there was no way to buy a card you had reserved, or to use a permanent's ability. Tapping a card there now opens its action sheet with **Buy** or the ability buttons. Thanks to the Discord tester who reported it from Firefox on Android.
- Small card windows (one or two cards) were squeezed so the card was cut off and hard to scroll. They now show the whole card.
- Card viewers say what a tap does instead of "Select 0–0".

**Behind the scenes**
- DEFCON played a million games against itself (Nirtom vs Reps4Thor, joined by Bitwize and 5ud0 in bigger games) to see whether it could learn better card values. It couldn't: the new values lost to the current ones, so DEFCON is unchanged. The tools for that run are now in the repo.

## v0.21 — DEFCON difficulty, bots that reserve
**New difficulty: DEFCON**
- A fourth bot level above 31337 Elite, built to be very hard to beat. Pick it on the main menu or for bot seats in online games.
- A DEFCON bot starts with **twice** everyone else's life (48 against your 24 in a standard two-player game).
- It plays smarter than Elite: it learned which cards win from 40,000 games against itself, and it works out exactly whether it can finish you this turn.
- It plays fair: it never sees your hand or the order of any deck. Its turns are as quick as Elite's.
- DEFCON bots wear a skull-and-crossbones avatar.
- In testing it beat Elite in 80–87% of games and Script Kiddie in 99%.

**Bots reserve cards**
- Bots now use the reserve mechanic at every level. Elite holds a strong card it can't afford yet, or one that would complete an opponent's combo; Phreak reserves when it has nothing good to buy; Script Kiddie reserves at random now and then.

**Lifetime stats**
- Games against DEFCON get their own row.

## v0.20 — Back out of dialogs, clearer card pickers
**Changed your mind?**
- Click or tap outside a dialog to back out, the same as Escape or the phone's back button. If the choice is required, the dialog stays and says "This choice can't be skipped".
- Optional card pickers show a **Choose none** button until you select a card.
- Backing out no longer uses up the ability. You can open Disassembled Sink, FOTTR Greatest Hits, Payphone, Candy Factory, Clarion Inn Chandeliers or Tennessee Department of Health, change your mind, and still use it later that turn.
- The inspect view, in-game menu, rules page, ban picker and Hero picker also close when you click outside them.

**Hand and discard pile separated**
- When a card picker offers cards from more than one place, they are grouped under headers such as "YOUR HAND · 5" and "YOUR DISCARD PILE · 4", so identical Hackers and Attacks are no longer mixed together.

**Fix**
- A player finishing below zero life could make a saved game lose its match stats.

## v0.19 — Flesh Oprah prompt
**Fix**
- **Flesh Oprah:** the card lets you remove it to buy O.P.R.A.H. for free, which only works on an O.P.R.A.H. you can buy (in the Center Row or your reserve). The prompt used to offer this even when there was none, so the card could be removed for nothing. It now warns you first: "O.P.R.A.H. is not in the Center Row or your reserve right now. Remove this card anyway?"

**Housekeeping**
- The changelog file is now called `RELEASE_NOTES.md`.

## v0.18 — Auto-activate and card-face avatars
Both additions in this version started as pull requests from **@mogorman**. Thank you!

**Auto toggle on cards** (idea and first version by @mogorman)
- Permanents with a free once-per-turn ability now carry an **Auto** toggle: Botnet, Mognet, Tableskirts, Unattended Phone, The Big Dipper and Shell Speech. Turn it on and the card activates by itself on each of your turns.
- The toggle is per card name (switching one Botnet switches them all), is remembered between games, and is off until you turn it on.
- Botnet and Mognet wait while you still have a playable copy in hand, so you never lose Hacking by firing early. If you end your turn with one waiting, it fires first.
- Works in games against bots and in online games.

**Card-face avatars** (by @mogorman)
- If your handle is the name of a card (for example `notlarry`), your avatar is that card's art. This shows at the table, in the menu preview, in the online lobby and on the result and stats cards.

## v0.17 — Lifetime stats
**Your stats**
- The game now keeps your record on your device: games, wins, win rate, best streak and time played, split into games against bots, online against players and online against bots, with breakdowns by bot difficulty, card set and table size.
- It also tracks your favourite Hero, your signature card, your most-bought card, and records such as biggest hit and fastest win.
- Open it with **Stats** on the main menu, or **Lifetime stats** on the end-game summary. Tutorial games and unfinished games are not counted.
- **Share your record:** save a stats card image or share it the same way as the end-game card (copy text, X, Bluesky, Reddit, Facebook, Discord, or the share sheet in phone browsers).
- Stats are stored on this device only, with a **Reset stats** button. No account or sign-in.

## v0.16 — Bot pace and turn recap
**See what the bots did**
- Opponents' plays now show as one row: the newest card large, earlier cards as thumbnails beside it. Nothing is skipped on long turns any more (before, only four cards fitted and the rest were dropped).
- When your turn starts, the row stays as a recap ("Since your turn: 12 cards") until your first click, tap or key press.

**Bot pace**
- Bot speed is now a **Bot pace** dropdown: Instant, or 0.25 / 0.5 / 1 / 1.5 / 2 / 3 / 5 seconds per card. It is on the main menu, the in-game menu and the toolbar. Your old setting carries over (Normal → 0.5 s, Fast → 0.25 s).
- **Online:** the host sets the bot pace for the room, when creating it or in the lobby. New rooms default to 0.5 seconds per card (online bots used to act instantly).

**Fixes**
- End-game summary: **View final deck** opened behind the summary and made the screen seem frozen. It now opens on top.
- Automated tests: a scripted test player could leave a "choose a card" prompt unanswered, which made the network test suites fail at random.

## v0.15 — Feel, phones and sharing
**Cards move**
- Played, bought, drawn and discarded cards now slide from where they were to where they go, instead of fading in. Hidden cards travel face down.
- The table no longer rebuilds every card on each change, so it stays smooth on phones.
- Short win/lose transition, and the damaged player's life counter shakes.

**Phone layout**
- New layout for phones (automatic; change it under Settings → Layout: Auto / Desktop / Phone): larger hand cards, large buttons, a compact opponent row, and the log as a slide-out drawer.
- On phones, tap a hand card to raise it, then tap **Play** — so a mis-tap does not play a card.
- On every screen, the log can be collapsed with the **Log** button, and the hand and Center Row cards are larger.

**End-of-game summary and sharing**
- The result screen now shows a match summary: life, damage, cards bought and played for every player, biggest hit, star card (your most-played card that is not a starter), priciest buy, turns and duration, plus **View final deck**.
- **Share your result:** save a result card image, copy a text summary, or open a post on X, Bluesky, Reddit or Facebook. The Discord button saves the image and copies the text, ready to paste. On phone browsers, **Share…** opens the system share sheet with the image attached.

**Tutorial**
- A guided first game (main menu → Tutorial, offered once on first launch) walks through playing, buying, attacking and ending a turn.

**Why can't I play this?**
- Tapping a card you cannot play or buy now says why ("Costs 6 Hacking — you have 4", "Nashville 2600 is in play…").
- Playable and affordable cards get a small badge as well as the coloured border.

**Online**
- A countdown shows how long you have before a bot answers for you, and other players show an idle timer.
- Eight preset emotes (GG, Nice play, Hack the planet!, …), with a setting to mute them.

**Sound**
- Optional ambient music with its own volume slider.
- New sounds for "your turn", a player being eliminated and the idle warning; card sounds vary slightly in pitch; reserving a card online plays the reserve sound.

**Options**
- Bot speed is now Normal / Fast / Instant.
- "Visual effects" off now stops every animation.

**Smaller download**
- The web version's game data is about 16 MB smaller (the Mog Variant art was stored uncompressed).

## v0.14 — Designer rulings
**Rules update** from the card game's designers (2026-11-10, 18 rulings; full text in `reference/rulings-2026-11-10.md`)
- **I've got the Logs:** only opponents who reveal the named card take damage (its printed cost), one separate hit each. Before, every opponent took the damage if anyone revealed it. Logs is still removed from the game if anyone reveals the card, and you still draw a card if no one does.
- **Fore04 + The Fellowship of the Token Ring / pTFS:** buying Fore04 now offers exactly one destination for it (top of deck, hand, or onto pTFS), chosen by you.
- The other 16 rulings confirm how the game already plays; they are now written into the rules (extra turns repeat start-of-turn effects, O.P.R.A.H. counts as acquiring, ICE absorbs all life loss, and more).

**Main menu**
- Credit line: "Digitized by Nirtom & Claude".

## v0.13 — Mog Variant
**New card set: Mog Variant · PhreakNIC 27**
- A third card set, alongside the 2025 base game and the 2026 expansion: the 2026 card pool with 48 cards swapped for their Mog Variant versions (Touch Mog, Mog Wonka, The Big Mogger, Who is Mog? and more), with new art and flavor text. Choose it on the main menu or when creating an online game.
- The cards play exactly like the originals, except **Mognet**, which counts cards named "Mognet" (like Botnet counts Botnets). "Who is Mog?" has every card name, so it counts too.
- Bans, saves, online rooms and bot Hero names all work with the new set.

**Joining by link**
- Opening an invite link no longer joins instantly as "You". You get a "Join game" step where you can type a handle or pick a Hero first (so your avatar shows at the table), then join.
- Joining by code or from the open-games list with the default name also asks once before joining.

**Server diagnostics**
- The game server's diagnostic lines (prompts, timeouts, idle turns, refused actions) now reach Cloudflare's logs, so problems like a stuck turn can be traced.

## v0.12 — Smarter bots and card bans
**Smarter bots**
- **31337 Elite** now wins about 64–69% of head-to-head games against the v0.11 Elite (400-game benchmarks on both card sets). It values cards like Greatest Hits Vol 2 properly, saves its damage for the right moment, steals the right targets, and stops trashing its own offense and economy.
- **Phreak** gets a lighter version of the same improvements (about 62–65% against the old Phreak).
- **Script Kiddie** plays exactly as before, so new players still have a friendly opponent.
- Bots still only use information a human player could see.

**Card bans**
- The party leader can remove cards from the game before it starts: on the main menu for offline games, and in the room settings (host only) online. Pick them in a searchable card grid; at least 40 cards always stay in the Center Row deck.
- Everyone in the lobby can see which cards are banned, and the open-games list shows how many.

**Fixes**
- **Host leaves the lobby:** if the host leaves before the game starts, the room now closes for everyone with a message, instead of leaving guests stuck in a dead room. If the host just loses connection, the room waits 60 seconds for them to come back.
- **Server diagnostics:** the game server now logs prompts, answers, timeouts, idle timers, refused actions (with the reason) and connections, without any card or hand details, so problems like a player being unable to act can be traced.
- **Android:** the README now explains Google Play Protect's "unknown developer" warning (tap Install anyway).

## v0.11 — Security
This release comes from a full security audit, since PhreakNIC is a hacker con and you will poke at it. Found something? See [SECURITY.md](SECURITY.md) to report it privately.

**Fair games**
- **Unpredictable shuffles online:** the server now uses cryptographic randomness for every shuffle, draw and random effect, so no one can work out the deck order or other players' hands from what they can see.
- **No more stalled turns:** if a player sits idle on their own turn online, they get a warning after 2 minutes and a bot finishes that turn at 3 minutes. Players who keep idling are handed to a bot, the same as a disconnect.
- **Oprah Wonka** no longer shows your deck in its real order when you search it.

**Online play**
- **Open games list (server hotfix, live since v0.10):** the list only shows games on the current version, so you can't pick one you can't join.
- **Older games:** joining a game made with an older version now says so and suggests creating a new one, instead of telling you to update.
- **Hosts can remove players** from the lobby before the game starts.
- **One device per seat:** opening your seat somewhere else takes it over and tells the old one, instead of both fighting over it.
- **Clearer messages** when the servers are full, paused for maintenance, or your network has made too many attempts.
- **Server protection:** limits on running games, daily game starts, room lifetime (8 hours), connections and messages keep the servers up and the bill sane during the con.

**Safety and trust**
- **Verified downloads:** every release lists SHA-256 checksums, and the Android app is now signed with the project's release key (see SECURITY.md for the fingerprint). Because the signing key changed, **uninstall the old Android version before installing this one** (your offline save on Android is lost; online games aren't affected).
- **Bug reports** now replace other players' names in the attached log.
- **Website hardening:** strict security headers on phreaknic-ccg.net, and the game no longer runs any JavaScript `eval`.
- **Sturdier server and saves:** malformed messages, save files and settings are rejected safely (thousands of fuzzed messages are now part of the tests).
- **Automated tests** run on GitHub for every change.

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
