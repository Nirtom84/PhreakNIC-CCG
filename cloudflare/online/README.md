# PhreakNIC CCG online server

This Worker serves `https://online-01.phreaknic-ccg.net`; the website Worker is separate. One SQLite Room Durable Object owns each room's settings, seat secrets and latest authoritative snapshot, plus one lite Godot container. The global SQLite Lobby stores room reservations, public summaries and IP rate counters. Only the Room talks to the trusted `/link` socket; player sockets never reach Godot directly. Container disk is disposable.

## HTTP and clients

All browser requests must originate from `https://phreaknic-ccg.net`, `https://www.phreaknic-ccg.net`, `https://nirtom84.github.io`, or HTTP localhost/127.0.0.1 (any port). Native requests without Origin work. JSON HTTP responses disable caching. OPTIONS supports GET/POST and Content-Type.

- `GET /health`: `ok` (Worker health, not container readiness).
- `GET /rooms`: `{rooms:[{code,host,seats:[{name,hero,bot,difficulty}],open_seats,card_pool,starting_life,version,created}]}`. Only public, unstarted, unfilled rooms appear; timestamps are Unix milliseconds.
- `POST /rooms`: `{name,hero,public,seats:[{bot,difficulty},...],card_pool,starting_life,version}` → HTTP 201 `{code,seat:0,token}`. Supply 2–4 seats including the creator at index 0; that seat is always human. Remaining human seats initially have empty names and no tokens. Bot names default to `Bot`, heroes to empty strings for the game server's default selection. Difficulty is an integer 0–2. Names are trimmed printable Unicode, 1–16 code points; hero identifiers are trimmed printable strings of 1–64 code points; versions are printable ASCII, 1–32 characters. Card pool is `2025` or `2026`; life is 0, 20, 30 or 40. Public must be a boolean.
- `POST /rooms/CODE/join`: `{name,hero,version}` → `{seat,token}`. Claims the first empty human seat. Started/full rooms return 409. Version mismatch returns HTTP 409 `{error:"version",need:GAME_VERSION}` when the deployment version is set; the room also requires its locked version.
- `GET /ws/room/CODE?token=SECRET`: WebSocket upgrade. Codes are uppercase, four unambiguous symbols. Store the 128-bit hex token privately for reconnection; never put token-bearing URLs in logs or analytics. Multiple sockets may reconnect to one seat; disconnect reaches Godot when its last socket closes.

Both create and join check the client's version against `GAME_VERSION` when it
is nonempty, returning HTTP 409 `{error:"version",need:GAME_VERSION}` before room
allocation or seat claims. The empty placeholder in wrangler.jsonc disables this
release gate; the existing per-room version check still applies to joins.

Online bots with empty/default names receive unique seeded non-starter Hero names
and avatars from the selected card pool on the game server, excluding human
identities. Welcome and snapshots preserve them. Other players receive public
`waiting`/`waiting_done` events while a seat chooses; prompt cards/options stay private.

