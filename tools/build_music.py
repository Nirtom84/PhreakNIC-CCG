#!/usr/bin/env python3
"""Build the bitwize soundtrack using decoded, sample-exact 48 kHz PCM cuts."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parent.parent
# slug, track, loop start, loop end (decoded MP3 samples at 48000 Hz)
# PhreakNIC: the cue sheet prints 0:13.888 but sample 1333242, which is that time at 96 kHz without the MP3
# encoder delay. 13.888 s * 48000 + 1105 delay = 667726; the audio there matches the audio after the loop end.
CUES = [
 ('main_theme',1,3507067,7343796), ('starter_deck',2,2751575,7203376),
 ('center_row_amber',3,721658,2799761), ('center_row_red',3,3744964,5630608),
 ('the_fellowship',4,2261996,6568089), ('botnet',5,966774,5346531),
 ('the_clarion_inn',6,1404154,5601648), ('nashville_2600',7,3459948,4872818),
 ('the_juice',8,983841,3992331), ('military_grade_card_encapsulation',9,1431575,3537590),
 ('oprah',10,2855767,7409578), ('time_travel',11,1588220,6487670),
 ('phreaknic',12,667726,3091850), ('ptfs',13,798598,3624490),
 ('ctf_bangers',14,3311280,7522141), ('oprah_wonka',15,1870740,3282354),
 ('toctou',16,6189325,7682596), ('access_granted',17,None,None),
 ('connection_terminated',18,None,None),
]

def run(*args):
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y',*map(str,args)], check=True)

def main():
 parser = argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--source-dir', type=Path, default=ROOT.parent/'music_src')
 parser.add_argument('--rate', type=int, default=32000)
 parser.add_argument('--quality', type=float, default=1)
 args = parser.parse_args()
 if args.rate <= 0 or not -1 <= args.quality <= 10: parser.error('invalid rate or Vorbis quality')
 out = ROOT/'assets/music'
 out.mkdir(parents=True, exist_ok=True)
 metadata = {}
 with tempfile.TemporaryDirectory(prefix='phreaknic-music-') as temp:
  for track in range(1,19):
   sources = sorted(args.source_dir.glob(f'{track:02d} - *'))
   sources = [p for p in sources if p.suffix.lower() in ('.mp3','.wav')]
   if len(sources) != 1: raise ValueError(f'Expected one MP3 or WAV for track {track}: {sources}')
   source = sources[0]
   pcm = Path(temp)/'decoded.wav'
   run('-i',source,'-ar',48000,'-ac',2,'-c:a','pcm_s16le',pcm)
   with wave.open(str(pcm),'rb') as decoded:
    total = decoded.getnframes()
    def encode(filename, start, end):
     if not 0 <= start < end <= total: raise ValueError(f'{filename}: invalid sample range')
     decoded.setpos(start)
     sliced = Path(temp)/'slice.wav'
     with wave.open(str(sliced),'wb') as dest:
      dest.setparams(decoded.getparams())
      dest.writeframes(decoded.readframes(end-start))
     run('-i',sliced,'-ar',args.rate,'-ac',2,'-c:a','libvorbis','-q:a',args.quality,out/filename)
    for slug, number, loop_start, loop_end in CUES:
     if number != track: continue
     start = next(c[3] for c in CUES if c[0] == 'center_row_amber') if slug == 'center_row_red' else 0
     end = loop_end if loop_end is not None else total
     encode(slug+'.ogg',start,end)
     outro = slug+'_out.ogg' if loop_end is not None and slug != 'center_row_amber' else None
     if outro: encode(outro, end, total)
     metadata[slug] = dict(file=slug+'.ogg', loop_offset=(loop_start-start)/48000 if loop_start is not None else 0.0,
                           length=(end-start)/48000, outro=outro, title=source.stem.split(' - ',1)[1], track=track,
                           looping=loop_end is not None, outro_length=(total-end)/48000 if outro else 0.0)
   print(f'{track:02d}: {source.name}')
 (ROOT/'data/music_cues.json').write_text(json.dumps(metadata,indent=2)+'\n')
 print(f'Total OGG bytes: {sum(p.stat().st_size for p in out.glob("*.ogg"))}')

if __name__ == '__main__': main()
