"""Narrate an episode with VoiceStudio's OmniVoice engine, one voice per character.

Usage: python engine/vs_tts.py <episode.json> <out.wav> [single test line]
A chunk is either {"text": ...} (narrator Marcus) or has "lines": [[voice, text], ...].
"gapAfter": seconds of silence after the chunk (gameplay moments).
Writes <out>.chunks.json (chunk starts) and <out>.words.json (estimated word timings,
usable as the episode's words_file).
"""
import json, os, sys, time
sys.path.insert(0, os.environ.get("VOICESTUDIO", "/home/user/debpalash/voicestudio"))
import numpy as np, soundfile as sf, torch
from omnivoice.models.omnivoice import OmniVoice

HERE = os.path.dirname(os.path.abspath(__file__))
VS = os.path.join(HERE, "..", "audio", "voicestudio")
REFS = {"marcus": ("ref-narrator.wav", "Day eight. You voted A... striker. The special match. A charity game. And then... he walked out of the tunnel.")}
for n in ("dez", "bigmike", "tasha"):
    if os.path.exists(os.path.join(VS, f"voice-{n}.wav")):
        REFS[n] = (f"voice-{n}.wav", open(os.path.join(VS, f"voice-{n}.txt")).read().strip())

ep = json.load(open(sys.argv[1])); out = sys.argv[2]
chunks = ep["chunks"] if len(sys.argv) < 4 else [{"text": sys.argv[3]}]
torch.set_num_threads(os.cpu_count())
model = OmniVoice.from_pretrained("k2-fsa/OmniVoice", device_map="cpu", dtype=torch.float32, allow_tokenizer_fallback=True)
prompts = {n: model.create_voice_clone_prompt(ref_audio=os.path.join(VS, f), ref_text=tx) for n, (f, tx) in REFS.items()}
sr = model.sampling_rate
sil = lambda s: np.zeros(int(sr * s), dtype=np.float32)


def trim(a, thr=0.012):
    idx = np.where(np.abs(a) > thr)[0]
    return a[max(0, idx[0] - int(0.03 * sr)): idx[-1] + int(0.06 * sr)] if len(idx) else a


pieces, starts, words, t = [], [], [], 0.0
for i, c in enumerate(chunks):
    lines = c.get("lines") or [["marcus", c["text"]]]
    starts.append(round(t, 3))
    for j, (voice, txt) in enumerate(lines):
        t0 = time.time()
        a = model.generate(text=txt, voice_clone_prompt=prompts[voice], language="English", num_step=32)[0]
        a = trim(a.squeeze().cpu().numpy() if hasattr(a, "cpu") else np.asarray(a).squeeze())
        d = len(a) / sr
        ws = txt.split(); wl = [len(w) + 1 for w in ws]; tot = sum(wl); pos = t
        for w, n in zip(ws, wl):
            words.append({"text": w, "start": round(pos, 3), "end": round(pos + d * n / tot, 3), "type": "word", "voice": voice}); pos += d * n / tot
        pause = 0.3 if j < len(lines) - 1 else 0.35
        pieces += [a, sil(pause)]; t += d + pause
        print(f"chunk {i}.{j} [{voice}] {d:.1f}s in {time.time()-t0:.0f}s", flush=True)
    if c.get("gapAfter"):
        pieces.append(sil(float(c["gapAfter"]))); t += float(c["gapAfter"])
sf.write(out, np.concatenate(pieces), sr)
json.dump(starts, open(out + ".chunks.json", "w"))
json.dump({"words": words}, open(out + ".words.json", "w"))
print("total", round(t, 2))
