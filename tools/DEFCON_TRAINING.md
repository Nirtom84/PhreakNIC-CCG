# Reproducing the 2026-11-12 DEFCON weights

Requires Godot 4.7.1 and Python with NumPy. Run from the project root. Every
Godot process needs a separate temporary `XDG_DATA_HOME`. The following runs
16 independent processes at once; the handicap batch runs eight.

```bash
run_dir=$(mktemp -d)
train_batch() {
 local label=$1 iteration=$2 epsilon=$3 first_seed=$4 shards=$5 weights=$6 bonus=$7
 for pool in 2025 2026; do
  for ((shard=0; shard<shards; shard++)); do
   (
    export XDG_DATA_HOME=$(mktemp -d)
    export TRAIN_POOL=$pool TRAIN_SEED=$((first_seed + shard * 1000))
    export TRAIN_GAMES=1000 TRAIN_ITERATION=$iteration TRAIN_EPSILON=$epsilon
    export TRAIN_BONUS=$bonus TRAIN_OUT="$run_dir/$label-$pool-$shard.json"
    if [ -n "$weights" ]; then export TRAIN_WEIGHTS="$weights"; else unset TRAIN_WEIGHTS; fi
    ~/.local/bin/godot4.7.1 --headless -s tests/defcon_train.gd > "$run_dir/$label-$pool-$shard.log" 2>&1
   ) &
  done
 done
 wait
}
train_batch i0 0 .35 1000000 8 '' 0
OPENBLAS_NUM_THREADS=1 python3 tools/defcon_fit.py "$run_dir/i0-*.json" --output "$run_dir/i0.json"
train_batch i1 1 .25 1100000 8 "$run_dir/i0.json" 0
OPENBLAS_NUM_THREADS=1 python3 tools/defcon_fit.py "$run_dir/i[01]-*.json" --output "$run_dir/normal.json"
```

The handicap experiments used the first fit with its 2025 coefficients multiplied
by four (the 2026 coefficients were unchanged). Make that immutable snapshot:

```bash
python3 - "$run_dir/i0.json" "$run_dir/i0-picked.json" <<'PY'
import json, sys
x = json.load(open(sys.argv[1]))
for id, values in x['pools']['2025'].items():
 x['pools']['2025'][id] = [round(v * 4, 5) for v in values]
json.dump(x, open(sys.argv[2], 'w'))
PY
train_batch bonus 1 .35 1200000 4 "$run_dir/i0-picked.json" 1
OPENBLAS_NUM_THREADS=1 python3 tools/defcon_fit.py "$run_dir/bonus-*.json" --output "$run_dir/bonus.json"
python3 tools/defcon_pack.py "$run_dir/normal.json" "$run_dir/bonus.json"
```

`defcon_pack.py` applies the measured selection: normal multipliers 2/1 for
2025/2026, handicap multiplier 2, normal buy thresholds 1.8/1.8/1.8, and handicap
thresholds 0/0/0. It preserves training seeds, game counts and outcome statistics
inside the JSON. No opponent hand or deck order is a feature. With `TRAIN_BONUS=1`
only the alternating double-life learner explores; its opponent stays plain Elite.
With `TRAIN_ITERATION=1` the normal batch uses learned deciders on both seats.
Game RNG and exploration RNG are independent and reset per seed.

Each recorded `(card, phase)` statistic counts a buyer/game once and records
wins (draws count half) and signed outcome divided by the square root of the
remaining own turns. Regression uses randomized decisions only: a selected-card
indicator minus the mean indicators of all affordable choices and stopping.
Ridge 40 shrinks the adjustment to zero, preserving Elite's heuristic as the
prior. The target is `(win - 0.5) + 0.15 * tempo`. Three phase fits are independent.

