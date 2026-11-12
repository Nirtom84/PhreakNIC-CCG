#!/usr/bin/env bash
# Detached-safe, resumable bounded pool. STOP prevents new work; running shards finish.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
run_dir=$(realpath -m "${1:?usage: tools/defcon_selfplay.sh run_dir [workers=24]}")
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
 base=60000000 if scale==1 else 70000000
 configs=[(s,p,200000 if s==2 else 150000) for s in (2,3,4) for p in ('2025','2026')]
 groups=[]
 for ci,(seats,pool,n) in enumerate(configs):
  total=int(Decimal(n)*scale); group=[]
  for offset in range(0,total,size):
   key=f'{seats}p-{pool}-{offset:06d}'
   group.append(dict(id=key,seats=seats,pool=pool,seed=base+ci*1000000+offset,games=min(size,total-offset),output=f'shards/{key}.json'))
  groups.append(group)
 shards=[g[i] for i in range(max(map(len,groups))) for g in groups if i<len(g)]
 weights=pathlib.Path(os.environ.get('SP_WEIGHTS',str(pathlib.Path(root)/'data/defcon_weights.json'))).resolve()
 shutil.copyfile(weights,run/'training_weights.json')
 plan=dict(format='selfplay-plan-v1',weights='training_weights.json',games=sum(x['games'] for x in shards),epsilon=float(os.environ.get('SP_EPSILON','.25')),shards=shards)
 # Atomic exclusive publication: a killed writer cannot leave a partial plan.
 plan_temp=run/'plan.json.tmp'
 plan_temp.write_text(json.dumps(plan,indent=2))
 os.link(plan_temp,plan_path)
 plan_temp.unlink()
plan=json.loads(plan_path.read_text())
def complete(s):
 try:
  d=json.loads((run/s['output']).read_text())
  return d['format']=='selfplay-v1' and d['games']==s['games'] and d['totals']['games']==s['games'] and d['seed']==s['seed']
 except (OSError,ValueError,KeyError,TypeError): return False
def worker(s):
 if (run/'STOP').exists(): return 'stopped'
 if complete(s): return 'skipped'
 td=tempfile.mkdtemp(prefix='defcon-worker-')
 env=os.environ.copy(); env.update(XDG_DATA_HOME=td,SP_SEATS=str(s['seats']),SP_POOL=s['pool'],SP_SEED=str(s['seed']),SP_GAMES=str(s['games']),SP_EPSILON=str(plan['epsilon']),SP_OUT=str(run/s['output']))
 if plan.get('weights'): env['SP_WEIGHTS']=str(run/plan['weights'])
 try:
  with (run/'logs'/f"{s['id']}.log").open('w') as log:
   result=subprocess.run(['nice','-n','10',os.environ.get('GODOT',os.path.expanduser('~/.local/bin/godot4.7.1')),'--headless','--path',root,'-s','tests/defcon_selfplay.gd'],env=env,stdout=log,stderr=log)
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
