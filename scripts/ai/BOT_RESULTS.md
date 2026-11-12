# v0.12 bot results

400 games per row per experiment. Before = frozen versus frozen; after = final new versus frozen. Four-player rates combine both new seats. CIs are 95% Wilson; draws count as non-wins. Times are elapsed ms per designated-side bot turn, including engine resolution.

| Pool | Players | Level | Before win % [95% CI] | After win % [95% CI] | Turns before → after | ms/turn before → after |
|---|---:|---|---|---|---|---|
| 2025 | 2 | Elite | 45.5% [40.7, 50.4] | 69.2% [64.6, 73.6] | 36.09 → 28.09 | 6.041 → 4.501 |
| 2025 | 2 | Phreak | 50.7% [45.9, 55.6] | 65.0% [60.2, 69.5] | 28.20 → 26.42 | 1.944 → 2.197 |
| 2025 | 2 | Kiddie | 49.2% [44.4, 54.1] | 49.2% [44.4, 54.1] | 27.98 → 27.98 | 1.275 → 1.239 |
| 2025 | 4 | Elite | 52.0% [47.1, 56.9] | 63.0% [58.2, 67.6] | 47.26 → 42.62 | 3.367 → 3.660 |
| 2025 | 4 | Phreak | 53.5% [48.6, 58.3] | 54.2% [49.4, 59.1] | 42.88 → 39.18 | 2.004 → 1.535 |
| 2025 | 4 | Kiddie | 49.0% [44.1, 53.9] | 49.0% [44.1, 53.9] | 41.71 → 41.71 | 1.138 → 1.052 |
| 2026 | 2 | Elite | 48.8% [43.9, 53.6] | 64.0% [59.2, 68.6] | 40.89 → 33.07 | 12.412 → 12.600 |
| 2026 | 2 | Phreak | 49.5% [44.6, 54.4] | 62.3% [57.4, 66.9] | 32.05 → 30.70 | 3.958 → 4.874 |
| 2026 | 2 | Kiddie | 50.2% [45.4, 55.1] | 50.2% [45.4, 55.1] | 32.17 → 32.17 | 1.349 → 1.264 |
| 2026 | 4 | Elite | 45.0% [40.2, 49.9] | 57.8% [52.9, 62.5] | 49.64 → 47.26 | 5.278 → 6.997 |
| 2026 | 4 | Phreak | 51.5% [46.6, 56.4] | 57.8% [52.9, 62.5] | 46.83 → 44.13 | 1.930 → 1.850 |
| 2026 | 4 | Kiddie | 52.2% [47.4, 57.1] | 52.2% [47.4, 57.1] | 46.90 → 46.90 | 1.289 → 1.208 |

## Findings and retained changes

- Baseline text-only valuation missed powerful damage, draw, and recurring effects. In the initial 100 base-pool Elite diagnostic games, frozen Elite bought Greatest Hits Vol 2 zero times and The Juice 16 times; the improved side bought Greatest Hits Vol 2 23 times. These are diagnostic trial counts, before the final thinning guard.
- A controlled Game Show hand dealt 1 damage with the frozen driver and 3 after ordering Hacking before spending it.
- With its own Book and an enemy Botnet available, the frozen theft prompt selected its own Book. The new policy selects the enemy Botnet.
- Optional thinning could remove all starter damage and too much economy. The seed-12 four-player network fixture then stalled: at turn 337 the survivors had 308 and 469 life. Preserving damage and economy makes the network suite finish (13,177 checks, zero failures).
- Phreak receives fixed card estimates, ordering, and prompt/thinning safeguards. Elite additionally evaluates public permanent counts and board-wipe balance, and retains its existing combo, lethal, and reserve heuristics. Kiddie decisions remain identical to the frozen policy.

## Suite summaries

