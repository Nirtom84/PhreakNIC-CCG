#!/usr/bin/env python3
"""Fit randomized affordable-choice contrasts, ridge shrinkage to Elite (zero).
Only exploration assignments contribute to the fit; per-buyer/card/phase outcome
statistics include all purchases. Seed-disjoint benchmarks select scale/knobs.
"""
import argparse, glob, json
from pathlib import Path
import numpy as np
p = argparse.ArgumentParser()
p.add_argument('inputs', nargs='+')
p.add_argument('--output', default='data/defcon_weights.json')
p.add_argument('--scale', type=float, default=20)
p.add_argument('--ridge', type=float, default=40)
a = p.parse_args()
files = sorted(set(f for pattern in a.inputs for f in glob.glob(pattern)))
if not files: p.error('No training files matched')
cards = json.loads(Path('data/cards.json').read_text())
result = {'method': 'randomized affordable-choice contrasts; ridge toward Elite', 'scale': a.scale, 'ridge': a.ridge, 'pools': {}, 'statistics': {}, 'training': []}
for pool in ['2025', '2026']:
 ids = [c['id'] for c in cards if not c['starter'] and (pool == '2026' or c.get('set', '2025') == '2025')]
 ids.append('__stop__')
 index = {id: i for i, id in enumerate(ids)}
 n = len(ids)
 matrices = [np.eye(n) * a.ridge for _ in range(3)]
 targets = [np.zeros(n) for _ in range(3)]
 stats = {}
 count = 0
 for f in files:
  data = json.loads(Path(f).read_text())
  if data['pool'] != pool: continue
  result['training'].append({k: data[k] for k in ['pool', 'iteration', 'seed', 'games', 'epsilon']})
  for k, v in data['stats'].items():
   dest = stats.setdefault(k, {'games': 0, 'wins': 0, 'tempo': 0})
   for metric in dest: dest[metric] += v[metric]
  for id, phase, options, win, tempo in data['samples']:
   if id not in index: continue
   options = [x for x in options if x in index] + ['__stop__']
   x = np.zeros(n)
   for option in options: x[index[option]] -= 1 / len(options)
   x[index[id]] += 1
   matrices[phase] += np.outer(x, x)
   targets[phase] += x * ((win - .5) + .15 * tempo)
   count += 1
 if count == 0: raise ValueError(f'No randomized samples for {pool}')
 coefficients = [np.linalg.solve(m, y) for m, y in zip(matrices, targets)]
 result['pools'][pool] = {id: [round(float(np.clip(c[index[id]] * a.scale, -8, 8)), 5) for c in coefficients] for id in ids}
 result['statistics'][pool] = stats
 print(pool, 'randomized samples', count, 'games', sum(t['games'] for t in result['training'] if t['pool'] == pool))
Path(a.output).write_text(json.dumps(result, indent=1) + '\n')
