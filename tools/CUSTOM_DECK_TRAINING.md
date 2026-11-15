# Custom-deck bots and offline training

The custom planner is isolated in `scripts/ai/custom_deck/`. Normal games retain
all their original policies. `BotPlayer.purchase_value` routes custom purchases
and reserve scores through the planner; `BotDecider._init` installs its public movement observer at setup;
`BotPlayer._init` reuses that engine-owned planner across turns. Kiddie keeps its existing purchases. Phreak blends 35% of the
planner with its fixed estimates and seeded noise. Elite uses the full planner;
DEFCON adds its existing double life and exact lethal, with custom purchase
values instead of the unrelated normal learned table.

The prior combines existing base estimates, own-card named references, shared
name/text families, expected synergy weighted by remaining public composition,
and capped cost-discounted denial against the strongest visible opponent.
Deck remaining fraction and original size adjust damage versus economy. The
census subtracts unique visible card identities from the published list and
observes public movements, including returns on elimination. It never reads
Center Deck order or opponent hands. Initializing mid-game cannot reconstruct
previously unseen acquisitions now hidden; the census is exact when observation
starts at setup, except that cards O.P.R.A.H. draws into a hand count as
remaining until they are revealed. Mog originals share base weights;
Botnet/Mognet share learned values but use their distinct printing text when
deriving synergy.

Godot 4.7.1, Python 3 and NumPy are required. Run from the repository root.
Use temporary `XDG_DATA_HOME` and `XDG_CONFIG_HOME` for manual Godot commands.
The runners create separate per-worker data directories and use nice 10.

```bash
# About 2,000 games; do this before committing resources to a million.
SP_PLAN_SCALE=.002 tools/custom_selfplay.sh /tmp/custom-pilot 24
python3 tools/custom_selfplay_report.py /tmp/custom-pilot
OPENBLAS_NUM_THREADS=1 python3 tools/custom_fit.py /tmp/custom-pilot --output /tmp/custom-pilot/candidate.json
CB_WEIGHTS=/tmp/custom-pilot/candidate.json CB_RUN=/tmp/custom-pilot/bench CB_GAMES=50 python3 tools/custom_bench.py
# Full run, explicitly launched by the operator:
tools/custom_selfplay.sh /path/to/custom-million 24
# Graceful stop: current shards finish; no new shards start.
touch /path/to/custom-million/STOP
# After the runner exits, remove STOP and run the same command to resume.
rm /path/to/custom-million/STOP
tools/custom_selfplay.sh /path/to/custom-million 24
```

`plan.json` is immutable on resume. It snapshots sorted runtime
`decks/custom/*.phreakdeck.json` codes and starting weights into
`training_weights.json`. Missing/empty custom directories use validated starter
codes. Godot imports all codes with `CustomDeck.from_file_text`. Invalid deck
codes fail a shard rather than silently replacing a snapshotted deck. Only one
orchestrator may own a run directory. Completed atomic shard files are skipped;
partial `.tmp` files are overwritten. Logs and error seeds remain in the run.

The full plan is exactly 1,000,000 games: 400,000 two-player, 300,000 three-player,
300,000 four-player. Seed blocks are 81,000,000–81,399,999,
82,000,000–82,299,999, and 83,000,000–83,299,999. These avoid the older training
and the older **80,000,000–80,300,999 benchmark** ranges. Scaled pilots use the
same blocks: keep them separate from independent validation. Shards interleave
seat counts and default to 2,000 games (50 scaled); `SP_SHARD_SIZE` overrides.
Decks rotate within each seat configuration, with counts differing by at most
one when the deck count does not divide the total. Difficulty tuples enumerate
base four once per deck cycle, covering every ordered tuple in the million run
with 100 decks. The first seat rotates independently; the learner rotates seats.

One designated learner has a 25% chance per purchase decision to choose uniformly
among affordable card instances and stopping. Other seats follow their policy.
Game RNG and exploration RNG are independent per seed. Training disables exact
lethal/search, as the previous pipeline does; benchmarks retain live exact lethal.
Games at 200 turns are draws. Runtime errors exclude the game from the fit and
include its seed in the shard. Conservation failures are separately counted.