```
Games: 150; draws: 0 (natural 0, turn cap 0)
Elite vs Script Kiddie (60 games): Elite 51 (85.0%), Kiddie 9 (15.0%)
Tournament played coverage (2026): 152/152; handlers: 152/152
Games: 150; draws: 0 (natural 0, turn cap 0)
Elite vs Script Kiddie (60 games): Elite 41 (68.3%), Kiddie 19 (31.7%)
Tournament played coverage (2025): 104/104; handlers: 152/152
Checks: 163166; failures: 0
Rules checks: 53 checks, 0 failures
v05 checks: 123 checks, 0 failures
v08 checks: 52 checks, 0 failures
v10 checks: 75 checks, 0 failures
V11 checks: 340 checks, 0 failures
Save checks: 1581 checks, 0 failures
Net checks: 13177 checks, 0 failures
Bot checks: 8; failures: 0
Bot benchmark failures: 0 (each pool, BENCH_GAMES=400)
```

`tests/rules_checks.gd` cannot be launched directly with `-s`: it extends RefCounted. The direct command was attempted and returned exit 1. Its scenarios pass both through sim.gd and the new rules_checks_runner.gd entrypoint.

## Full benchmark records

Fields: n, designated-side win rate/CI, draws, average turns, designated-side ms/turn, other-side ms/turn.

```
before ('2025', '2', '0') ('400', '49.2% [44.4, 54.1]', '0', '27.98', '1.275', '1.274')
before ('2025', '2', '1') ('400', '50.7% [45.9, 55.6]', '0', '28.20', '1.944', '3.591')
before ('2025', '2', '2') ('400', '45.5% [40.7, 50.4]', '11', '36.09', '6.041', '4.119')
before ('2025', '4', '0') ('400', '49.0% [44.1, 53.9]', '2', '41.71', '1.138', '1.138')
before ('2025', '4', '1') ('400', '53.5% [48.6, 58.3]', '4', '42.88', '2.004', '2.242')
before ('2025', '4', '2') ('400', '52.0% [47.1, 56.9]', '5', '47.26', '3.367', '3.337')
before ('2026', '2', '0') ('400', '50.2% [45.4, 55.1]', '0', '32.17', '1.349', '1.389')
before ('2026', '2', '1') ('400', '49.5% [44.6, 54.4]', '3', '32.05', '3.958', '2.801')
before ('2026', '2', '2') ('400', '48.8% [43.9, 53.6]', '18', '40.89', '12.412', '11.488')
before ('2026', '4', '0') ('400', '52.2% [47.4, 57.1]', '3', '46.90', '1.289', '1.217')
before ('2026', '4', '1') ('400', '51.5% [46.6, 56.4]', '2', '46.83', '1.930', '2.112')
before ('2026', '4', '2') ('400', '45.0% [40.2, 49.9]', '5', '49.64', '5.278', '3.674')
after ('2025', '2', '0') ('400', '49.2% [44.4, 54.1]', '0', '27.98', '1.239', '1.240')
after ('2025', '2', '1') ('400', '65.0% [60.2, 69.5]', '1', '26.42', '2.197', '4.657')
after ('2025', '2', '2') ('400', '69.2% [64.6, 73.6]', '4', '28.09', '4.501', '4.225')
after ('2025', '4', '0') ('400', '49.0% [44.1, 53.9]', '2', '41.71', '1.052', '1.049')
after ('2025', '4', '1') ('400', '54.2% [49.4, 59.1]', '0', '39.18', '1.535', '1.389')
after ('2025', '4', '2') ('400', '63.0% [58.2, 67.6]', '2', '42.62', '3.660', '3.267')
after ('2026', '2', '0') ('400', '50.2% [45.4, 55.1]', '0', '32.17', '1.264', '1.297')
after ('2026', '2', '1') ('400', '62.3% [57.4, 66.9]', '3', '30.70', '4.874', '2.797')
after ('2026', '2', '2') ('400', '64.0% [59.2, 68.6]', '7', '33.07', '12.600', '13.095')
after ('2026', '4', '0') ('400', '52.2% [47.4, 57.1]', '3', '46.90', '1.208', '1.139')
after ('2026', '4', '1') ('400', '57.8% [52.9, 62.5]', '2', '44.13', '1.850', '2.465')
after ('2026', '4', '2') ('400', '57.8% [52.9, 62.5]', '3', '47.26', '6.997', '3.421')
```

## 2026-11-11 — v0.21 reserve decisions

