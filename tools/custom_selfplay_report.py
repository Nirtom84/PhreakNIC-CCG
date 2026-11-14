#!/usr/bin/env python3
"""Report completed planned custom shards (including partial runs)."""
import argparse,json
from pathlib import Path

def add(a,b):
 for k,v in b.items():
  if isinstance(v,dict): add(a.setdefault(k,{}),v)
  elif isinstance(v,(int,float)): a[k]=a.get(k,0)+v

def main():
 p=argparse.ArgumentParser();p.add_argument('run_dir',type=Path);a=p.parse_args();run=a.run_dir
 plan=json.loads((run/'plan.json').read_text()); out=dict(totals={},decks={},levels={},configurations={},error_seeds=[],worker_seconds=0,bytes=0)
 for s in plan['shards']:
  try:
   path=run/s['output'];d=json.loads(path.read_text())
   if d['format']!='custom-selfplay-v1' or d['seed']!=s['seed'] or d['totals']['games']!=s['games']: continue
  except (OSError,ValueError,KeyError,TypeError): continue
  for field in ['totals','decks','levels']: add(out[field],d[field])
  add(out['configurations'].setdefault(str(s['seats']),{}),d['totals'])
  out['error_seeds']+=d['error_seeds'];out['worker_seconds']+=d['wall_seconds'];out['bytes']+=path.stat().st_size
 n=out['totals'].get('games',0); t=out['totals']; rate=n/max(.001,out['worker_seconds'])
 eta=f'{1000000/rate/24/3600:.2f} hours' if rate else 'unknown (no finished games)'
 lines=[f'custom selfplay: {n}/{plan["games"]} games',str(t),f'worker games/s {rate:.3f}; estimated 1M at 24 workers {eta}',f'bytes/1000 games {out["bytes"]*1000/max(1,n):.0f}',f'first-seat win rate {t.get("first_wins",0)/max(1,n):.2%}; mean turns {t.get("turns",0)/max(1,n):.2f}',f'error seeds {out["error_seeds"]}']
 for seats,c in sorted(out['configurations'].items()):
  rate_first=c['first_wins']/max(1,c['games'])
  lines.append(f"{seats}P: {c['games']} games, first-seat wins {rate_first:.2%} (advantage {rate_first-1/int(seats):+.2%} vs equal seats), mean turns {c['turns']/max(1,c['games']):.2f}, draws {c['draws']}, cap draws {c['turn_caps']}")
 for name,d in sorted(out['decks'].items()):
  d['average_turns']=d['turns']/max(1,d['games'])
  for level,stats in d['levels'].items(): stats['win_rate']=stats['wins']/max(1,stats['seats'])
  rates=', '.join(f"{key}: {v['wins']}/{v['seats']} ({v['win_rate']:.1%})" for key,v in sorted(d['levels'].items()))
  lines.append(f"{name}: games={d['games']}, mean turns={d['average_turns']:.2f}, draws={d['draws']}, errors={d['errors']}; {rates}")
 for filename,text in [('summary.json',json.dumps(out,indent=1)+'\n'),('summary.txt','\n'.join(lines)+'\n')]:
  tmp=run/(filename+'.tmp');tmp.write_text(text);tmp.replace(run/filename)
 print('\n'.join(lines))
if __name__=='__main__':main()
