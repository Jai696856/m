# Marcus's voice

All narration uses **ElevenLabs**, model `eleven_v4`, 1 take per line, flow `MU2PniQoAPInjebqqkFB`.

- Day 3 onward: "VALF - Young & Energetic" — voice_id `nNXPmxHfg9PtGzFxr9Zd`
  (changed after a viewer asked for a new voice).
- Days 1–2, thank-you and wheel videos: "Raspy" — voice_id `HL6h30e2Rd3SQjMZu1Wz`.
- Exact word timings: transcribe the generated audio node with `eleven_scribe_v1` (free),
  save words.json under audio/, and set "words_file" in the episode JSON.
- Free plan: 10,000 characters/month; free generations are sometimes "busy" — just retry.

## Day 9+ voice (Fish Audio)
ElevenLabs free characters ran out, so from Day 9 the narration uses Fish Audio:
- Voice: "Commentary Niche" — reference_id `1414df4cc21043b7bed23e1f99e11fdd` (closest match to VALF)
- Model header: `s2.1-pro-free`; body `{text, reference_id, format: "mp3", normalize: true}` → POST https://api.fish.audio/v1/tts
- Fish ASR needs paid credits, so timing uses silence detection: `"silence_db": -34, "silence_min": 0.12` in the episode JSON.

## Recurring cast
- **Lana** (from Day 9): golden puppy with a red collar and gold tag, Marcus's companion for the rest of the story — named in honor of @jetdabest1's dog. Draw with `dog(x, y, scale, t, state, face)` in engine/comic.js (states: sit, run, wet, sad).