Method: Godot 4.7.1 headless with a fresh `XDG_DATA_HOME=$(mktemp -d)` for each batch. Frozen `scripts/ai/baseline/` was unchanged. Frequency: 100 all-bot games per pool/seat-count/level (1,200 total), seeds 820000–820099, rotating starting seat, 200 global-turn cap. Counts use `card_reserved`, `card_bought`, and every `turn_started` signal, including reaction turns. Signal counters live in Dictionaries. A later buy counts only for the reserving owner; delay is the number of that owner's actual turns, including reactions. “Never” includes cards unbought at the game end or cap. `RESERVE_GAMES`, `BENCH_POOL`, `BENCH_SEATS`, `BENCH_LEVEL`, and optional `RESERVE_TRACE=1` reproduce/filter the reusable script.

Strength: unchanged `tests/bot_bench.gd`, seeds 720000 onward, 400 games per two-seat row and 200 per four-seat row (3,600 total). New vs frozen at the same difficulty; starting seats rotate, and four-seat results group two new seats against two frozen seats. 95% Wilson intervals; draws are non-wins. These comparisons include the existing improvements over the historical frozen control, so the full win-rate advantage is not attributed to reserving alone.

Final rules:

- Elite: normal buy threshold 1.8. Save up for an unaffordable target worth at least 3.5 and at least 2.0 more than the best affordable buy, only when that buy is below 3.5. Block saving with lethal, any enemy at 8 life or less, or any enemy more than 4 life ahead. Save only through global turn 20 with two seats / 24 with four. Fallback reserves need value 3.0 and no buy reaching 1.8, through turn 16. Denial also ends at turn 16 and requires no buy reaching 1.8 plus at least 2.0 in public combo bonuses. Keep at most two wanted unbought reserves, except denial. Tips can enable a reserve after purchases.
- Phreak: before any acquisition, with no buy reaching 0.5, reserve the highest-value reachable card worth at least 3.0; hold at most one unbought reserve. No denial or save-up comparison. Stop after global turn 20 with two seats / 24 with four.
- Both use `min(estimate_hacking + 2, sum of the five highest printed Hacking amounts in own deck/discard/hand)` plus own persistent economy (Botnets squared, Payphone +2, Unattended Phone/Tableskirts +1). This uses composition, never deck order. Wanted reserved buys receive +2.0 priority without lowering the normal buy threshold. Denial uses opponents' public permanents/discard/reserve (Botnets, Fellowship, Never Gonna, 5ud0/Bitwize/crook3dfingers, Reps4Thor/nirtom, DeMartian/m8trix310).
- Script Kiddie: one 10% seeded-RNG roll per eligible turn, before any acquisition; select a random reservable row card. Unlimited reserve inventory; keep the existing priciest-affordable buying rule.
- A reservation breaks the action loop immediately, then ends the turn. Existing action and no-progress guards remain. Server bots and idle takeovers already share BotPlayer; focused tests verify engine `card_reserved`, client `reserved` events and normal “reserves” logs.

### Reserve frequency

Each row has 100 games. Delay is in owner turns.

| Pool | Seats | Level | Turns | Reserves | Per game | Games with reserve | Later bought | Never bought | Bought % | Delay | Capped games |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025 | 2 | Elite | 2719 | 227 | 2.27 | 93.0% | 186 | 41 | 81.9% | 2.54 | 0 |
| 2025 | 2 | Phreak | 2597 | 120 | 1.20 | 70.0% | 95 | 25 | 79.2% | 2.28 | 0 |
| 2025 | 2 | Script Kiddie | 2844 | 259 | 2.59 | 93.0% | 148 | 111 | 57.1% | 3.67 | 0 |
| 2025 | 4 | Elite | 4361 | 246 | 2.46 | 91.0% | 184 | 62 | 74.8% | 2.76 | 0 |
| 2025 | 4 | Phreak | 4038 | 171 | 1.71 | 80.0% | 125 | 46 | 73.1% | 2.63 | 0 |
| 2025 | 4 | Script Kiddie | 4137 | 393 | 3.93 | 99.0% | 187 | 206 | 47.6% | 3.07 | 0 |
| 2026 | 2 | Elite | 3422 | 212 | 2.12 | 83.0% | 173 | 39 | 81.6% | 3.09 | 2 |
| 2026 | 2 | Phreak | 2961 | 124 | 1.24 | 75.0% | 112 | 12 | 90.3% | 2.44 | 0 |
| 2026 | 2 | Script Kiddie | 3252 | 292 | 2.92 | 92.0% | 173 | 119 | 59.2% | 4.06 | 0 |
| 2026 | 4 | Elite | 4742 | 204 | 2.04 | 82.0% | 163 | 41 | 79.9% | 2.85 | 0 |
| 2026 | 4 | Phreak | 4557 | 171 | 1.71 | 85.0% | 129 | 42 | 75.4% | 2.50 | 1 |
| 2026 | 4 | Script Kiddie | 4818 | 461 | 4.61 | 100.0% | 221 | 240 | 47.9% | 3.23 | 0 |

