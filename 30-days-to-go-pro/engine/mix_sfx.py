"""Mix sound effects under a VoiceStudio narration (Day 10+).

Usage: python3 engine/mix_sfx.py <episode.json> <voice.wav> <out.mp3>
Cage-match chunks get whistle/kick/crowd cues, kitchen scenes get grill sizzle.
"""
import json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from timeline import build_from_words  # noqa: E402

CAGE_SFX = {
    'cg1': [(0.02, 'whistle'), (0.55, 'kick'), (0.66, 'groan')],
    'cg2': [(0.3, 'kick'), (0.56, 'kick'), (0.67, 'roar')],
    'cg3': [(0.5, 'kick'), (0.66, 'roar')],
    'cg4': [(0.3, 'kick'), (0.5, 'kick'), (0.64, 'roar'), (0.92, 'whistle3')],
}
SFX = {
    'whistle': "sine=f=2900:d=0.45,volume=0.35,tremolo=f=30:d=0.6",
    'whistle3': "sine=f=2900:d=1.6,volume=0.35,tremolo=f=30:d=0.6,afade=t=out:st=1.3:d=0.3",
    'kick': "sine=f=70:d=0.18,volume=1.6,afade=t=out:st=0.02:d=0.16",
    'roar': "anoisesrc=d=3.5:c=pink:a=0.7,lowpass=f=2600,afade=t=in:d=0.2,afade=t=out:st=1.8:d=1.7",
    'groan': "anoisesrc=d=1.6:c=brown:a=0.5,lowpass=f=700,afade=t=in:d=0.2,afade=t=out:st=0.6:d=1.0",
}


def main(ep_path, voice, out):
    base = os.path.dirname(os.path.abspath(ep_path))
    ep = json.load(open(ep_path))
    tl, dur = build_from_words(ep["chunks"], voice, os.path.join(base, ep["words_file"]))
    events, beds = [], []
    for c in tl:
        T0, T1 = c["t0"], c["t1"]
        if c["scene"] == "cage":
            for p, kind in CAGE_SFX.get(c["play"], []):
                f = (p - 0.22) / 0.5 if c.get("view") == "replay" else p
                if 0 <= f <= 1 and not (c.get("view") == "replay" and kind.startswith("whistle")):
                    events.append((T0 + f * (T1 - T0), kind))
        if c["scene"] in ("cage", "cagecard", "cagewon"):
            beds.append((T0, T1, "anoisesrc=c=pink:a=0.12,lowpass=f=1500,tremolo=f=0.35:d=0.35"))
        if c["scene"] in ("bigmike", "shift", "tasha"):
            beds.append((T0, T1, "anoisesrc=c=white:a=0.03,highpass=f=3000,tremolo=f=7:d=0.5"))
    inputs, filters, labels = ["-i", voice], [], []
    n = 1
    for a, b, src in beds:
        L = b - a
        inputs += ["-f", "lavfi", "-i", f"{src.split(',')[0]}:d={L:.2f},{','.join(src.split(',')[1:])},afade=t=in:d=0.4,afade=t=out:st={max(0, L - 0.5):.2f}:d=0.5"]
        filters.append(f"[{n}:a]aresample=44100,aformat=channel_layouts=mono,adelay={int(a * 1000)}|{int(a * 1000)}[b{n}]"); labels.append(f"[b{n}]"); n += 1
    for et, kind in events:
        inputs += ["-f", "lavfi", "-i", SFX[kind]]
        filters.append(f"[{n}:a]aresample=44100,aformat=channel_layouts=mono,adelay={int(et * 1000)}|{int(et * 1000)}[e{n}]"); labels.append(f"[e{n}]"); n += 1
    filters.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0[fx]")
    filters.append("[0:a]aresample=44100,aformat=channel_layouts=mono,loudnorm=I=-16:TP=-1.5[v]")
    filters.append("[v][fx]amix=inputs=2:normalize=0,alimiter=limit=0.95[out]")
    subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[out]", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "192k", out], check=True)
    print("mixed", len(events), "events,", len(beds), "beds ->", out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
