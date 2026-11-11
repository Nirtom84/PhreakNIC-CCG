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
