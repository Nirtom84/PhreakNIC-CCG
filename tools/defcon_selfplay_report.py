#!/usr/bin/env python3
"""Merge completed self-play shards and render a shareable progress card."""
import argparse
import json
import math
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['Nirtom', 'Reps4Thor', 'Bitwize', '5ud0']
IDS = ['nirtom', 'Reps4Thor', 'Bitwize', '5ud0']
MIN_RECORDS = {'fastest_win', 'comeback'}

def add(dest, source):
    for k, v in source.items():
        if isinstance(v, dict):
            add(dest.setdefault(k, {}), v)
        elif isinstance(v, (float, int)):
            dest[k] = dest.get(k, 0) + v

def atomic(path, text):
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(text)
    temp.replace(path)

def merge(run):
    plan = json.loads((run / 'plan.json').read_text())
    summary = dict(people={}, cards={}, records={}, totals={}, configurations={},
                   eliminations=[[0]*4 for _ in range(4)], failure_seeds=[], cap_seeds=[], error_seeds=[])
    walls = 0
    finished = 0
    for shard in plan['shards']:
        key = f"{shard['seats']}P/{shard['pool']}"
        config = summary['configurations'].setdefault(key, dict(planned=0, done=0, wall_seconds=0, people={}))
        config['planned'] += shard['games']
        try:
            d = json.loads((run / shard['output']).read_text())
            if d.get('format') != 'selfplay-v1' or d['totals']['games'] != shard['games'] or d['seed'] != shard['seed']:
                continue
        except (OSError, ValueError, KeyError, TypeError):
            continue
        finished += 1
        walls += d['wall_seconds']
        config['done'] += d['games']
        config['wall_seconds'] += d['wall_seconds']
        add(config['people'], d['people'])
        for field in ('people', 'cards', 'totals'):
            add(summary[field], d[field])
        for field in ('failure_seeds', 'cap_seeds', 'error_seeds'):
            summary[field].extend(d[field])
        for i, row in enumerate(d['eliminations']):
            for j, value in enumerate(row): summary['eliminations'][i][j] += value
        for name, record in d['records'].items():
            old = summary['records'].get(name)
            if old is None or (record['value'] < old['value'] if name in MIN_RECORDS else record['value'] > old['value']):
                summary['records'][name] = record
    games = summary['totals'].get('games', 0)
    # Sum shard runtimes is worker time, not elapsed run time. Report both explicitly.
    remaining_worker_seconds = 0
    unknown = False
    for c in summary['configurations'].values():
        c['games_per_second'] = c['done']/c['wall_seconds'] if c['wall_seconds'] else None
        if c['done']:
            remaining_worker_seconds += (c['planned']-c['done']) / c['games_per_second']
        elif c['planned']: unknown = True
    summary['progress'] = dict(games_done=games, games_planned=plan['games'],
        shards_done=finished, shards_planned=len(plan['shards']),
        worker_wall_seconds=walls, games_per_worker_hour=games*3600/walls if walls else 0,
        estimated_remaining_worker_hours=None if unknown else remaining_worker_seconds/3600,
        estimated_remaining_hours_at_24_workers=None if unknown else remaining_worker_seconds/3600/24,
        epsilon=plan.get('epsilon', .25))
    return summary

