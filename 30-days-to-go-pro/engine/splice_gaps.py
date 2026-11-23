"""Insert silent gameplay gaps into a narration and build the match sound bed.

Usage: python3 splice_gaps.py <episode.json>

Reads episode["voice_file"] + episode["voice_words"], inserts `gapAfter` seconds of
silence after each chunk that asks for it, shifts the word timings, then mixes a
crowd/kick/whistle bed under the live-match chunks. Writes episode["words_file"] and
<voice_file with -voice replaced by ''> (the final audio passed to render.js).
"""
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from timeline import build_from_words  # noqa: E402

# Seconds-within-play where sounds happen, as fractions of the chunk (must match comic.js plays).
PLAY_SFX = {
    'kickoff': [(0.02, 'whistle'), (0.66, 'kick'), (0.82, 'cheer')],
    'concede': [(0.55, 'kick'), (0.68, 'groan')],
    'post': [(0.70, 'kick'), (0.80, 'post'), (0.82, 'groan')],
    'equalizer': [(0.58, 'kick'), (0.74, 'roar')],
    'celebrate': [(0.0, 'roar')],
    'winner': [(0.52, 'kick'), (0.62, 'kick'), (0.74, 'roar'), (0.93, 'whistle3')],
}


def dur(p):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p]))


def main(ep_path):
    base = os.path.dirname(os.path.abspath(ep_path))
    ep = json.load(open(ep_path))
    voice = os.path.join(base, ep["voice_file"])
    vwords = os.path.join(base, ep["voice_words"])
    tl, _ = build_from_words(ep["chunks"], voice, vwords)

    cuts = []  # (time in original audio, gap seconds)
    for c in tl:
        if c.get("gapAfter"):
            end = max(w[2] for w in c["words"][:-1]) if len(c["words"]) > 1 else c["words"][0][2]
            last = [w for w in json.load(open(vwords))["words"] if w.get("type", "word") == "word" and w["start"] <= c["words"][-1][1] + 0.01]
            end = last[-1]["end"] if last else end
            allw = [w for w in json.load(open(vwords))["words"] if w.get("type", "word") == "word"]
            nxt = [w["start"] for w in allw if w["start"] > end - 1e-3]
            cut = min(end + 0.12, (nxt[0] - 0.02) if nxt else end + 0.12)
            cuts.append((max(end, cut), float(c["gapAfter"])))

    # build spliced narration
    tmp = os.path.join(base, "audio", "_splice")
    os.makedirs(tmp, exist_ok=True)
    parts, prev = [], 0.0
    for i, (ct, gap) in enumerate(cuts):
        seg = os.path.join(tmp, f"s{i}.wav")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", voice, "-ss", f"{prev}", "-to", f"{ct}", "-ar", "44100", "-ac", "1", seg], check=True)
        sil = os.path.join(tmp, f"g{i}.wav")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", f"{gap}", sil], check=True)
        parts += [seg, sil]
        prev = ct
    last = os.path.join(tmp, "slast.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", voice, "-ss", f"{prev}", "-ar", "44100", "-ac", "1", last], check=True)
    parts.append(last)
    lst = os.path.join(tmp, "list.txt")
    open(lst, "w").write("".join(f"file '{p}'\n" for p in parts))
    narr = os.path.join(tmp, "narration.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", narr], check=True)

    # shift words
    words = json.load(open(vwords))["words"]
    out = []
    for w in words:
        shift = sum(g for ct, g in cuts if w["start"] >= ct)
        out.append(dict(w, start=w["start"] + shift, end=w["end"] + shift))
    json.dump({"words": out}, open(os.path.join(base, ep["words_file"]), "w"))

    # timeline on the spliced audio to place sound effects
    tl2, total = build_from_words(ep["chunks"], narr, os.path.join(base, ep["words_file"]))
    live = [c for c in tl2 if c["scene"] == "live"]
    events = []
    for c in live:
        for p, kind in PLAY_SFX.get(c.get("play"), []):
            events.append((c["t0"] + p * (c["t1"] - c["t0"]), kind))
    m0, m1 = live[0]["t0"], live[-1]["t1"]
    won = [c for c in tl2 if c["scene"] == "won"]
    if won:
        m1 = won[0]["t1"]

    sfx = {
        'whistle': "sine=f=2900:d=0.45,volume=0.35,tremolo=f=30:d=0.6",
        'whistle3': "sine=f=2900:d=1.6,volume=0.35,tremolo=f=30:d=0.6,afade=t=out:st=1.3:d=0.3",
        'kick': "sine=f=70:d=0.18,volume=1.6,afade=t=out:st=0.02:d=0.16",
        'post': "sine=f=1150:d=0.6,volume=0.5,afade=t=out:st=0.05:d=0.55",
        'cheer': "anoisesrc=d=2.2:c=pink:a=0.5,lowpass=f=2200,afade=t=in:d=0.3,afade=t=out:st=1.2:d=1.0",
        'roar': "anoisesrc=d=4:c=pink:a=0.8,lowpass=f=2600,afade=t=in:d=0.2,afade=t=out:st=2.2:d=1.8",
        'groan': "anoisesrc=d=1.6:c=brown:a=0.5,lowpass=f=700,afade=t=in:d=0.2,afade=t=out:st=0.6:d=1.0",
    }
    inputs, filters = ["-i", narr], []
    # crowd bed
    bed_len = m1 - m0
    inputs += ["-f", "lavfi", "-i", f"anoisesrc=d={bed_len:.2f}:c=pink:a=0.16,lowpass=f=1500,tremolo=f=0.35:d=0.35,afade=t=in:d=1.5,afade=t=out:st={max(0, bed_len - 2):.2f}:d=2"]
    filters.append(f"[1:a]adelay={int(m0 * 1000)}|{int(m0 * 1000)}[bed]")
    labels = ["[bed]"]
    for i, (et, kind) in enumerate(events):
        inputs += ["-f", "lavfi", "-i", sfx[kind]]
        idx = i + 2
        filters.append(f"[{idx}:a]aresample=44100,aformat=channel_layouts=mono,adelay={int(et * 1000)}|{int(et * 1000)}[e{i}]")
        labels.append(f"[e{i}]")
    filters.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0[fx]")
    filters.append("[0:a][fx]amix=inputs=2:normalize=0,alimiter=limit=0.95[out]")
    final = os.path.join(base, ep["voice_file"].replace("-voice", ""))
    subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[out]", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "192k", final], check=True)
    print("narration", round(dur(voice), 2), "-> final", round(dur(final), 2), "events", len(events))


if __name__ == "__main__":
    main(sys.argv[1])
