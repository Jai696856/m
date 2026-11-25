"""Narrate an episode with VoiceStudio's OmniVoice engine (voice clone of the series narrator).

Usage: python engine/vs_tts.py <episode.json> <out_voice.wav>
Generates each chunk separately, joins them with short pauses and writes
<out>.chunks.json with each chunk's start time (used as `at` pins).
"""
import json, os, sys, time
sys.path.insert(0, os.environ.get("VOICESTUDIO", "/home/user/debpalash/voicestudio"))
import numpy as np, soundfile as sf, torch
from omnivoice.models.omnivoice import OmniVoice

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "..", "audio", "voicestudio", "ref-narrator.wav")
REF_TEXT = "Day eight. You voted A... striker. The special match. A charity game. And then... he walked out of the tunnel."

ep = json.load(open(sys.argv[1])); out = sys.argv[2]
texts = [c["text"] for c in ep["chunks"]] if len(sys.argv) < 4 else [sys.argv[3]]
torch.set_num_threads(os.cpu_count())
model = OmniVoice.from_pretrained("k2-fsa/OmniVoice", device_map="cpu", dtype=torch.float32, allow_tokenizer_fallback=True)
prompt = model.create_voice_clone_prompt(ref_audio=REF, ref_text=REF_TEXT)
sr = model.sampling_rate
pieces, starts, t = [], [], 0.0
gap = np.zeros(int(sr * 0.35), dtype=np.float32)
for i, txt in enumerate(texts):
    t0 = time.time()
    a = model.generate(text=txt, voice_clone_prompt=prompt, language="English", num_step=32)[0]
    a = a.squeeze().cpu().numpy() if hasattr(a, "cpu") else np.asarray(a).squeeze()
    starts.append(round(t, 3)); pieces += [a, gap]; t += (len(a) + len(gap)) / sr
    print(f"chunk {i}: {len(a)/sr:.1f}s audio in {time.time()-t0:.0f}s", flush=True)
sf.write(out, np.concatenate(pieces), sr)
json.dump(starts, open(out + ".chunks.json", "w"))
print("total", round(t, 2))
