---
name: livestream-clipper
description: Watch a YouTube livestream (or its replay) and turn the best moments into clips or a compilation, Kyro-style ("Best GTA VI clips so far"). Use when the user shares a youtube.com/live/ link, a stream VOD, or asks to "watch", "clip", "find the best moments of" or "make a compilation from" a livestream. Handles streams that are still live by checking back until the replay is ready.
---

# Livestream Clipper

Turns a livestream into clips using the vidIQ tools. Load each tool with
ToolSearch (`select:mcp__vidIQ__<name>`) before the first call.

## What is and isn't possible

- The tools cannot watch a stream *in real time*. They work on the finished
  replay (VOD). While a stream is live, YouTube reports its duration as `P0D`
  and transcripts/clipping refuse it.
- "Watching a livestream" here means: detect it's live → check back on a
  schedule → as soon as the replay exists, watch it, find the best moments,
  and clip them.
- `vidiq_video_watch` handles replays up to 6 hours. Longer streams must be
  split into sections (see step 4).
- `vidiq_generate_clips` only outputs **vertical** clips (Shorts/TikTok/Reels).
  A landscape compilation has to be assembled in an editor from timestamps.

## Costs (always tell the user before spending)

| Tool | Cost |
| --- | --- |
| `vidiq_get_videos_by_ids` | 5 credits |
| `vidiq_video_transcript` | 5 credits |
| `vidiq_video_watch` | 25 credits per call |
| `vidiq_generate_clips` | 9 credits per minute processed |
| `vidiq_job_poll`, `vidiq_balance` | free |

A 10-hour stream clipped end to end is ~5,400 credits. Prefer finding the
moments first (transcript + watch, cheap) and then clipping only short ranges
around them with `processingStartSeconds` / `processingEndSeconds`.

## Workflow

### 1. Check the stream
Call `vidiq_get_videos_by_ids` with the link. Report title, channel, views.
- `duration` is `P0D` → still live (or replay processing). Go to step 2.
- Real duration → replay is ready. Go to step 3.

### 2. Stream is live: check back until the replay is ready
Ask the user once whether to keep watching for it. If yes, schedule a check-in
with `mcp__claude-code-remote__send_later` (start at ~60 minutes; streams can
run 8–12+ hours, so back off to every 2 hours after a few misses). The message
should say: "Re-check livestream <id> for a finished replay and continue the
livestream-clipper workflow with: <user's format, focus, section>."
On each check-in run step 1 again (5 credits). Stop after ~24 hours, or if the
user says stop, and tell them. Never sleep-poll in the shell.

### 3. Agree the output
Ask only what's unknown:
1. **Format**: vertical Shorts (separate 30–60s clips) or a compilation list
   (timestamps + vertical clips to join in an editor).
2. **Focus**: e.g. "funniest reactions, chaos, police chases, first-time moments".
3. **Section**: whole stream or a time range.

### 4. Find the best moments
1. `vidiq_video_transcript` (5 credits) — skim for hype: shouting, laughter,
   "bro", "no way", chat reactions, sudden topic changes. Note timestamps.
   If it errors because the stream was live over a day, skip to the next step.
2. `vidiq_video_watch` (25 credits) with a prompt like:
   "List the 10–15 best clip-worthy moments for a highlight compilation
   focused on <focus>. For each: start–end timestamp, what happens, why it's
   funny/exciting, and a hook title." For streams over 6 hours, ask about the
   section the user cares about, or split into ≤6h halves via the prompt.
   Poll `vidiq_job_poll` until `completed`; read `analysisText`.
3. Show the user a ranked moment list with timestamps and estimated clipping
   cost, and get a go-ahead.

### 5. Clip
For each approved moment (or a merged range covering several close ones), call
`vidiq_generate_clips` with:
- `videoUrl`: the replay link
- `processingStartSeconds` / `processingEndSeconds`: ~30s before to ~30s after
  the moment (span must be ≥30s)
- `prompt`: what the moment is, so the right part is chosen
- `clipDuration`: 30–60 for Shorts
- `captionStyle`: "Loud & Clear" default; "Hype Mode" suits gaming streams

Poll `vidiq_job_poll` for each `mcpJobId` until completed; failed jobs are
refunded automatically.

### 6. Deliver
Give the user: each clip's link, the source timestamp, a suggested title, and
for a compilation an ordered edit list (strongest clip first, best
saved for last). Remind them once: reposting another creator's stream can get
copyright claims — add commentary/edits and credit the streamer.
