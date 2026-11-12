#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
run_dir=$(realpath "${1:?usage: tools/defcon_selfplay_finish.sh run_dir}")
export OPENBLAS_NUM_THREADS=1
python3 tools/defcon_fit.py "$run_dir/shards/*.json" --output "$run_dir/selfplay_fit.json"
python3 tools/defcon_pack.py "$run_dir/selfplay_fit.json" "$run_dir/selfplay_fit.json" --output "$run_dir/candidate_weights.json"
exec python3 - "$run_dir" "$ROOT" <<'PY'
import concurrent.futures, json, math, os, pathlib, shutil, subprocess, sys, tempfile
run=pathlib.Path(sys.argv[1]); root=sys.argv[2]; n=int(os.environ.get('SP_FINISH_GAMES','1000')); four=int(os.environ.get('SP_FINISH_FOUR_GAMES',str(n)))
if min(n,four)<1: raise SystemExit('benchmark game counts must be positive')
plan=json.loads((run/'plan.json').read_text()); complete=0
for s in plan['shards']:
 try: complete+=json.loads((run/s['output']).read_text())['totals']['games']
 except (OSError,ValueError,KeyError): pass
jobs=[(seats,pool,n if seats==2 else four,int(os.environ.get('SP_FINISH_SEED','80000000'))+ci*100000) for ci,(seats,pool) in enumerate((s,p) for s in (2,4) for p in ('2025','2026'))]
# Replace historical packer provenance with the candidate's actual experiment.
candidate_path=run/'candidate_weights.json'
candidate=json.loads(candidate_path.read_text())
candidate['selection_seeds']=[]
candidate['validation_seeds']=[[seed,seed+count-1] for seats,pool,count,seed in jobs]
candidate['bonus_method']='All-DEFCON randomized self-play; N-seat centred contrasts; combined fit packed into both tables'
candidate['selection']['bonus']['source']='selfplay combined fit'
for pool in ('2025','2026'): candidate['selection'][pool]['source']='selfplay combined fit'
candidate['evaluation']='Pending finish_report.md; no automatic installation'
candidate_path.write_text(json.dumps(candidate,indent=1)+'\n')
def bench(job):
 seats,pool,count,seed=job; label=f'bench-{seats}p-{pool}'; td=tempfile.mkdtemp(prefix='defcon-finish-')
 env=os.environ.copy(); env.update(XDG_DATA_HOME=td,DEFCON_GAMES=str(count),DEFCON_SEED=str(seed),DEFCON_SEATS=str(seats),DEFCON_POOL=pool,DEFCON_BONUS='0',DEFCON_OPPONENT='3',DEFCON_WEIGHTS=str(run/'candidate_weights.json'),DEFCON_OPPONENT_WEIGHTS=str(pathlib.Path(root)/'data/defcon_weights.json'),DEFCON_OUT=str(run/f'{label}.json'))
 # Default live DEFCON behavior; no rollout override inherited from training.
 env.pop('DEFCON_COUNT',None)
 try:
  with (run/f'{label}.log').open('w') as log:
   subprocess.run([os.environ.get('GODOT',os.path.expanduser('~/.local/bin/godot4.7.1')),'--headless','--path',root,'-s','tests/defcon_bench.gd'],env=env,stdout=log,stderr=log,check=True)
  data=json.loads((run/f'{label}.json').read_text())
  if data['failures']: raise RuntimeError('Conservation failure in '+label)
  return data
 finally: shutil.rmtree(td,ignore_errors=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex: results=list(ex.map(bench,jobs))
def wilson(w,n):
 z=1.96; d=1+z*z/n; c=(w/n+z*z/(2*n))/d; h=z*math.sqrt(w/n*(1-w/n)/n+z*z/(4*n*n))/d
 return c-h,c+h
lines=['# Candidate evaluation','',f'Trained on {complete:,} / {plan["games"]:,} planned games. Candidate weights remain in this run directory.', '', 'Candidate occupies a rotating seat against shipped DEFCON, with equal base life for every seat. Each pool uses fresh paired seat schedules; 4P faces three shipped opponents. Live policy is used, without exploration.', '', '| Seats | Pool | Games | Wins | Draws | Win rate (95% Wilson) |','|---|---|---:|---:|---:|---|']
better=True
for d in results:
 lo,hi=wilson(d['wins'],d['games']); rate=d['wins']/d['games']
 lines.append(f'| {d["seats"]} | {d["pool"]} | {d["games"]:,} | {d["wins"]:,} | {d["draws"]:,} | {rate:.1%} ({lo:.1%}–{hi:.1%}) |')
 if d['seats']==2 and lo<=.5: better=False
 if d['seats']==4 and hi<.25: better=False
verdict='candidate is better than shipped' if better else 'candidate is not better than shipped'
lines+=['',f'Verdict: **{verdict}**.', '', 'Rule: lower 95% Wilson bound must exceed 50% in BOTH 2P pools, and neither 4P upper bound may fall below 25%. Draws count as non-wins in this conservative test. A not-better result includes insufficient evidence; it does not establish equivalence. No weights are installed.', '', 'The same self-play fit is packed into normal and handicap tables using the existing packer multipliers. This is a candidate for validation, not a claim that mixed-seat training is optimal for either regime.']
(run/'finish_report.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
PY
