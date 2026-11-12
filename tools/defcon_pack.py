#!/usr/bin/env python3
"""Pack the benchmark-selected normal and handicap fits into runtime tables."""
import argparse, json
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('normal_fit', help='defcon_fit.py output from both self-play iterations')
p.add_argument('bonus_fit', help='defcon_fit.py output from handicap purchase experiments')
p.add_argument('--output', default='data/defcon_weights.json')
a = p.parse_args()
x = json.loads(Path(a.normal_fit).read_text())
b = json.loads(Path(a.bonus_fit).read_text())
for pool, multiplier in [('2025', 2), ('2026', 1)]:
 for id, values in x['pools'][pool].items():
  x['pools'][pool][id] = [round(v * multiplier, 5) for v in values]
x['bonus_pools'] = {pool: {id: [round(v * 2, 5) for v in values] for id, values in table.items()} for pool, table in b['pools'].items()}
x['date'] = '2026-11-12'
x['settings'] = {'threshold': [1.8]*3, 'reserve_margin': 2.5, 'late_filler': 0.0,
 'bonus': {pool: {'threshold': [0]*3, 'reserve_margin': 2.5, 'late_filler': 0.0} for pool in ['2025', '2026']}}
x['features'] = ['card id', 'own turns: 1-4 / 5-9 / 10+', 'own starting life exceeds table base: selects separately trained handicap values']
x['selection_seeds'] = [950000, 950199]
x['validation_seeds'] = [930000, 930399]
x['selection'] = {'2025': {'source': 'combined', 'scale_multiplier': 2}, '2026': {'source': 'combined', 'scale_multiplier': 1}, 'bonus': {'source': 'bonus', 'scale_multiplier': 2, 'threshold': [0]*3}}
x['bonus_statistics'] = b['statistics']
x['bonus_training'] = b['training']
x['bonus_method'] = 'Randomized purchase experiments by a double-life learner against fixed Elite; alternating seats; 4000 games per pool'
Path(a.output).write_text(json.dumps(x, indent=1) + '\n')