Two-player frequency and follow-through targets are met in both pools. The remaining follow-through shortfall is four-seat 2025 Elite: 184/246 = 74.8%, 0.2 percentage points below 75%; intentional denial and fewer future owner turns can leave reservations unused. Earlier four-seat cutoffs improved this from 71.3% in the previous 100-game trial while retaining a 64.5% benchmark win rate. This is a reported shortfall, not a claim that further improvement is impossible. Phreak meets 70% in every row. Kiddie's four-seat totals (3.93 / 4.61 per game) exceed the rough 1–3 flavour target because the fixed 10% chance applies to each seat's turns; its two-seat frequency and all strength points are in range. Three frequency games hit the 200-turn cap (two 2026 two-seat Elite, one 2026 four-seat Phreak); their unbought cards remain in “Never”.

### Strength vs frozen control

| Pool | Seats | Level | Games | New win % [95% Wilson] | Draws | Mean turns | ms/new turn | ms/frozen turn |
|---|---:|---|---:|---|---:|---:|---:|---:|
| 2025 | 2 | Elite | 400 | 66.2% [61.5, 70.7] | 4 | 28.91 | 5.685 | 4.519 |
| 2025 | 2 | Phreak | 400 | 65.0% [60.2, 69.5] | 3 | 27.33 | 2.413 | 5.995 |
| 2025 | 2 | Script Kiddie | 400 | 46.5% [41.7, 51.4] | 1 | 28.02 | 1.328 | 1.328 |
| 2025 | 4 | Elite | 200 | 64.5% [57.7, 70.8] | 1 | 42.58 | 5.492 | 4.312 |
| 2025 | 4 | Phreak | 200 | 50.5% [43.6, 57.4] | 0 | 38.90 | 2.061 | 1.512 |
| 2025 | 4 | Script Kiddie | 200 | 45.5% [38.7, 52.4] | 1 | 41.90 | 1.215 | 1.179 |
| 2026 | 2 | Elite | 400 | 61.8% [56.9, 66.4] | 7 | 33.24 | 13.505 | 6.354 |
| 2026 | 2 | Phreak | 400 | 65.0% [60.2, 69.5] | 3 | 30.52 | 3.721 | 2.530 |
| 2026 | 2 | Script Kiddie | 400 | 48.5% [43.6, 53.4] | 0 | 32.48 | 1.493 | 1.509 |
| 2026 | 4 | Elite | 200 | 62.5% [55.6, 68.9] | 1 | 46.23 | 6.151 | 3.708 |
| 2026 | 4 | Phreak | 200 | 64.5% [57.7, 70.8] | 0 | 44.36 | 2.484 | 1.838 |
| 2026 | 4 | Script Kiddie | 200 | 47.0% [40.2, 53.9] | 0 | 48.19 | 1.313 | 1.305 |

All Elite and Phreak rows satisfy the requested strength criterion: point estimate at least 49%, with no Wilson interval entirely below 50%.

### Cross-level sanity


2026:

- Before: `Elite vs Script Kiddie (60 games): Elite 51 (85.0%), Kiddie 9 (15.0%)`
- After: `Elite vs Script Kiddie (60 games): Elite 54 (90.0%), Kiddie 6 (10.0%)`

2025:

