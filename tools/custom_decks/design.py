#!/usr/bin/env python3
"""Hand-designed 100 custom Center Decks -> tools/custom_deck_specs.json.

Usage (from the project root):
  XDG_DATA_HOME=$(mktemp -d) OUT=/tmp/printings.json godot4.7.1 --headless -s tools/custom_decks/dump_printings.gd
  python3 tools/custom_decks/design.py . /tmp/printings.json tools/custom_decks/deck_defs.py
  godot4.7.1 --headless -s tools/custom_decks_build.gd


Each deck: explicit core (display name -> copies) plus an optional themed
top-up ("fill") drawn from role pools until the target size is reached.
"""
import json, random, re, sys, collections
ROOT = sys.argv[1]
PR = json.load(open(sys.argv[2]))  # CustomDeck.printings() dump

# ---------- name -> printing id ----------
name_count = collections.Counter(p['name'] for p in PR)
ID = {}; BASE = {}; LEG = {}
for p in PR:
    key = p['name']
    if name_count[key] > 1 and p['id'].endswith('@mog'): key += ' (Mog)'
    assert key not in ID, key
    ID[key] = p['id']; BASE[p['id']] = p['base_id']; LEG[p['base_id']] = p['legendary'] or LEG.get(p['base_id'], False)

def limit(base): return 2 if LEG[base] else 4

# ---------- role pools (display names of ORIGINAL printings) ----------
POOL = {
 'econ': ["c14ud3","notlarry","NotLarry Cardboard Cutout","zalphaWolf","Still Not Spock","Brimstone","Kevin Mitnick Cardboard Cutout","John Titor","Elonka","mog","JousterL","Venaul","hardwarez","tipsybacchus","Tyler Crumpton","Randy","pouipoui","Zenthere, Mind Goblin","Altk3y","Clarion Inn Staff","Payphone Dave","hfuller","fred rogers","heartsh8ped","Two Hump Camel","Treasure Hunters","itsamenathan","Drunk Riddler","Talks Fun Police","DeMartian"],
 'fottr': ["5ud0","bitwize","crook3dfingers","Errorgone","Fore04","G4nd4lf","proudF00F","cyberMonk3y","F.O.T.T.R. Greatest Hits","F.O.T.T.R. Capture the Flag","BONY","CTF Bangers"],
 'damage': ["Elevator Noises","Share a Link","Even More Logo","You've Got Mail","Doom on a Trading Card","Rookie Numbers","Hotel Roof Chair Toss","Under New Management","Botnet Takeover","evildagmar","Non-Infringing Game Show","CRT LAN Party","m8trix","_NASKEY","Should have Preregistered","I've got the Logs","Jenny","Two Hump Camel","heartsh8ped"],
 'draw': ["Bedtime Story","Lightning Talks","Clarion Inn Breakfast","Egg in Your Soup","Empty Lockpicking Table","Employee Review","Where's Apache!?","OSINT for Dummies","Payphone Karaoke","Pooping in the Dark","Number One PhreakNIC Rule","Registration","Speakers Needed","Phreaknic Website Refresh","Mog's Pancake Breakfast","What is Truth?","Tips and tricks for Windows and Office365"],
 'perm': ["Botnet","Payphone","Unattended Phone","Tableskirts","Filler","Shell Speech","White Python Boots","Disassembled Sink","Makeshift Lectern","Lowes Shopping Cart","Bribery","Fiverr Friendship","The Big Dipper","The Juice","Clarion Inn Air Conditioning","Dick Van Dyke Stamp","Powered-On Taser Maintenance","AI Ben's AI Camry","Clarion Inn Chandeliers","Time Travel","Military-Grade Card Encapsulation","CTF Bangers"],
 'ice': ["Corporate SWAG Table","The Sandwich Factory","Clarion Inn Carpeted Pool","The Clarion Inn","Candy Factory","Clarion Inn Storage Closet","Walmart Parking Lot","[Restaurant Name] Restaurant","Phreaknic Network","Hardware Hacking Village"],
 'disrupt': ["AI Slop","The Reason","Clarion Inn Morning Coffee","Talks Fun Police","Still Not Spock","AI Fingers","Etch-a-Sketch Skillz","Doom on a Trading Card","I've got the Logs","CRT LAN Party","AI Ben's AI Camry","Tennessee Department of Health"],
 'legend': ["benthemeek","benthephreak","Brimstone, Fabulous","_NSAKEY, Juiced","Nirtom Unleashed","Super r0nk","O.P.R.A.H.","Oprah Wonka","pouipoui, AV Guy","Merry Christmas","PhreakMyst","PhreakNIC","The Book","Foundation of Time/Temporal Reconstruction","The Fellowship of the Token Ring","Nuvious","Rick Astley"],
 'oddball': ["Kevin's Desk","Nashville 2600","Grass","pTFS","Tennessee Department of Health","Flesh Oprah","Etch-a-Sketch Skillz","TOCTOU Photo-Finish","Time Travel","Lowes Shopping Cart","Mog's Lemon Custard Ice Cream","Rickroll","Never Gonna Give You Up","Never Gonna Let You Down","F.O.T.T.R. Greatest Hits Volume 2","Corporate Retreat","Reps4Thor","Nirtom","r0nk","The Tone Whisperer","Clarion Inn Chandeliers","Altk3y","Speakers Needed"],
}
POOL['all'] = sorted({n for v in POOL.values() for n in v})
MOG = sorted(k for k in ID if ID[k].endswith('@mog') or k == 'Mognet')

