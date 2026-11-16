#!/usr/bin/env bash
# Record a YouTube live stream with yt-dlp + ffmpeg.
# Usage: record.sh URL [-o DIR] [-q best|1080|720|480|audio] [-d DURATION]
#                      [--from-start] [--wait] [--cookies FILE]
set -euo pipefail

usage() { sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

URL="" OUT="./recordings" QUALITY="best" DURATION="" FROM_START=0 WAIT=0 COOKIES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    -q) QUALITY="$2"; shift 2 ;;
    -d) DURATION="$2"; shift 2 ;;
    --from-start) FROM_START=1; shift ;;
    --wait) WAIT=1; shift ;;
    --cookies) COOKIES="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) URL="$1"; shift ;;
  esac
done
[[ -n "$URL" ]] || usage

for t in yt-dlp ffmpeg; do
  command -v "$t" >/dev/null || { echo "Missing $t. Install: pip install -U yt-dlp / apt install ffmpeg" >&2; exit 2; }
done

# Convert 30m / 2h / 90s / HH:MM:SS to seconds.
to_seconds() {
  local d="$1"
  case "$d" in
    *:*) IFS=: read -r a b c <<<"$d"; [[ -z "$c" ]] && { c=$b; b=$a; a=0; }
         echo $((10#$a*3600 + 10#$b*60 + 10#$c)) ;;
    *h) echo $(( ${d%h} * 3600 )) ;;
    *m) echo $(( ${d%m} * 60 )) ;;
    *s) echo "${d%s}" ;;
    *)  echo "$d" ;;
  esac
}

case "$QUALITY" in
  best)  FMT="bv*+ba/b" ;;
  audio) FMT="ba/b" ;;
  [0-9]*) FMT="bv*[height<=${QUALITY}]+ba/b[height<=${QUALITY}]/b" ;;
  *) echo "Bad quality: $QUALITY" >&2; exit 1 ;;
esac

mkdir -p "$OUT"
ARGS=(
  --no-playlist --live-from-start
  -f "$FMT"
  -o "$OUT/%(upload_date>%Y-%m-%d)s %(title).150B [%(id)s].%(ext)s"
  --hls-use-mpegts            # partial file stays playable if interrupted
  --retries 20 --fragment-retries 50 --retry-sleep fragment:exp=1:20
  --newline --no-colors
)
[[ $FROM_START -eq 1 ]] || ARGS=("${ARGS[@]/--live-from-start/}")
[[ $WAIT -eq 1 ]] && ARGS+=(--wait-for-video 30-120)
[[ -n "$COOKIES" ]] && ARGS+=(--cookies "$COOKIES")
if [[ "$QUALITY" == audio ]]; then
  ARGS+=(-x --audio-format m4a)
else
  ARGS+=(--merge-output-format mp4)
fi
if [[ -n "$DURATION" ]]; then
  SECS=$(to_seconds "$DURATION")
  ARGS+=(--downloader ffmpeg --downloader-args "ffmpeg_i:-t $SECS")
fi

# Drop empty array entries left by the --live-from-start removal.
CLEAN=(); for a in "${ARGS[@]}"; do [[ -n "$a" ]] && CLEAN+=("$a"); done

echo "Checking stream..."
yt-dlp ${COOKIES:+--cookies "$COOKIES"} --no-playlist \
  --print "Title: %(title)s | Channel: %(channel)s | Status: %(live_status)s" "$URL" || true

echo "Recording to $OUT ..."
exec yt-dlp "${CLEAN[@]}" "$URL"
