# PhreakNIC CCG online server

This Worker serves `https://online-01.phreaknic-ccg.net`; the website Worker is separate. One SQLite Room Durable Object owns each room's settings, seat secrets and latest authoritative snapshot, plus one lite Godot container. The global SQLite Lobby stores room reservations, public summaries and IP rate counters. Only the Room talks to the trusted `/link` socket; player sockets never reach Godot directly. Container disk is disposable.

## HTTP and clients

All browser requests must originate from `https://phreaknic-ccg.net`, `https://www.phreaknic-ccg.net`, `https://nirtom84.github.io`, or HTTP localhost/127.0.0.1 (any port). Native requests without Origin work. JSON HTTP responses disable caching. OPTIONS supports GET/POST and Content-Type.

- `GET /health`: `ok` (Worker health, not container readiness).
- `GET /rooms`: `{rooms:[{code,host,seats:[{name,hero,bot,difficulty}],open_seats,card_pool,starting_life,version,created}]}`. Only public, unstarted, unfilled rooms appear; timestamps are Unix milliseconds.
- `POST /rooms`: `{name,hero,public,seats:[{bot,difficulty},...],card_pool,starting_life,version}` → HTTP 201 `{code,seat:0,token}`. Supply 2–4 seats including the creator at index 0; that seat is always human. Remaining human seats initially have empty names and no tokens. Bot names default to `Bot`, heroes to empty strings for the game server's default selection. Difficulty is an integer 0–2. Names are trimmed printable Unicode, 1–16 code points; hero identifiers are trimmed printable strings of 1–64 code points; versions are printable ASCII, 1–32 characters. Card pool is `2025`, `2026` or `2026mog` (Base Set + Expansion 1 · Mog Variant); life is 0, 20, 30 or 40. Public must be a boolean.
- `POST /rooms/CODE/join`: `{name,hero,version}` → `{seat,token}`. Claims the first empty human seat. Started/full rooms return 409. Version mismatch returns HTTP 409 `{error:"version",need:GAME_VERSION}` when the deployment version is set; a current client joining an older room receives 409 `{error:"room_version",room:<room version>}`.
- `GET /ws/room/CODE?token=SECRET`: WebSocket upgrade. Codes are uppercase, four unambiguous symbols. Store the 128-bit hex token privately for reconnection; never put token-bearing URLs in logs or analytics. Only one socket per seat is allowed; a new authenticated connection closes the old socket with 4000 `replaced`.

Both create and join check the client's version against `GAME_VERSION` when it
is nonempty, returning HTTP 409 `{error:"version",need:GAME_VERSION}` before room
allocation or seat claims. The empty placeholder in wrangler.jsonc disables this
release gate; the existing per-room version check still applies to joins.

Online bots with empty/default names receive unique seeded non-starter Hero names
and avatars from the selected card pool on the game server, excluding human
identities. Welcome and snapshots preserve them. Other players receive public
`waiting`/`waiting_done` events while a seat chooses; prompt cards/options stay private.

