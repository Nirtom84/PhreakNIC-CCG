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