HTTP errors use `{error:reason}`. Creation is limited to 60 attempts per IP per hour and joins to 300 (generous, because everyone on a convention's Wi-Fi shares one public IP); rate rejection is 429. HTTP bodies and client WebSocket messages are capped at 64 KiB. Excess client messages above 30/second are dropped; oversized or binary frames close the socket.

## Lobby and game WebSocket protocol

The Room sends this state on connect and after lobby changes:

```json
{"t":"room","code":"K7QX","seats":[{"name":"Nirtom","hero":"nirtom","bot":false,"difficulty":0,"connected":true}],"host_seat":0,"started":false,"public":true,"card_pool":"2026","starting_life":0}
```

The host sends `{t:"lobby",action:"start"}`, `{t:"lobby",action:"add_bot",difficulty:2}`, `{t:"lobby",action:"remove_seat",seat:1}`, or `{t:"lobby",action:"settings",public:false,card_pool:"2025",starting_life:30}` (settings may be partial). A nonhost may send `{t:"lobby",action:"leave"}`; its token is revoked and its human seat reopens. Removed seat indices shift; clients should use the next room broadcast. Seat 0 cannot be removed. Rooms retain 2–4 seats. All human slots must be claimed before start; remove unfilled slots and/or add bots first. An accepted start immediately locks joins and broadcasts `started:true` while boot proceeds. Invalid lobby commands send `{t:"error",reason:...}`.

During startup/recovery the Room sends `{t:"server",status:"restarting"}`, then `status:"ok"` once the link accepts setup/restore, or `status:"unavailable"` after three failed attempts. A later reconnection retries. Clients should wait for game welcome/view messages before submitting actions. On finish clients receive the opaque game server `game_over` and the room lifecycle message `{t:"over",winner:0}` (-1 means draw).

After start, send the GameServer action/answer JSON directly; Room wraps it as `{t:"from",seat,msg}` without interpreting its fields. GameServer welcome/view/prompt/prompt_done/log/event/game_over/error payloads are unwrapped from `{t:"to",seat,msg}` and delivered unchanged. Version checks on each container connect use the room's locked version.

## Container lifecycle

The Room starts `ctx.container.images.base` as `lite` with Internet disabled, polls `/health` for up to about 30 seconds, then upgrades `/link` and waits up to five seconds for `ready`. It sends setup with a persisted random 31-bit seed (bot tokens are empty), or restore with the last saved snapshot, followed by connect for each online human. Snapshot messages replace the SQLite save; game messages stay opaque. Before the first snapshot, recovery repeats setup with the same seed. Any action after the last acknowledged snapshot can be lost on a crash; clients must render the restored authoritative view.

Both link closure and container monitor completion trigger recovery, with three bounded attempts and exponential backoff. After Durable Object restart, inactivity timeout and monitor are reattached for a running container; the next player reconnect opens its link. Player WebSockets use ordinary acceptance, not hibernation, and must reconnect if the object restarts. When no human socket remains, an alarm destroys the container after ten minutes and retains the snapshot. A later connection restores it. After 24 hours without client/lobby activity an alarm destroys the container, closes sockets, deletes storage and releases the code. Snapshots alone do not extend expiry. Lobby lists omit expired entries even if room cleanup is delayed.

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

Workers Paid and Containers access are required. Each active room uses lite (256 MiB, 1/16 vCPU, 2 GB disk per the cached schema); RAM/CPU/disk runtime, Worker/DO requests, storage and nonhibernating WebSocket duration contribute to costs. The plan's rough $5/month and room-hour estimates are planning assumptions, not a verified current quote. Confirm actual pricing and configure usage alerts in Cloudflare before operating at scale. Empty rooms can bill for up to ten minutes before sleep; rate limits are per address and do not impose a global spend cap. Four-symbol codes have finite capacity; creation retries up to 100 random reservations. The SQLite reservation covers private, full and started rooms too.

Pure tests need no npm install. In this sandbox the requested directory command reports one passing file-level test; running `node --test --experimental-test-isolation=none cloudflare/online/test/protocol.test.js` exposes all nine individual passing tests. `test/package.json` supplies the directory entry point for Node 22. A live smoke test must still verify Wrangler provisioning/custom domain, container runtime API, image architecture and shared libraries, embedded PCK, health/link handshake, real Godot snapshot restore and version errors, monitor exits, retries, alarms, multi-client reconnects, CORS upgrades, and local Docker dev. No cloud deployment or Docker build is performed by the test suite. Avoid request URL logging because the WebSocket URL carries a seat secret.

## Admin panel

Open https://online-01.phreaknic-ccg.net/admin for live public room, active game and connected client counts; daily activity, platform/version/settings breakdowns, game durations, recent games and server health. Release asset download totals load directly from public GitHub in your browser. Choose 7, 30, 90 or 365 UTC days; the API accepts 1–400 days. Daily counters are retained for 400 days and individual game rows for 90 days, so duration samples and recent games only cover retained games. Connected clients are socket counts (a player can have multiple sockets); counts become stale after 15 minutes without a Room update. Active games also require a start within 24 hours.

Stats contain no player names, IP addresses or tokens. Random room codes are retained in game rows. Existing IP rate counters remain separate from stats, including failed admin authentication attempts. Create/join bodies optionally accept `platform` (`windows`, `linux`, `macos`, `android`, `ios`, `web`); missing is `unknown`, all other values are `other`. It is used only for stats and never sent to players or the container.

Configure a random key of at least 32 characters using stdin from a secure generator or password manager, from `cloudflare/online/`:

```sh
npx wrangler secret put ADMIN_KEY
```

Paste the key into Wrangler's stdin prompt, then enter it in the panel. An unset or shorter key disables every admin route (404). The browser keeps the key only in sessionStorage; Lock forgets it. The stats API requires `Authorization: Bearer <key>`, allows only the panel's own Origin or no Origin, and limits failed authentication to ten attempts per IP per hour. Admin responses disable caching and have no CORS headers. Cloudflare Access can be put in front of `/admin` and `/admin/*` later for extra protection.