HTTP errors use `{error:reason}`. Creation is limited to 60 attempts per IP per hour and joins to 300 (generous, because everyone on a convention's Wi-Fi shares one public IP); rate rejection is 429. HTTP bodies and client WebSocket messages are capped at 64 KiB. Limits aggregate by seat across reconnects: 30 messages/second and 256 KiB/10 seconds. Excess messages are dropped; sustained flooding closes with 1008. Oversized or binary frames close the socket. WebSocket attempts are limited to 60/IP/minute, lists to 120/IP/minute; join and WebSocket authentication failures share a 30/IP/hour limit. Unknown rooms and invalid WebSocket tokens both return 401 `{error:"token"}`. Listings contain at most 50 rooms and are cached for five seconds.

## Lobby and game WebSocket protocol

The Room sends this state on connect and after lobby changes:

```json
{"t":"room","code":"K7QX","seats":[{"name":"Nirtom","hero":"nirtom","bot":false,"difficulty":0,"connected":true}],"host_seat":0,"started":false,"public":true,"card_pool":"2026","starting_life":0}
```

The host sends `{t:"lobby",action:"start"}`, `{t:"lobby",action:"add_bot",difficulty:2}`, `{t:"lobby",action:"remove_seat",seat:1}`, or `{t:"lobby",action:"settings",public:false,card_pool:"2025",starting_life:30}` (settings may be partial). A nonhost may send `{t:"lobby",action:"leave"}`; its token is revoked and its human seat reopens. Removed seat indices shift; clients should use the next room broadcast. Seat 0 cannot be removed. Rooms retain 2–4 seats. All human slots must be claimed before start; remove unfilled slots and/or add bots first. An accepted start reserves its Lobby budget before locking joins and broadcasts `started:true` while boot proceeds. Invalid lobby commands send `{t:"error",reason:...}`.

During startup/recovery the Room sends `{t:"server",status:"restarting"}`, then `status:"ok"` once the link accepts setup/restore, or `status:"unavailable"` after three failed attempts. A later reconnection retries. Clients should wait for game welcome/view messages before submitting actions. On finish clients receive the opaque game server `game_over` and the room lifecycle message `{t:"over",winner:0}` (-1 means draw).

After start, send the GameServer action/answer JSON directly; Room wraps it as `{t:"from",seat,msg}` without interpreting its fields. GameServer welcome/view/prompt/prompt_done/log/event/game_over/error payloads are unwrapped from `{t:"to",seat,msg}` and delivered unchanged. Version checks on each container connect use the room's locked version.

## Container lifecycle

The Room starts `ctx.container.images.base` as `lite` with Internet disabled, polls `/health` for up to about 30 seconds, then upgrades `/link` and waits up to five seconds for `ready`. It sends setup with a persisted random 31-bit seed (bot tokens are empty), or restore with the last saved snapshot, followed by connect for each online human. Snapshot messages replace the SQLite save; game messages stay opaque. Before the first snapshot, recovery repeats setup with the same seed. Any action after the last acknowledged snapshot can be lost on a crash; clients must render the restored authoritative view.

Both link closure and container monitor completion trigger recovery, with three bounded attempts and exponential backoff. After Durable Object restart, inactivity timeout and monitor are reattached for a running container; the next player reconnect opens its link. Player WebSockets use ordinary acceptance, not hibernation, and must reconnect if the object restarts. When no human socket remains, an alarm destroys the container after ten minutes and retains the snapshot. A later connection restores it. At the hard lifetime of eight hours from creation an alarm destroys the container, closes sockets, deletes storage and releases the code. Snapshots alone do not extend expiry. Lobby lists omit expired entries even if room cleanup is delayed.

## Build, deploy and local development

Docker must be running and the binary must be a self-contained linux/amd64 Godot server export (embed the PCK). Build first with `tools/build_all.sh server`, then run:

```sh
tools/deploy_online.sh
# Local Docker containers, no custom domain and no cloud credentials needed:
tools/deploy_online.sh --dev
node --test cloudflare/online/test/
```

The deploy helper reads `config/version` from project.godot and passes
`--var GAME_VERSION:<version>` in both deploy and `--dev` modes. It copies `build/server/phreaknic-server.x86_64` into the ignored container path. Production sources `~/.config/phreaknic/cf-env.sh` only when CLOUDFLARE_API_TOKEN is unset, then invokes `npx --yes wrangler@4 deploy`. It never prints credentials. Dev uses the `dev` environment, repeats the noninherited bindings/container config, and has no routes. Point clients to the localhost address Wrangler prints; browser clients must originate from an allowed HTTP loopback origin. Native Godot clients can use local `ws://`.

`wrangler.jsonc` follows the locally cached Wrangler 4.160.0 JSON schema: `scheduling_policy:"durable_object"`, named `images.base.dockerfile` and `build_context`, SQLite declarative `exports`, and a named container explicitly attached with `exports.Room.container`. No migrations are combined with exports. This adds explicit container names/attachment to the supplied minimal example; its listed container keys are supported unchanged. Schema validation does not prove runtime Container API behavior.

## Costs, limits and remaining deployment checks

Workers Paid and Containers access are required. Each active room uses lite (256 MiB, 1/16 vCPU, 2 GB disk per the cached schema); RAM/CPU/disk runtime, Worker/DO requests, storage and nonhibernating WebSocket duration contribute to costs. The plan's rough $5/month and room-hour estimates are planning assumptions, not a verified current quote. Confirm actual pricing and configure usage alerts in Cloudflare before operating at scale. Empty rooms can bill for up to ten minutes before sleep; the Lobby also enforces global spending caps: at most 20 live started games and 300 game starts per UTC day. Entries expire at the room lifetime and release on finish, idle destruction, failed boot, and expiry. Recovery of a counted room bypasses the caps; reacquiring a released slot counts as another start. Cap rejections return 503 `busy` (or a lobby error). Set Worker var `ONLINE_ENABLED` to `"0"` to disable create/join/start with 503 `maintenance`; it defaults enabled. Daily counters include `refused.busy` and `refused.maintenance`. Connections alone never refresh activity or extend the eight-hour lifetime. Four-symbol codes have finite capacity; creation retries up to 100 random reservations. The SQLite reservation covers private, full and started rooms too.

Pure tests need no npm install. The directory entry point includes both pure decision and mocked runtime tests. In this sandbox the requested directory command reports one passing file-level test; running `node --test --experimental-test-isolation=none cloudflare/online/test/protocol.test.js` exposes all individual tests. `test/package.json` supplies the directory entry point for Node 22. A live smoke test must still verify Wrangler provisioning/custom domain, container runtime API, image architecture and shared libraries, embedded PCK, health/link handshake, real Godot snapshot restore and version errors, monitor exits, retries, alarms, multi-client reconnects, CORS upgrades, and local Docker dev. No cloud deployment or Docker build is performed by the test suite. Avoid request URL logging because the WebSocket URL carries a seat secret.

## Admin panel

Open https://online-01.phreaknic-ccg.net/admin for live public room, active game and connected client counts; daily activity, platform/version/settings breakdowns, game durations, recent games and server health. Release asset download totals load directly from public GitHub in your browser. Choose 7, 30, 90 or 365 UTC days; the API accepts 1–400 days. Daily counters are retained for 400 days and individual game rows for 90 days, so duration samples and recent games only cover retained games. Connected clients are socket counts (one per seat); counts become stale after 15 minutes without a Room update. Active games also require a start within 24 hours.

Stats contain no player names, IP addresses or tokens. Random room codes are retained in game rows. Existing IP rate counters remain separate from stats, including failed admin authentication attempts. Create/join bodies optionally accept `platform` (`windows`, `linux`, `macos`, `android`, `ios`, `web`); missing is `unknown`, all other values are `other`. It is used only for stats and never sent to players or the container.

Configure a random key of at least 32 characters using stdin from a secure generator or password manager, from `cloudflare/online/`:

```sh
npx wrangler secret put ADMIN_KEY
```

Paste the key into Wrangler's stdin prompt, then enter it in the panel. An unset or shorter key disables every admin route (404). The browser keeps the key only in sessionStorage; Lock forgets it. The stats API requires `Authorization: Bearer <key>`, allows only the panel's own Origin or no Origin, and limits failed authentication to ten attempts per IP per hour. Admin responses disable caching and have no CORS headers. Cloudflare Access can be put in front of `/admin` and `/admin/*` later for extra protection.

## v0.11 moderation and errors

Before start the host may send `{t:"lobby",action:"kick",seat:1}` for a joined human other than the host. It clears the identity and token, reopens the seat, and closes its socket with 4001 `kicked`. Use `remove_seat` for bots.

Clients must handle `busy`, `maintenance`, `room_version`, `rate_limit`, `kicked` (4001), and `replaced` (4000). Existing `version` errors keep their `need` field. Accepted lobby actions and forwarded game messages refresh activity; rejected commands and connections do not.

To rotate the admin key, generate a new random key and pass it directly on stdin from `cloudflare/online/`:

```sh
openssl rand -hex 32 | npx wrangler secret put ADMIN_KEY
```

Store the new key securely and enter it in the admin panel. Nothing else changes; the previous key stops authenticating. The per-IP failure bucket is checked before comparing any key; a locked address receives 429 even with the correct key until its one-hour window expires.

Deploy helpers use a private temporary `DOCKER_CONFIG` (mode 700), removed by an EXIT trap on success and failure so registry credentials never persist.

The site Worker caches full WASM responses under the versioned R2 path and remembers strong ETags by version, allowing conditional 304 responses without R2 reads. Site responses carry CSP, nosniff, referrer, HSTS, and minimal permissions headers. HTML scripts receive a fresh CSP nonce so the Godot inline bootstrap runs without allowing arbitrary inline scripts. HTML is not cached. The policy permits WebAssembly compilation and self/blob workers; browser verification must cover audio worklets and JavaScriptBridge calls (the export contains `eval`, which this CSP deliberately does not authorize).

### Party bans and pregame room closure (0.12)

Create and lobby `settings` accept optional `banned` (default `[]`): an array of
at most 150 unique printable ASCII card IDs, each at most 64 characters.
The Worker validates shape only. A changed `card_pool` clears bans. The room
broadcast and container `setup` include `banned`; public summaries include
`banned_count`. Godot filters IDs to the selected center pool, expands copies and
refuses setup unless at least 40 center-deck cards remain before dealing five.
Authoritative snapshots retain the normalized list.

A host's lobby `leave` closes an unstarted room for everyone. Other sockets receive
`{t:'room_closed',reason:'host_left'}` followed by WebSocket code **4002**, reason
`closed`. Clients forget the seat and stop reconnecting. An unannounced pregame
host disconnect gets a persisted, alarm-based 60-second grace period; authenticated
host reconnect cancels it. Closure deletes room storage and the lobby entry and
increments daily `rooms.closed_by_host`; the code may be reused. Started games
keep their existing lifecycle.

Version 0.13: invite links open the online identity panel and wait for an explicit Join as / Join anyway press. Default identities joining by code or open-game list also receive a one-time identity prompt. Players without a Hero use the FOTTR logo.

Container diagnostics now cross the trusted room link as `{t:'diag',text}`. LinkServer limits forwarding to 120 lines per minute per room (including a final muted note), preserving stdout. Room.linkMessage logs string text only as `room CODE: TEXT`, truncates to 300 characters, ignores non-strings and never broadcasts diagnostic lines. These messages are visible to `wrangler tail`.