def render(run, s):
    bg, cyan, green, amber, red, muted = '#05090d','#29e6ff','#6dff9a','#f2c14e','#ff3b3b','#9fb3bd'
    image = Image.new('RGB', (1200,630), bg)
    draw = ImageDraw.Draw(image)
    for x in range(0,1200,30): draw.line((x,0,x,630),fill='#0b1920')
    for y in range(0,630,30): draw.line((0,y,1200,y),fill='#0b1920')
    draw.rounded_rectangle((12,12,1187,617), radius=12, outline=cyan, width=2)
    def font(size, bold=False):
        return ImageFont.truetype(str(ROOT/'assets/fonts'/('JetBrainsMonoNerdFontMono-Bold.ttf' if bold else 'JetBrainsMonoNerdFontMono-Regular.ttf')),size)
    def text(x,y,value,size=16,color=muted,bold=False,maxwidth=None):
        f=font(size,bold)
        if maxwidth:
            while draw.textlength(value,font=f)>maxwidth and len(value)>1: value=value[:-2]+'…'
        draw.text((x,y),value,font=f,fill=color)
    def center(x,y,value,size=16,color=muted,bold=False):
        f=font(size,bold); draw.text((x-draw.textlength(value,font=f)/2,y),value,font=f,fill=color)
    project=(ROOT/'project.godot').read_text()
    match=re.search(r'config/version="([^"]+)"',project)
    version=match.group(1) if match else '?'
    p=s['progress']; done=p['games_done']; planned=p['games_planned']
    text(36,27,'DEFCON vs DEFCON',34,cyan,True)
    text(36,75,f'{done:,}'+(f' of {planned:,}' if done<planned else '')+' games of self-play',18,green)
    text(850,40,f'PhreakNIC CCG v{version}',16,amber)
    if not done: text(850,72,'Awaiting finished shards',14,muted)
    cards={c['id']:c for c in json.loads((ROOT/'data/cards.json').read_text())}
    for i,(name,id) in enumerate(zip(NAMES,IDS)):
        x=43+i*287; cx=x+126
        draw.rounded_rectangle((x,113,x+252,400),radius=6,fill='#091219',outline='#1a414c')
        path=ROOT/cards.get(id,{}).get('image','assets/icon/defcon.png').removeprefix('res://')
        hero_art=path.is_file()
        if not hero_art: path=ROOT/'assets/icon/defcon.png'
        if path.is_file():
            art=Image.open(path).convert('RGB')
            # The top half of the card contains the illustration; omit its rules panel.
            if hero_art:
                art=art.crop((int(art.width*.08),int(art.height*.12),int(art.width*.92),int(art.height*.59)))
                art=ImageOps.fit(art,(112,114),method=Image.Resampling.LANCZOS)
            else:
                art=ImageOps.pad(art,(112,114),method=Image.Resampling.LANCZOS,color=bg)
            image.paste(art,(int(cx-56),125))
            draw.rectangle((cx-57,124,cx+56,239),outline=cyan)
        center(cx,244,name,22,cyan,True)
        person=s['people'].get(name,{})
        rate=person.get('wins',0)/person['games'] if person.get('games') else None
        center(cx,275,f'{rate:.1%} WINS' if rate is not None else '— WINS',25,green,True)
        for row,seats in enumerate((2,3,4)):
            wins=games=0
            for pool in ('2025','2026'):
                d=s['configurations'].get(f'{seats}P/{pool}',{}).get('people',{}).get(name,{})
                wins+=d.get('wins',0); games+=d.get('games',0)
            label=f'{seats}P   {wins:,} – {games:,}' if i<seats else f'{seats}P   —'
            center(cx,319+row*23,label,16,muted)
    def value(key,suffix=''):
        r=s['records'].get(key)
        return f"{r['value']:,.0f}{suffix}" if r else '—'
    most=max(s['cards'],key=lambda c:s['cards'][c]['bought'],default=None)
    winning=max(s['cards'],key=lambda c:s['cards'][c]['winner_games_bought'],default=None)
    wins=sum(x.get('wins',0) for x in s['people'].values())
    most_label=f"{cards.get(most,{}).get('name',most)} ({s['cards'][most]['bought']:,} times)" if most else '—'
    winning_label=f"{cards.get(winning,{}).get('name',winning)} ({s['cards'][winning]['winner_games_bought']/max(1,wins):.1%} of wins)" if winning else '—'
    records=[f"Longest game: {value('longest_game',' turns')}",f"Biggest hit: {value('biggest_hit')}",f"Fastest win: {value('fastest_win',' turns')}",f'Most-bought card: {most_label}',f'Winningest card: {winning_label}',f"Total damage dealt: {sum(p.get('damage_dealt',0) for p in s['people'].values()):,}"]
    for i,line in enumerate(records):
        text(37+(i%2)*572,419+(i//2)*36,line,15,amber if i in (1,4) else muted,maxwidth=550)
    text(37,537,f"{s['totals'].get('turns',0):,} turns  /  {s['totals'].get('draws',0):,} draws  /  {s['totals'].get('conservation_failures',0):,} conservation failures",15,red if s['totals'].get('conservation_failures') else green)
    draw.line((36,571,1163,571),fill=cyan)
    text(37,584,'phreaknic-ccg.net',15,cyan)
    text(593,584,f"bots were experimenting: {p['epsilon']:.0%} random buys",15,amber)
    temp=run/'stats_card.tmp.png'; image.save(temp); temp.replace(run/'stats_card.png')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run_dir',type=Path)
    args=parser.parse_args(); run=args.run_dir
    s=merge(run); p=s['progress']
    lines=[f"DEFCON self-play: {p['games_done']:,} / {p['games_planned']:,} games ({p['shards_done']}/{p['shards_planned']} shards)"]
    if not p['games_done']: lines.append('No finished shards yet; rerun this report after the first shard completes.')
    for key,c in s['configurations'].items():
        lines.append(f"{key}: {c['done']:,}/{c['planned']:,}"+(f" at {c['games_per_second']:.2f} games/s per worker" if c['games_per_second'] else ''))
    for name,person in s['people'].items(): lines.append(f"{name}: {person['wins']:,} wins / {person['games']:,} games ({person['wins']/max(1,person['games']):.1%})")
    lines.append(f"Conservation failures: {s['totals'].get('conservation_failures',0)}; errors: {s['totals'].get('errors',0)}; turn caps: {s['totals'].get('turn_caps',0)}")
    lines.append(f"Throughput: {p['games_per_worker_hour']:,.0f} games per worker-hour (summed shard wall times)")
    eta=p['estimated_remaining_hours_at_24_workers']
    lines.append(f'Estimated remaining at 24 workers: {eta:.2f} hours' if eta is not None else 'ETA awaits a finished shard in every configuration.')
    atomic(run/'summary.json',json.dumps(s,indent=2)+'\n')
    atomic(run/'summary.txt','\n'.join(lines)+'\n')
    render(run,s)
    print('\n'.join(lines))

if __name__=='__main__': main()