- Before: `Elite vs Script Kiddie (60 games): Elite 41 (68.3%), Kiddie 19 (31.7%)`
- After: `Elite vs Script Kiddie (60 games): Elite 40 (66.7%), Kiddie 20 (33.3%)`

2026mog:

- Before: `Elite vs Script Kiddie (60 games): Elite 54 (90.0%), Kiddie 6 (10.0%)`
- After: `Elite vs Script Kiddie (60 games): Elite 54 (90.0%), Kiddie 6 (10.0%)`

### Validation

Each required suite was run as `timeout 1500 ~/.local/bin/godot4.7.1 --headless -s tests/<suite>.gd`. Summary lines:

```text
ui_smoke: UI smoke: 119 checks, 0 failures
touch_checks: Touch checks: 32 checks, 0 failures
v05_checks: v05 checks: 124 checks, 0 failures
v06_checks: v06 checks: 35 checks, 0 failures
v07_checks: v07 checks: 31 checks, 0 failures
v08_checks: v08 checks: 52 checks, 0 failures
v10_checks: v10 checks: 75 checks, 0 failures
v11_checks: V11 checks: 340 checks, 0 failures
v12_checks: v12 checks: 35 checks, 0 failures
v13_checks: V13 checks: 122 checks, 0 failures
v15_checks: v15 checks: 12816 checks, 0 failures
v16_checks: v16 checks: 122 checks, 0 failures
v17_checks: v17 checks: 383 checks, 0 failures
v18_checks: v18 checks: 68 checks, 0 failures
v20_checks: v20 checks: 494 checks, 0 failures
fuzz_checks: Fuzz checks: 59 checks, 0 failures (6000 malformed/foreign messages plus link-handler probes, seed 110011)
save_checks: Save checks: 1543 checks, 0 failures
ui_state_sync: UI state sync: 21717 checks, 0 failures
net_checks: Net checks: 15465 checks, 0 failures
online_ui_checks: Online UI checks: 79 checks, 0 failures
bot_checks: Bot checks: 39; failures: 0
rules_checks_runner: Rules checks: 109 checks, 0 failures
sim: Checks: 247031; failures: 0
Link checks: 0 checks, 0 failures (SKIPPED: sandbox cannot bind localhost TCP)
```

The v15 purchase-statistics reference counter previously counted only Center Row → discard movements. It now includes reserve → discard purchases too; the equality/reconciliation assertion remains. Online UI checks now stop the fake server, finish the game and drain pending decisions before deletion, with an added quiescence assertion. A changed bot trace exposed an offline guest prompt that the old teardown could abandon. No rule, conservation, strength, or fixed-game winner assertion was weakened. Focused bot checks cover save-up vs normal buying, lethal/pressure/late guards, public-only denial and inventory caps, later buying and buying priority, Phreak eligibility/cap, seeded Kiddie frequency/repeatability/acquisition guard, zero further acquire attempts after reserving, Elite Tips buy-then-reserve, and both server bot / idle takeover client events.

### Follow-up: stricter Elite save-up, and a like-for-like comparison

The tables above compare the new AI with the frozen control. Measured the same way on the same seeds
(400 two-player games), the AI *before* this change scored 69.2% (2025) and 64.0% (2026) at Elite, and
65.2% / 62.5% at Phreak. So the first version of reserving cost Elite about 2–3 points in two-player games
(66.2% / 61.8%), inside the confidence intervals but in the same direction on both pools; Phreak was unchanged or better.

The save-up rule was then tightened from `best < 3.5 and value >= max(3.5, best + 2.0)` to
`best < 2.5 and value >= max(3.5, best + 2.5)`: Elite only skips a turn's buys for a clearly better card
when the buy it gives up is weak.

| Pool | Seats | Elite before reserving work | First version | Final (stricter save-up) |
|---|---|---|---|---|
| 2025 | 2 | 69.2% [64.6, 73.6] | 66.2% [61.5, 70.7] | 67.5% [62.8, 71.9] |
| 2026 | 2 | 64.0% [59.2, 68.6] | 61.8% [56.9, 66.4] | 62.0% [57.2, 66.6] |

Final Elite reserve frequency (100 two-player games): 2025: 2.10 per game, 93% of games, 81.9% later bought;
2026: 1.89 per game, 80% of games, 84.7% later bought.


