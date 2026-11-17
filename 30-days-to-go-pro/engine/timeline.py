"""Print the narration-aligned timeline for an episode as JSON."""
import json
import re
import subprocess
import sys


def audio_duration(path):
    return float(subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]))


def silences(path):
    r = subprocess.run(["ffmpeg", "-i", path, "-af", "silencedetect=noise=-35dB:d=0.25", "-f", "null", "-"],
                       capture_output=True, text=True)
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", r.stderr)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", r.stderr)]
    return list(zip(starts, ends))


def build(chunks, audio):
    dur = audio_duration(audio)
    sil = silences(audio)
    start = sil[0][1] if sil and sil[0][0] < 0.05 else 0.0
    end = sil[-1][0] if sil and sil[-1][1] >= dur - 0.05 else dur
    mids = [(s + e) / 2 for s, e in sil if start < (s + e) / 2 < end]
    lens = [len(c["text"]) for c in chunks]
    total, acc, bounds = sum(lens), 0, [start]
    for n in lens[:-1]:
        acc += n
        guess = start + (end - start) * acc / total
        if mids:
            best = min(mids, key=lambda m: abs(m - guess))
            if abs(best - guess) < 2.5 and best > bounds[-1] + 0.4:
                guess = best
        bounds.append(guess)
    bounds.append(end)
    # a chunk may pin its start time ("at": seconds) when pause-snapping guesses wrong
    for i, c in enumerate(chunks):
        if i > 0 and "at" in c:
            bounds[i] = float(c["at"])
    # speech intervals, used to place words only where there is voice
    speech, cur = [], start
    for s, e in sil:
        if e <= start or s >= end:
            continue
        if s > cur:
            speech.append((cur, s))
        cur = max(cur, e)
    speech.append((cur, end))
    out = []
    for i, c in enumerate(chunks):
        t0, t1 = bounds[i], bounds[i + 1]
        spans = [(max(a, t0), min(b, t1)) for a, b in speech if min(b, t1) > max(a, t0)] or [(t0, t1)]
        talk = sum(b - a for a, b in spans)
        words = c["text"].split()
        wl = [len(w) + 1 for w in words]
        tot = sum(wl)
        wt, pos = [], 0.0
        for w, n in zip(words, wl):
            a, b = pos, pos + talk * n / tot
            pos = b

            def at(x):
                for sa, sb in spans:
                    if x <= sb - sa:
                        return sa + x
                    x -= sb - sa
                return spans[-1][1]
            wt.append([w, at(a + 1e-6), at(b)])
        # keep the last word on screen until the chunk ends
        wt[-1][2] = t1
        out.append(dict(c, t0=t0, t1=t1, words=wt))
    out[-1]["t1"] = dur + 1
    return out, dur


if __name__ == "__main__":
    ep = json.load(open(sys.argv[1]))
    tl, dur = build(ep["chunks"], sys.argv[2])
    print(json.dumps({"timeline": tl, "duration": dur}))
