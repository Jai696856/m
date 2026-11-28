"""Design one reference clip per side character with OmniVoice voice design (fixed seed).
Later lines clone from these clips so each character keeps the same voice across episodes."""
import os, sys
sys.path.insert(0, os.environ.get("VOICESTUDIO", "/home/user/debpalash/voicestudio"))
import soundfile as sf, torch
from omnivoice.models.omnivoice import OmniVoice

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "audio", "voicestudio")
CAST = {
    # name: (instruct, seed, reference line)
    "dez": ("male, elderly, very low pitch, american accent", 11, "Listen to me, kid. Tired legs teach you the most. Now do it again, and this time do it right."),
    "bigmike": ("male, middle-aged, low pitch, american accent", 23, "You're late, rookie. Grill, fries, mop. I don't pay you to stand around, so move it."),
    "tasha": ("female, young adult, moderate pitch, american accent", 37, "Yo, new guy. You juggle like you actually play. Midnight, at the cage. Bring your boots."),
}
torch.set_num_threads(os.cpu_count())
model = OmniVoice.from_pretrained("k2-fsa/OmniVoice", device_map="cpu", dtype=torch.float32, allow_tokenizer_fallback=True)
for name in (sys.argv[1:] or CAST):
    instruct, seed, line = CAST[name]
    a = model.generate(text=line, instruct=instruct, language="English", seed=seed, num_step=32)[0]
    a = a.squeeze().cpu().numpy() if hasattr(a, "cpu") else a.squeeze()
    sf.write(os.path.join(OUT, f"voice-{name}.wav"), a, model.sampling_rate)
    open(os.path.join(OUT, f"voice-{name}.txt"), "w").write(line)
    print(name, round(len(a) / model.sampling_rate, 1), "s", flush=True)
