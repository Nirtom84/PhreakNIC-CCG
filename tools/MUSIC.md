# bitwize soundtrack

Music by bitwize. Sources remain outside the repository in `../music_src/`. Only the generated OGGs and cue metadata ship.

## Rebuild

Install Python 3 and ffmpeg with libvorbis, then run from any directory:

```sh
python3 tools/build_music.py
python3 tools/build_music.py --source-dir /path/to/sources --rate 32000 --quality 1
```

Defaults: 32 kHz stereo, Vorbis quality 1. The source directory must contain exactly one `NN - Title.mp3` or `NN - Title.wav` per track. The tool decodes each complete source to 48 kHz stereo PCM in a temporary directory, slices PCM frames, then resamples and encodes. It never seeks within compressed MP3 data or copies MP3s into the repository. Rebuild all cues together; import afterward with Godot 4.7.1 `--headless --import`.

The table below uses the composer’s **decoded MP3 sample positions at 48 kHz**, including the supplied encoder delay. PhreakNIC’s printed loop start (0:13.888) conflicts with its printed sample value (1333242, which is 27.776 seconds). The sample value is the same time counted at 96 kHz without the MP3 encoder delay, so the tool uses 13.888 s × 48000 + 1105 = **667726**; the audio there matches the audio that follows the loop end, and nothing near 1333242 does. Confirm with bitwize when the WAVs arrive. The cue sheet recommends full-quality WAVs for final seamless-loop quality. For later 24-bit/96 kHz WAV sources, confirm loop boundaries with the composer and update `CUES` to the corresponding positions in the decoded/resampled 48 kHz PCM; do not blindly reuse MP3 encoder-delay offsets.

## Cue table

| Slug | Track | Loop start sample | Loop end sample |
| --- | ---: | ---: | ---: |
| main_theme | 01 | 3507067 | 7343796 |
| starter_deck | 02 | 2751575 | 7203376 |
| center_row_amber | 03 | 721658 | 2799761 |
| center_row_red | 03 | 3744964 | 5630608 |
| the_fellowship | 04 | 2261996 | 6568089 |
| botnet | 05 | 966774 | 5346531 |
| the_clarion_inn | 06 | 1404154 | 5601648 |
| nashville_2600 | 07 | 3459948 | 4872818 |
| the_juice | 08 | 983841 | 3992331 |
| military_grade_card_encapsulation | 09 | 1431575 | 3537590 |
| oprah | 10 | 2855767 | 7409578 |
| time_travel | 11 | 1588220 | 6487670 |
| phreaknic | 12 | 667726 | 3091850 |
| ptfs | 13 | 798598 | 3624490 |
| ctf_bangers | 14 | 3311280 | 7522141 |
| oprah_wonka | 15 | 1870740 | 3282354 |
| toctou | 16 | 6189325 | 7682596 |
| access_granted | 17 | one-shot | whole file |
| connection_terminated | 18 | one-shot | whole file |

Looping files contain the intro through loop end; `_out.ogg` contains loop end through EOF. Amber has no outro. Red begins at amber’s loop end (2799761), so its loop offset is (3744964 − 2799761) / 48000 seconds. All other looping files begin at sample zero. Stings contain the whole source and never loop. `data/music_cues.json` records filenames, offsets and lengths in seconds, titles, source track numbers and outro lengths. Runtime explicitly sets stream loop and loop_offset; import loop flags are not used.

## Runtime and hosting

Menu/rules/Hero picker use Main Theme; lobby uses PhreakNIC. All surviving players above 10 life use Starter Deck; any at 10 or below use amber; any at 5 or below use red. Public permanent names add rotation cues. A new permanent starts immediately; otherwise the intro and two loop traversals precede the next rotation cue. Turn cards override rotation; TOCTOU overrides turn cards. Clarion’s collapse ending plays in full when its playing theme leaves rotation. Time Travel activation retains the cue through its extra turn and restarts it when that turn starts. Results play one sting then silence.

Public table events supply played cards, turn boundaries, Time Travel activations and TOCTOU saves. Offline these come from engine signals; online the server forwards the same public events and the table reads its mirrored public board. No hand/deck contents or copied effect identities enter music selection. Copies match their own printed public name.

Two Music-bus players crossfade over 0.8 seconds, with −8 dB below the user slider. Headless/server runs allocate neither players nor requests. Web waits for the first input gesture, fetches `music/<file>` relative to document.baseURI, caches streams in memory and retries failed files no more than once per minute. The current track continues during downloads. Web and Server presets exclude the OGG directory; `tools/build_all.sh web` copies it to `build/web/music/`. The site Worker applies a 30-day cache header; its existing same-origin connect-src/media-src allow this. The deployment asset ignore list only excludes wasm/pck and itself, so music remains a static asset. No deployment is required to rebuild locally.
