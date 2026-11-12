#!/usr/bin/env python3
"""Aggregate seed-disjoint defcon_bench DEFCON_OUT files, including Wilson CI."""
import argparse, collections, glob, json, math
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('inputs', nargs='+')
a = p.parse_args()
groups = collections.defaultdict(list)
for pattern in a.inputs:
 for f in glob.glob(pattern):
  d = json.loads(Path(f).read_text())
  groups[(d['pool'], d['seats'], d['bonus'])].append(d)
for (pool, seats, bonus), rows in sorted(groups.items()):
 n = sum(r['games'] for r in rows)
 w = sum(r['wins'] for r in rows)
 rate = w / n
 den = 1 + 1.96**2 / n
 center = (rate + 1.96**2 / (2*n)) / den
 half = 1.96 * math.sqrt(rate*(1-rate)/n + 1.96**2/(4*n*n)) / den
 turns = sum(r['turns'] for r in rows)
 mean = sum(r['total_ms'] for r in rows) / max(1, turns)
 worst = max(r['worst_ms'] for r in rows)
 print(f'{pool} seats={seats} bonus={bonus} {w}/{n}: {100*rate:.2f}% [{100*(center-half):.2f}, {100*(center+half):.2f}], draws={sum(r["draws"] for r in rows)}, turn mean/worst={mean:.3f}/{worst:.3f} ms; failures={sum(r["failures"] for r in rows)}')