## DEFCON — 2026-11-12

DEFCON now has measured skill beyond Elite without its life handicap. Final
2025/2026 win rates are **65.25% / 58.25%**, each over 400 two-player games;
both Wilson lower bounds exceed 50%. With double life the results are
**91.50% / 79.25%**. **The 2026 double-life target of 90% was missed.**
No version was bumped and the pre-existing v0.21 changes were preserved.

### Training and policy selection

40,000 training games total: per pool, 8,000 Elite self-play games with 35%
random purchase exploration, then 8,000 self-play games using the first learned
policy with 25% exploration. Another 4,000 games per pool trained an alternating
double-life learner against fixed Elite with 35% exploration. Every randomized
purchase includes every affordable card and buying nothing. The game and
exploration RNGs are independent and reset per seed. The handicap experiments
supply a separate table selected using only whether our own starting life
exceeds the table base. They use no opponent-private features.

Features are card ID, own-turn phase (1–4, 5–9, 10+), and that own-life context.
Mog IDs resolve through CardDB's existing variant metadata to their originals.
There are no newly learned pair interactions. Elite's existing own/public
context terms remain in the heuristic prior. Per buyer/game/card/phase the
trainer records games, wins (draws count half), and signed outcome divided by
the square root of remaining own turns. Only randomized assignments enter the
fit: selected-card indicator minus the affordable-choice/stop mean, regressed
on `(win - 0.5) + 0.15 * tempo`. Ridge 40 shrinks adjustments toward zero, hence
toward Elite's heuristic for sparse cards. Fitting those choice contrasts
reduces the confounding from comparing raw purchases made in different positions.

The JSON stores all coefficients, statistics, seeds and counts. It loads once;
invalid/missing data silently produces zero adjustment, preserving Elite values.
The shipped normal coefficients use both iterations, with multipliers 2/1 for
2025/2026 on the scale-20 fit. Handicap coefficients use their separate fit,
multiplier 2. Re-fitting the saved shards reproduced every shipped coefficient.
Two independent four-game trainer runs also produced identical JSON.

Tuning used seeds 950000–950199. First-fit scale multipliers 0.5/1/2/4, second
iteration and combined-data fits, phase thresholds 1.8/1.8/1.8 versus
1.8/2.5/3.5 and 0/1.8/4, reserve margins 0/2.5/5, and late cheap-card penalties
0/2 were compared. The combined fit beat the second iteration alone in the
larger comparisons. Normal play retains thresholds 1.8/1.8/1.8, reserve margin
2.5 and no extra late filler penalty; learned late-phase scores supply the
card-specific rejection instead. Handicap tuning selected thresholds 0/0/0
versus 1.8/1.8/1.8 or 3/3/3, with margin 2.5 and filler penalty 0.
The complete screening results are in `tests/defcon_benchmark_results.json`.
Selection considered both the tuning and listed validation comparisons;
Wilson intervals below are descriptive and unadjusted for model selection.

### Two-player results

Each row is 400 games, seeds 930000–930399, alternating seats. Draws remain
in the denominator and do not count as wins. Life-off resets both current and
starting life to the common base, selecting the ordinary self-play table.
"Search off baseline" is the initial Elite fallback, before learned values and
DEFCON play improvements. "Final" has learned purchases, bounded exact lethal,
safe learned thinning, the draw-cycle guard and no live rollouts.

| Pool | Configuration | Life bonus | Wins / games | Win rate, Wilson 95% | Turn mean / worst ms |
|---|---|---|---|---|---|
| 2025 | Search off baseline | None | 187/400 | 46.75% [41.91, 51.65] | 11.807 / 97.010 |
| 2025 | Search off baseline | Double | 337/400 | 84.25% [80.36, 87.49] | 11.660 / 334.203 |
| 2026 | Search off baseline | None | 193/400 | 48.25% [43.39, 53.14] | 16.055 / 1744.597 |
| 2026 | Search off baseline | Double | 311/400 | 77.75% [73.42, 81.55] | 46.617 / 3504.842 |
| 2025 | Final | None | 261/400 | 65.25% [60.46, 69.75] | 8.821 / 119.324 |
| 2025 | Final | Double | 366/400 | 91.50% [88.36, 93.85] | 8.906 / 124.346 |
| 2026 | Final | None | 233/400 | 58.25% [53.36, 62.98] | 7.854 / 100.571 |
| 2026 | Final | Double | 317/400 | 79.25% [75.01, 82.94] | 9.695 / 107.448 |

