# Bot benchmark

The files in `scripts/ai/baseline/` freeze the pre-0.12 policy, changing only
class names. The benchmark explicitly installs both its turn driver and its
prompt decider, including nested TOCTOU reaction turns via `engine.turn_driver`.
The engine and card catalog are shared by both policies.

Run from the repository root:

```sh
BENCH_GAMES=400 XDG_DATA_HOME=$(mktemp -d) ~/.local/bin/godot4.7.1 --headless --path . -s tests/bot_bench.gd
```

Default: 200 games **per** pool/player-count/difficulty combination (2,400 total).
At 400: 4,800 games. `BENCH_BASELINE=1` replaces the new side with the frozen
policy for a control run. Optional `BENCH_POOL=2025|2026`, `BENCH_SEATS=2|4`,
`BENCH_LEVEL=0|1|2` select individual combinations. `BENCH_TRACE=1` prints
purchase frequencies and Jenny resource availability from public play events.

Seeds are 720000 through 720000+N-1 for each combination. Duels alternate first
player. Four-player games rotate the adjacent new/new/old/old arrangement through
all four seats; first seat changes every four games, balancing all 16 combinations
for N divisible by 16. Four-player win rate means **either** new-policy seat wins,
not wins per seat. Draws (including the 200-turn cap) count as non-wins.
Intervals are two-sided 95% Wilson binomial intervals, not a confidence interval
for the difference between two experiments. Seeds are fixed reproducibility
samples, not a guarantee about every possible deck distribution.

Turn time is monotonic microseconds around the synchronous headless driver,
including engine action resolution, prompt answers, and ending the turn (including
the next start-of-turn effects). Nested reaction-driver time is assigned to the
reacting policy and subtracted from the outer call to avoid counting it twice.
No artificial action delay is used. Setup and conservation validation are outside
the timer. Timings are elapsed execution time, a conservative CPU proxy in these
synchronous runs, and vary with contention from concurrent suites.

`tests/bot_checks.gd` exercises resource ordering, enemy theft selection, and
preserving Hackers while Dick Van Dyke Stamp is active, and preserving a minimum
offensive/economic core during optional thinning. The latter prevents the
seed-12 four-player network fixture from thinning into a healing stalemate. `rules_checks.gd` is a
RefCounted helper rather than a SceneTree entrypoint; run
`tests/rules_checks_runner.gd` for its standalone checks. `sim.gd` also runs it.
