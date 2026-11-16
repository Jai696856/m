---
name: record-youtube-live
description: Record a YouTube live stream to a local video file with yt-dlp and ffmpeg. Use when the user asks to record, capture, save, archive or DVR a YouTube livestream (a youtube.com/watch, youtu.be, /live or channel @handle/live URL), wait for a scheduled stream to start and record it, record from the beginning of a stream that is already running, or record only a fixed duration.
---

# Record a YouTube live stream

Records a live (or upcoming) YouTube stream to disk using `scripts/record.sh`,
a wrapper around `yt-dlp` + `ffmpeg`.

## Before recording

1. Only record streams the user owns or has permission to save (their own
   channel, Creative Commons, or personal/offline use the creator allows).
   If the request is clearly to redistribute someone else's content, say so
   and don't proceed.
2. Check tools: `command -v yt-dlp ffmpeg`. If `yt-dlp` is missing, install it
   with `pip install -U yt-dlp` (or `pipx install yt-dlp`). Keep it up to date —
   YouTube changes often and an old yt-dlp is the #1 cause of failures.
3. Confirm the stream: `yt-dlp --print "%(title)s | live_status=%(live_status)s" URL`.
   `live_status` is `is_live`, `is_upcoming`, `was_live` or `not_live`.

## Recording

```bash
bash .claude/skills/record-youtube-live/scripts/record.sh URL [options]
```

| Option | Meaning |
|---|---|
| `-o DIR` | Output folder (default `./recordings`) |
| `-q QUALITY` | `best` (default), `1080`, `720`, `480`, or `audio` |
| `-d DURATION` | Stop after a duration, e.g. `30m`, `2h`, `90s`, `01:30:00` |
| `--from-start` | Record from the beginning of a stream already in progress (DVR) |
| `--wait` | If the stream is scheduled, wait and start recording when it goes live |
| `--cookies FILE` | Netscape cookies.txt, for members-only / age-restricted streams |

Examples:

- Record now until the stream ends: `record.sh https://www.youtube.com/@handle/live`
- Wait for a premiere and record at 720p: `record.sh URL --wait -q 720`
- Grab one hour from the start: `record.sh URL --from-start -d 1h`

Long recordings: run the script in the background (Bash `run_in_background`)
so the session isn't blocked, and tell the user where the file will land.
Stop early with Ctrl-C / killing the process — yt-dlp finalises the partial
file into a playable video (`.part` files can be remuxed with
`ffmpeg -i in.part -c copy out.mp4`).

## Output

Files are saved as `DIR/<upload date> <title> [<id>].<ext>` (mp4/mkv, or m4a
for audio). Afterwards report the path, size (`du -h`) and duration
(`ffprobe -v error -show_entries format=duration -of csv=p=0 FILE`).

## Troubleshooting

- "Sign in to confirm you're not a bot" / 403: update yt-dlp; then try `--cookies`.
- Members-only / private: needs `--cookies` from an account with access.
- `--from-start` only works if the streamer enabled DVR and the stream is
  under ~5 days; otherwise recording starts from the live edge.
- Cloud/container sessions may have youtube.com blocked by the network policy;
  then the recording must run on the user's own machine.