The first selected learned policy, before policy iteration, scored 61.25%
[56.39, 65.90] / 56.75% [51.85, 61.52] without the bonus (400 per pool).
After both iterations the selected combined fit scored 65.25% / 58.25%.
For 2026, scaling the combined fit by four screened better at 200 games but
fell to 55.50% at 400; the multiplier-one fit was retained. The separate
handicap fit improved 2025 from 88.00% to 91.50%; 2026 changed from 79.00%
to 79.25%, a one-game difference and no convincing evidence of a handicap-policy
improvement in that pool. The latter remains well short of the requested 90%.

### Rollout decision, play safeguards and timing

Rollouts are **disabled by default** (`LIVE_ROLLOUTS = false`). The explicit
positive-count path remains for experiments and regression fixtures. A fresh
400-game-per-pool comparison with the final ordinary weights and runtime caps
showed that spending the budget on full rollouts sacrifices useful actions:

| Pool | Rollouts (count 1), no bonus | Wilson 95% | Turn mean / worst ms |
|---|---|---|---|
| 2025 | 142/400 (35.50%) | [30.97, 40.31] | 104.991 / 169.643 |
| 2026 | 126/400 (31.50%) | [27.14, 36.21] | 103.462 / 169.322 |

Consequently the retained search does not earn a live purchase or play-order
rollout slot. Exact lethal remains: at most six initial playable cards, 128
nodes, and a 40 ms wall deadline, with a printed-damage/known-bonus feasibility
check before cloning. Wall deadlines now apply to rollout count mode too.
The overall DEFCON turn allowance is 80 ms excluding UI pacing waits; checks
between complete rules actions allow an atomic action to finish. Search/server
decision budgets are 80 ms, with the exact tree using at most 40 ms. The older
300 ms search allowance remains an additional ceiling across repeated direct
search calls. No asynchronous pacing wait consumes the turn allowance.

A DEFCON-only guard stops repeatedly recycling a non-damaging card after three
plays of that identity, while allowing offensive cards to continue. This fixes
Brimstone/Oprah and Apache draw cycles that previously occupied the 200-action
limit and delayed acquisition. Learned thinning keeps the existing six-Hacking,
two-damage and Stamp protections and applies the same floors to low-valued
non-starters. Harmful player prompts prefer a killable target, otherwise the
highest strength computed from life and visible discard/permanents/reserve;
beneficial gifts retain Elite's beneficiary choice. Ordinary damage already
hits all opponents in these rules. Hidden hand/deck arrangements are never
used in this target strength. Sandboxes retain canonical hidden shuffles.

Final mean turns are all below 10 ms; the worst over the 1,600 live two-seat
validation games was **124.346 ms**, below 500 ms. These timings include rules
resolution in headless `take_turn`, not just score calculation, with animation
pacing disabled. Independent benchmark processes used separate data directories
and ran in parallel on this machine. They were measured under concurrent load.

### Four-seat and rules coverage

2025, one DEFCON seat versus three Elite, no life bonus, 400 games on seeds
960000–960399: **148/400 (37.00%, Wilson [32.41, 41.83])**,
versus the 25% equal-seat baseline. Draws: 2. Mean/worst DEFCON turn:
9.092/113.900 ms. All benchmark conservation checks passed.

The previous pass's real-play coverage top-up was already correct and is kept.
The sim now uses cheap bounded live DEFCON seats (two short games per pool).
Final sim: **230,067 checks, zero failures, 98.69 seconds**, including coverage
104/104 (2025), 152/152 (2026), and 152/152 (2026mog), with 157/157 handlers.
No coverage, rule or conservation requirement was reduced.