DECKS = []
def deck(name, size, tags, desc, style, combos, core, fill=None, copies=2, exclude=(), seed=None):
    DECKS.append(dict(name=name, size=size, tags=tags, desc=desc, style=style, combos=combos, core=core, fill=fill or [], copies=copies, exclude=set(exclude), seed=seed if seed is not None else len(DECKS)))

def build(d):
    counts = collections.OrderedDict(); per_base = collections.Counter()
    def add(nm, n):
        assert nm in ID, (d['name'], nm)
        pid = ID[nm]; b = BASE[pid]
        n = min(n, limit(b) - per_base[b], d['size'] - sum(counts.values()))
        if n <= 0: return 0
        counts[pid] = counts.get(pid, 0) + n; per_base[b] += n; return n
    for nm, n in d['core'].items():
        got = add(nm, n)
        assert got == n, (d['name'], nm, n, got)
    rng = random.Random(1000 + d['seed'])
    for rnd in range(4):
        cands = []
        for pool in d['fill']:
            names = list(POOL[pool]) if pool in POOL else [pool]
            rng.shuffle(names); cands += names
        for nm in cands:
            if sum(counts.values()) >= d['size']: break
            if nm in d['exclude'] or nm not in ID: continue
            add(nm, d['copies'] if rnd == 0 else 1)
        if sum(counts.values()) >= d['size']: break
    if sum(counts.values()) < d['size']:
        print('note: topping up', d['name'], 'from the related pools', file=sys.stderr)
        extra = sorted(POOL['econ'] + POOL['draw']); rng.shuffle(extra)
        for nm in extra * 4:
            if sum(counts.values()) >= d['size']: break
            if nm not in d['exclude']: add(nm, 1)
    assert sum(counts.values()) == d['size'], (d['name'], sum(counts.values()), d['size'])
    return [[k, v] for k, v in counts.items()]

B = lambda s: s  # readability helper for backticked names in combo strings
exec(open(sys.argv[3]).read())  # deck definitions

out = []
for i, d in enumerate(DECKS):
    slug = re.sub(r'[^a-z0-9]+', '-', d['name'].lower()).strip('-')
    out.append(dict(slug=slug, name=d['name'], description=d['desc'], play_style=d['style'], combos=d['combos'], tags=d['tags'], cards=build(d)))
json.dump(out, open(f"{ROOT}/tools/custom_deck_specs.json", 'w'), indent=1, ensure_ascii=False)
hist = [0,0,0,0]
for d in DECKS: hist[0 if d['size']<80 else 1 if d['size']<120 else 2 if d['size']<160 else 3] += 1
print(len(out), 'decks; histogram', hist)