Only randomized decisions accumulate chosen-minus-choice-mean base-card feature
contrasts in sparse X'X and X'y, split into three own-turn phases (remaining deck below 20% forces late phase). Rewards are
win minus 1/seat-count, with draws neutral. Ridge 40 applies once after merging
and shrinks adjustments toward the snapshotted starting weights. The stop
coefficient is subtracted to preserve its zero-value reference. Fit artifacts
never install themselves. Text synergy and denial are prior terms; this first
format learns base-card/phase corrections, not independent pair coefficients.
Output is aggregated per shard, not per decision: with ~160 base IDs, the dense
upper bound at 500 shards is about 1–2 GB, below the 3 GB target.

Manual shard variables: `SP_GAMES`, `SP_SEATS`, `SP_SEED`, `SP_OFFSET`, `SP_OUT`,
optional `SP_PLAN`, `SP_WEIGHTS`. `tests/custom_bench.gd` uses these variables,
sets benchmark mode and accepts `CB_ORDERING=1` for difficulty comparisons.
The benchmark runner uses `CB_GAMES` per each of its four configurations,
`CB_WEIGHTS`, `CB_RUN`, and `CB_SEED` (default 89000000). Seeds start at 89,000,000 in separate 100,000 blocks;
keep CB_GAMES <= 100000. Candidate and starting seats rotate at 2P and 4P.
Two-player ordering cycles adjacent level pairs and reports each pair separately
(the mixed opponent schedule makes pooled 2P rates unsuitable for ordering).
Four-player ordering seats all four levels. The report includes Wilson 95% intervals and an explicit
strict ordering verdict. Small pilots can be noisy and may not pass ordering.

**Only ship weights if an independent benchmark shows a significant win:**
require the candidate's lower 95% Wilson bound above 50% at 2P and above 25%
at 4P, with zero errors and a satisfactory difficulty ordering check. Use at
least 1,000 games per configuration; keep validation seeds unused by tuning.
The shipped JSON is intentionally prior-only. No million-game run is automatic.

`tests/defcon_policy_checks.gd` is a RefCounted helper, so Godot cannot run it
directly with `-s`. Its scenarios run inside bot_checks and v21_checks; the
standalone `tests/defcon_policy_checks_runner.gd` also executes them unchanged.

`CB_REPORT_ONLY=1 CB_RUN=... python3 tools/custom_bench.py` regenerates the
benchmark report from its four existing JSON files without launching games.
The bot checks accept natural outcomes or the same explicit 200-turn draw cap,
check conservation and the full census after every turn, and fail on logged
script errors. Some custom decks can maintain healing stalemates indefinitely.

## Validation pilot (2026-11-13)

The final prior completed a 24-worker, 2,000-game pilot (800/600/600 at 2/3/4
seats): zero script errors or conservation failures, 128 draws including 127
turn caps, mean 54.59 turns. It took 114.61 seconds elapsed (17.45 games/s).
Summed shard time gives 1.777 games/s per worker, projecting about 6.51 hours
for 1M at 24 continuously occupied workers. Straight pilot wall-time scaling
is 15.9 hours; small-run shard tails and the full run's broader difficulty mix
make either estimate uncertain. Shards used 2.416 MB per 1,000 games, about
2.42 GB if extrapolated with the pilot's smaller 50-game shards. The full
run's default 2,000-game shards amortize those aggregate tables further.
The fit used 17,216 randomized decision contrasts and produced loadable JSON.

A fresh prior-only ordering check used seeds 89,800,000+ and 89,900,000+:
Phreak vs Kiddie 35–12, Elite vs Phreak 28–17, DEFCON vs Elite 38–9 (50 games
per pair, remaining outcomes draws). In 150 four-player games with one of each
level, wins were 0/4/17/119 in ascending difficulty order. These establish the
requested point ordering, not tight confidence intervals for every adjacent
pair. An earlier check exposed Phreak beating Elite; Phreak's seeded purchase
noise was increased before this final pilot and fresh ordering check.

The pilot candidate's 50-game-per-seat-count benchmark scored 24/50 at 2P and
15/50 at 4P, with zero errors and no significant gain. Starting weights remain
prior-only. These are pipeline checks, not permission to ship learned data.

The saved pilot report combines the completed 50-game candidate comparisons
with the separate completed 150-game **prior** ordering checks. It records the
weight source of each ordering result. Additional candidate-ordering trials
were stopped after slow healing-heavy matchups because the candidate had
already failed the win gate; candidate ordering is therefore unvalidated.
The ship verdict also requires ordering measurements from the same candidate
weights. `SP_TRACE_TURNS=1` is available for diagnosing long games by seed/turn.
The offline engine enforces the turn cap inside nested turn entry as well as
in the outer loop, so automatic extra-turn chains cannot bypass the cap.
