#!/usr/bin/env python3
"""Run candidate-v-prior and difficulty ordering on seed-disjoint custom games."""
import concurrent.futures,json,math,os,shutil,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
run=Path(os.environ.get('CB_RUN',tempfile.mkdtemp(prefix='custom-bench-'))).resolve();run.mkdir(parents=True,exist_ok=True)
games=int(os.environ.get('CB_GAMES','1000'))
seed_base=int(os.environ.get('CB_SEED','89000000'))
if seed_base < 89000000: raise SystemExit('CB_SEED must be at least 89000000')
weights=Path(os.environ.get('CB_WEIGHTS',root/'data/custom_deck_weights.json')).resolve()
if not 1 <= games <= 100000: raise SystemExit('CB_GAMES must be in 1..100000')
def worker(config):
 index,seats,ordering=config
 td=tempfile.mkdtemp(prefix='custom-bench-data-')
 out=run/f'{seats}p-{"ordering" if ordering else "candidate"}.json'
 env=os.environ.copy();env.update(XDG_DATA_HOME=td,XDG_CONFIG_HOME=str(Path(td)/'config'),XDG_CACHE_HOME=str(Path(td)/'cache'),SP_GAMES=str(games),SP_SEATS=str(seats),SP_SEED=str(seed_base+index*100000),SP_OFFSET='0',SP_OUT=str(out),SP_WEIGHTS=str(weights),CB_ORDERING=str(int(ordering)))
 # Never inherit a training plan or exploration setting accidentally.
 env.pop('SP_PLAN',None)
 try:
  with out.with_suffix('.log').open('w') as log:
   result=subprocess.run(['nice','-n','10',os.environ.get('GODOT',str(Path.home()/'.local/bin/godot4.7.1')),'--headless','--path',str(root),'-s','tests/custom_bench.gd'],env=env,stdout=log,stderr=log)
  if result.returncode: raise RuntimeError(f'Benchmark failed: {out.with_suffix(".log")}')
  return json.loads(out.read_text())
 finally: shutil.rmtree(td,ignore_errors=True)
def wilson(w,n):
 z=1.959964;p=w/n;den=1+z*z/n;half=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den;mid=(p+z*z/(2*n))/den
 return [mid-half,mid+half]
configs=[(0,2,False),(1,4,False),(2,2,True),(3,4,True)]
if os.environ.get('CB_REPORT_ONLY')=='1':
 results=[json.loads((run/f'{seats}p-{"ordering" if ordering else "candidate"}.json').read_text()) for _,seats,ordering in configs]
else:
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: results=list(pool.map(worker,configs))
summary={'candidate':{},'ordering':{},'adjacent_pairs':{},'ordering_weights':{},'candidate_weights':str(weights)}
for (_,seats,ordering),d in zip(configs,results):
 if ordering:
  summary['ordering'][str(seats)]=d['levels']
  summary['ordering_weights'][str(seats)]=d.get('weights',str(weights))
  if seats==2: summary['adjacent_pairs']=d['matchups']
 else:
  n=d['games'];w=d['totals']['candidate_wins'];ci=wilson(w,n)
  summary['candidate'][str(seats)]={'games':n,'wins':w,'rate':w/n,'wilson95':ci,'significant':ci[0]>1/seats,'draws':d['totals']['draws'],'errors':d['totals']['errors']}
summary['ship']=all(x['significant'] and not x['errors'] for x in summary['candidate'].values())
summary['ordering_pass']={}
for seats,levels in summary['ordering'].items():
 rates=[levels.get(f'{seats}P/{i}',{}).get('wins',0)/max(1,levels.get(f'{seats}P/{i}',{}).get('seats',0)) for i in range(4)]
 summary['ordering_pass'][seats]=all(a<b for a,b in zip(rates,rates[1:])) if seats=='4' else (len(summary['adjacent_pairs'])==3 and all(v['higher_wins']>v['lower_wins'] for v in summary['adjacent_pairs'].values()))
summary['ship'] &= all(summary['ordering_pass'].values()) and all(v==str(weights) for v in summary['ordering_weights'].values())
path=run/'report.json';temp=path.with_suffix('.tmp');temp.write_text(json.dumps(summary,indent=1)+'\n');temp.replace(path)
print(json.dumps(summary,indent=1));print('Artifacts:',run)
