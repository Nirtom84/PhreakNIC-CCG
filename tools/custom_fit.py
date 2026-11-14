#!/usr/bin/env python3
"""Merge sufficient statistics and ridge toward the text-based prior."""
import argparse, json, os
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('run_dir',type=Path); p.add_argument('--output',required=True,type=Path)
p.add_argument('--ridge',type=float,default=40); p.add_argument('--scale',type=float,default=20)
a=p.parse_args()
if a.ridge <= 0: p.error('ridge must be positive')
plan=json.loads((a.run_dir/'plan.json').read_text())
shards=[]
for s in plan['shards']:
 try:
  d=json.loads((a.run_dir/s['output']).read_text())
  if d['format']=='custom-selfplay-v1' and d['seed']==s['seed'] and d['totals']['games']==s['games']: shards.append(d)
 except (OSError,ValueError,KeyError,TypeError): pass
ids=sorted({k for d in shards for f in d['fit'] for k in f['xy']}); index={k:i for i,k in enumerate(ids)}
if not ids: p.error('No randomized samples in completed shards')
coeff=[]
for phase in range(3):
 xx=np.eye(len(ids))*a.ridge; xy=np.zeros(len(ids))
 for d in shards:
  f=d['fit'][phase]
  for k,v in f['xy'].items(): xy[index[k]]+=v
  for k,row in f['xx'].items():
   for j,v in row.items(): xx[index[k],index[j]]+=v
 coeff.append(np.linalg.solve(xx,xy)*a.scale)
starting=json.loads((a.run_dir/plan['weights']).read_text()).get('adjustments',{})
adjustments=dict(starting)
for k,i in index.items():
 if k!='__stop__': adjustments[k]=[round(float(np.clip(starting.get(k,[0,0,0])[j]+coeff[j][i]-coeff[j][index.get('__stop__',i)],-8,8)),6) for j in range(3)]
result=dict(format='custom-weights-v1',adjustments=adjustments,metadata=dict(method='randomized choice contrasts; ridge toward starting prior',ridge=a.ridge,games=sum(d['games'] for d in shards),samples=sum(f['count'] for d in shards for f in d['fit'])))
temp=a.output.with_suffix(a.output.suffix+'.tmp'); temp.write_text(json.dumps(result,indent=1)+'\n'); temp.replace(a.output)
print('custom fit:',result['metadata'])