A benchmark process supports `DEFCON_POOL`, `DEFCON_GAMES`, `DEFCON_SEED`,
`DEFCON_BONUS`, `DEFCON_SEATS`, `DEFCON_COUNT`, `DEFCON_WEIGHTS`, and
`DEFCON_OUT`. Omit `DEFCON_COUNT` or set it to -1 for the shipped live policy;
0 skips exact lethal as well as rollouts; positive counts enable the experimental
rollout path, capped by count **and** time. For tuning only, `DEFCON_SCALE`,
`DEFCON_THRESHOLD` (a JSON array), `DEFCON_MARGIN`, and `DEFCON_FILLER` override
settings in a separate process. `DEFCON_SLOW=1` logs turns exceeding 500 ms.

For each pool/bonus pair, run four processes of 100 games with seeds
930000, 930100, 930200, 930300 and separate output files/data directories.
Aggregate their JSON with `python3 tools/defcon_report.py 'path/to/results-*.json'`.
The 400-game four-seat check used 2025, no bonus, and seeds 960000–960399.
Tuning used 950000–950199, disjoint from training and validation.

`tests/defcon_trace_hashes.json` was captured from the original uncommitted v0.21
working tree **before** shared AI edits: levels 0–2, all three pools, seeds
77101–77103. `tests/defcon_traces.gd` verifies these hashes; its `--record` option
exists for intentional future baselines and must not be used to update this
regression expectation merely because a test fails.

## Million-game all-DEFCON self-play (offline only)

`tests/defcon_selfplay.gd` reuses the trainer's purchase-policy hook: every
seat is level 3 with its normal double life, and each purchase decision has an
independent 25% chance to pick uniformly from affordable card instances plus
stopping. Experiment RNG is separate from game RNG. Exact lethal/rollouts are
disabled (`DefconSearch.fixed_rollouts = 0`), matching the existing trainer.
The first player rotates with shard-local game index modulo seat count.
Names are statistics labels only: Nirtom, Reps4Thor, Bitwize, 5ud0; no Hero is
selected or added. `setup` receives an empty decider-choice list.

Shard environment: `SP_SEATS=2|3|4`, `SP_POOL=2025|2026`, `SP_SEED`,
`SP_GAMES`, `SP_EPSILON` (default .25), `SP_OUT`, optional `SP_WEIGHTS`.
Output is a sibling `.tmp` file followed by atomic rename. Games that reach
200 turns are draws; errors are counted with seeds and excluded from the fit.
The Godot error logger observes runtime errors without aborting the shard.
`SP_TEST_ERROR_SEED` is an optional fault-injection check, never used in normal
runs. Engines are freed and a frame is yielded between games.

The plan contains exactly 1,000,000 games in 500 shards of 2,000:

| Seats | Pool | Games | Inclusive seed range |
|---|---|---:|---|
| 2 | 2025 | 200,000 | 60,000,000–60,199,999 |
| 2 | 2026 | 200,000 | 61,000,000–61,199,999 |
| 3 | 2025 | 150,000 | 62,000,000–62,149,999 |
| 3 | 2026 | 150,000 | 63,000,000–63,149,999 |
| 4 | 2025 | 150,000 | 64,000,000–64,149,999 |
| 4 | 2026 | 150,000 | 65,000,000–65,149,999 |

Each configuration has a separate million-seed block, and shard offsets within
a block never overlap. These ranges are disjoint from previous training,
tuning and validation ranges above, the 31–32 million shard checks, the initial
30–35 million tiny-plan check, and the 70–75 million scaled-plan checks.
Shard order interleaves the six configurations. `plan.json` is immutable on
resume. The starting weights are snapshotted to `training_weights.json`;
resumes use that snapshot. Every worker runs at nice 10 with a separate
`XDG_DATA_HOME`, removed when its process exits normally. SIGKILL can leave a
temporary directory; unfinished JSON `.tmp` files are ignored and overwritten.
Only one orchestrator should own a run directory at a time.

Launch from the repository root (the command does not need a terminal):

```bash
mkdir -p build/selfplay/run1
nohup setsid tools/defcon_selfplay.sh build/selfplay/run1 24 > build/selfplay/run1/driver.log 2>&1 < /dev/null &
```

Inspect progress and regenerate the image at any time:

