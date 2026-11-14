#!/usr/bin/env bash
# Detached-safe, resumable bounded pool. STOP prevents new work; running shards finish.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
run_dir=$(realpath -m "${1:?usage: tools/custom_selfplay.sh run_dir [workers=24]}")
workers=${2:-24}
mkdir -p "$run_dir/shards" "$run_dir/logs"
# Python owns scheduling so STOP is checked immediately before every launch.
exec python3 - "$run_dir" "$workers" "$ROOT" <<'PY'
import concurrent.futures, json, os, pathlib, shutil, subprocess, sys, tempfile
from decimal import Decimal
run=pathlib.Path(sys.argv[1]); workers=int(sys.argv[2]); root=sys.argv[3]
if workers < 1: raise SystemExit('workers must be positive')
plan_path=run/'plan.json'
if not plan_path.exists():
 scale=Decimal(os.environ.get('SP_PLAN_SCALE','1'))
 if not 0 < scale <= 1: raise SystemExit('SP_PLAN_SCALE must be in (0,1]')
 size=int(os.environ.get('SP_SHARD_SIZE','50' if scale != 1 else '2000'))
 if size < 1: raise SystemExit('SP_SHARD_SIZE must be positive')
 configs=[(seats,n) for seats,n in [(2,400000),(3,300000),(4,300000)]]
 groups=[]
 for ci,(seats,n) in enumerate(configs):
  total=int(Decimal(n)*scale); group=[]
  for offset in range(0,total,size):
   key=f'{seats}p-{offset:06d}'
   group.append(dict(id=key,seats=seats,offset=offset,seed=81000000+ci*1000000+offset,games=min(size,total-offset),output=f'shards/{key}.json'))
  groups.append(group)
 shards=[g[i] for i in range(max(map(len,groups),default=0)) for g in groups if i<len(g)]
 decks=[]
 for path in sorted((pathlib.Path(root)/'decks/custom').glob('*.phreakdeck.json')):
  decks.append(json.loads(path.read_text())['code'])
 if not decks:
  # Snapshot validated codes via Godot, including the starter fallback.
  td=tempfile.mkdtemp(prefix='custom-snapshot-')
  try:
   snapshot=run/'decks.json'
   env=os.environ.copy(); env.update(XDG_DATA_HOME=td,XDG_CONFIG_HOME=str(pathlib.Path(td)/'config'),XDG_CACHE_HOME=str(pathlib.Path(td)/'cache'),CB_DECK_OUT=str(snapshot))
   subprocess.run([os.environ.get('GODOT',os.path.expanduser('~/.local/bin/godot4.7.1')),'--headless','--path',root,'-s','tools/custom_snapshot.gd'],env=env,check=True)
   decks=json.loads(snapshot.read_text()); snapshot.unlink()
  finally: shutil.rmtree(td,ignore_errors=True)
 weights=pathlib.Path(os.environ.get('SP_WEIGHTS',str(pathlib.Path(root)/'data/custom_deck_weights.json'))).resolve()
 shutil.copyfile(weights,run/'training_weights.json')
 plan=dict(format='selfplay-plan-v1',weights='training_weights.json',games=sum(x['games'] for x in shards),epsilon=.25,decks=decks,shards=shards)
 # Atomic exclusive publication: a killed writer cannot leave a partial plan.
 plan_temp=run/'plan.json.tmp'
 plan_temp.write_text(json.dumps(plan,indent=2))
 os.link(plan_temp,plan_path)
 plan_temp.unlink()
plan=json.loads(plan_path.read_text())
def complete(s):
 try:
  d=json.loads((run/s['output']).read_text())
  return d['format']=='custom-selfplay-v1' and d['games']==s['games'] and d['totals']['games']==s['games'] and d['seed']==s['seed']
 except (OSError,ValueError,KeyError,TypeError): return False
def worker(s):
 if (run/'STOP').exists(): return 'stopped'
 if complete(s): return 'skipped'
 td=tempfile.mkdtemp(prefix='custom-worker-')
 env=os.environ.copy(); env.update(XDG_DATA_HOME=td,XDG_CONFIG_HOME=str(pathlib.Path(td)/'config'),XDG_CACHE_HOME=str(pathlib.Path(td)/'cache'),SP_SEATS=str(s['seats']),SP_OFFSET=str(s['offset']),SP_PLAN=str(plan_path),SP_SEED=str(s['seed']),SP_GAMES=str(s['games']),SP_EPSILON=str(plan['epsilon']),SP_OUT=str(run/s['output']))
 if plan.get('weights'): env['SP_WEIGHTS']=str(run/plan['weights'])
 env.pop('CB_BENCH',None); env.pop('CB_ORDERING',None)
 try:
  with (run/'logs'/f"{s['id']}.log").open('w') as log:
   result=subprocess.run(['nice','-n','10',os.environ.get('GODOT',os.path.expanduser('~/.local/bin/godot4.7.1')),'--headless','--path',root,'-s','tests/custom_selfplay.gd'],env=env,stdout=log,stderr=log)
  return 'done' if result.returncode==0 and complete(s) else 'FAILED'
 finally: shutil.rmtree(td,ignore_errors=True)
pending=[s for s in plan['shards'] if not complete(s)]
print(f"Plan {plan['games']:,} games; skipped {len(plan['shards'])-len(pending)} finished shards; pending {len(pending)}",flush=True)
failed=False
with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
 active={}; iterator=iter(pending)
 def fill():
  while len(active)<workers and not (run/'STOP').exists():
   s=next(iterator,None)
   if s is None: break
   active[executor.submit(worker,s)]=s
 fill()
 while active:
  done,_=concurrent.futures.wait(active,return_when=concurrent.futures.FIRST_COMPLETED)
  for f in done:
   s=active.pop(f); status=f.result(); print(s['id'],status,flush=True); failed |= status=='FAILED'
  fill()
if (run/'STOP').exists(): print('Stopped: remove STOP and rerun to resume.',flush=True)
raise SystemExit(1 if failed else 0)
PY