`tests/defcon_trace_hashes.json` records 27 complete state/RNG hashes captured
from the original working tree before shared changes: levels 0–2, all three
pools, seeds 77101–77103. All 27 still match. Additional checks cover full
normal/handicap weight coverage, actual Mog lookup, corrupt/missing fallback,
neutral and disagreeing purchase fixtures, thinning floors, exact-tree caps,
repeatability, draw-cycle termination, public target selection and server driving.
The DEFCON avatar is an original skull-and-crossbones drawing; UI test wording
now consistently calls it an avatar.

Reproduction commands: `tools/DEFCON_TRAINING.md`. Full aggregate and screening
measurements: `tests/defcon_benchmark_results.json`. Final suite summaries:

```text
ui_smoke: UI smoke: 119 checks, 0 failures
touch_checks: Touch checks: 32 checks, 0 failures
v05_checks: v05 checks: 124 checks, 0 failures
v06_checks: v06 checks: 35 checks, 0 failures
v07_checks: v07 checks: 31 checks, 0 failures
v08_checks: v08 checks: 52 checks, 0 failures
v10_checks: v10 checks: 76 checks, 0 failures
v11_checks: V11 checks: 340 checks, 0 failures
v12_checks: v12 checks: 35 checks, 0 failures
v13_checks: V13 checks: 122 checks, 0 failures
v15_checks: v15 checks: 12850 checks, 0 failures
v16_checks: v16 checks: 122 checks, 0 failures
v17_checks: v17 checks: 383 checks, 0 failures
v18_checks: v18 checks: 68 checks, 0 failures
v20_checks: v20 checks: 624 checks, 0 failures
v21_checks: v21 checks: 465 checks, 0 failures
fuzz_checks: Fuzz checks: 59 checks, 0 failures (6000 malformed/foreign messages plus link-handler probes, seed 110011)
save_checks: Save checks: 1602 checks, 0 failures
ui_state_sync: UI state sync: 21717 checks, 0 failures
net_checks: Net checks: 14195 checks, 0 failures
online_ui_checks: Online UI checks: 79 checks, 0 failures
bot_checks: Bot checks: 256; failures: 0
rules_checks_runner: Rules checks: 109 checks, 0 failures
sim: Checks: 230067; failures: 0
Link checks: 0 checks, 0 failures (SKIPPED: sandbox cannot bind localhost TCP)
node --test test/: tests 1; pass 1; fail 0
```

### Independent validation on untouched seeds

Re-run after the work above, 400 two-player games per row on seeds 1234000–1234399, which were used for
neither training, tuning nor the validation table (so these are free of selection effects):

| Pool | Life bonus | DEFCON wins vs Elite | Wilson 95% | Turn mean / worst ms |
|---|---|---|---|---|
| 2025 | None | 254/400 (63.5%) | [58.7, 68.1] | 6.7 / 96 |
| 2025 | Double | 347/400 (86.8%) | [83.1, 89.7] | 7.6 / 103 |
| 2026 | None | 225/400 (56.2%) | [51.4, 61.0] | 7.2 / 119 |
| 2026 | Double | 320/400 (80.0%) | [75.8, 83.6] | 8.3 / 114 |

Skill alone holds up (both lower bounds above 50%). With double life DEFCON beats Elite in 80–87% of games,
short of the 90% target on both pools.

## 2026-11-12 — Million-game DEFCON self-play (v0.22)
1,000,000 games of DEFCON against itself with double life in every seat and 25% random buys: 400k two-player, 300k three-player, 300k four-player, half on each card set (seeds 60,000,000–65,149,999). No conservation failures or errors; 1,135 games hit the 200-turn cap.

Card values fitted from the run were benchmarked against the shipped DEFCON at equal life (1,000 games per row, candidate in a rotating seat):

| Seats | Pool | Candidate win rate (95% Wilson) | Break-even |
|---|---|---|---|
| 2 | 2025 | 47.4% (44.3%–50.5%) | 50% |
| 2 | 2026 | 41.3% (38.3%–44.4%) | 50% |
| 4 | 2025 | 20.6% (18.2%–23.2%) | 25% |
| 4 | 2026 | 20.7% (18.3%–23.3%) | 25% |

Verdict: not better than shipped; `data/defcon_weights.json` is unchanged. Procedure: `tools/DEFCON_TRAINING.md`.