```bash
python3 tools/defcon_selfplay_report.py build/selfplay/run1
cat build/selfplay/run1/summary.txt
# Graceful stop: active shards finish, no new shards start.
touch build/selfplay/run1/STOP
# Resume after the previous orchestrator exits:
rm build/selfplay/run1/STOP
nohup setsid tools/defcon_selfplay.sh build/selfplay/run1 24 > build/selfplay/run1/driver.log 2>&1 < /dev/null &
# After completion (never installs weights):
tools/defcon_selfplay_finish.sh build/selfplay/run1
```

Reports merge finished planned shards only, summing counts and sparse matrices,
and selecting records with their original seed/pool/seats/name. The elimination
matrix is indexed by the four names above (source row, victim column); only
observed lethal damage gets finishing-blow credit, so forced card eliminations
without a damage source have no credited attacker. TOCTOU rescues do not count
as eliminations. Damage includes resolved life loss from damage sources,
including non-"dealing" effects. Hacking spent includes purchases, numbered
Hacking payments and paid activations; instrumentation delegates every decision
and action unchanged. Starter cards count as played but cannot be star cards;
star-card ties select the first card encountered. `winner_games_bought` counts
each card once per winning game, so the card image's winningest-card percentage
cannot exceed 100%. Comeback is the lowest observed nonnegative life divided by
the winner's starting life (smaller is better).

For N seats, wins/losses/draws are 1 / 0 / 1/N. The regression target is
`(win - 1/N) + 0.15 * tempo`, where
`tempo = 2 * (win - 1/N) / sqrt(remaining own turns)`, retaining the 2P trainer's
formula at N=2. Randomized decisions alone accumulate sparse X'X and X'y per
phase; no per-game rows are stored. Ridge 40 is applied **once** after merging.
Per-buyer/card/phase outcome statistics retain the existing trainer format.
`defcon_fit.py` still accepts legacy sample shards with the original 2P centre.

`summary.json`, `summary.txt` and `stats_card.png` work with partial or zero data.
Throughput from summed shard wall times is per worker; the 24-worker ETA assumes
linear scaling and similar CPU availability, and is unknown until every
configuration has a finished shard. Overall player win rates have different
mixtures of table sizes; the card also gives wins–games separately for 2P/3P/4P.

Finishing writes `selfplay_fit.json`, `candidate_weights.json`, four benchmark
JSON/log pairs, and `finish_report.md` inside the run directory. The existing
packer already supports `--output`; shipped data is never overwritten. The
same combined fit supplies normal and handicap candidate tables using the
existing packer's multipliers and settings. Benchmarks use live DEFCON without
exploration, with equal base life for every seat. Static weight tables are
swapped per seat **in the benchmark only**, restoring tables after nested
reaction turns. Candidate seat and starting seat rotate independently in a
balanced schedule. Default checks are 1,000 games for each pool at 2P, plus
1,000 games for each pool at 4P (one candidate versus three shipped opponents).
Seeds occupy blocks starting at 80,000,000 / 80,100,000 / 80,200,000 / 80,300,000.
The verdict requires a lower 95% Wilson bound over 50% in both 2P pools and no
4P upper bound below 25%; "not better" includes insufficient evidence.

For a disposable 500-game integration check (six workers, shard size 50):

```bash
tiny_run=$(mktemp -d)
SP_PLAN_SCALE=0.0005 tools/defcon_selfplay.sh "$tiny_run" 6
python3 tools/defcon_selfplay_report.py "$tiny_run"
SP_FINISH_GAMES=12 SP_FINISH_FOUR_GAMES=8 SP_FINISH_SEED=40000000 tools/defcon_selfplay_finish.sh "$tiny_run"
```

Scaled plans default to the separate 70–75 million seed blocks and shard size
50; `SP_SHARD_SIZE` can override shard size. The six per-config counts use
integer truncation when scaled: .0005 gives exactly 100/100/75/75/75/75 games.
`SP_FINISH_GAMES`, `SP_FINISH_FOUR_GAMES` and `SP_FINISH_SEED` are only intended
for small tooling checks. Do not interpret the tiny-run verdict as validation
of million-game weights. No binary image samples belong in the repository.
