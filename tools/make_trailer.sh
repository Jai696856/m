#!/bin/bash
# Builds trailer.mp4 from the game itself.
#   tools/make_trailer.sh <godot binary> <work dir> <output.mp4>
# Needs xvfb-run and ffmpeg. Rendering takes about 20 minutes without a GPU.
set -e
GODOT="$1"; WORK="$2"; OUT="$3"
mkdir -p "$WORK/frames"
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 \
    --fixed-fps 30 --write-movie "$WORK/frames/f.png" -s tools/trailer.gd
"$GODOT" --headless --path . -s tools/render_music.gd -- game "$WORK/music.wav"
DUR=$(ls "$WORK/frames"/f*.png | wc -l | awk '{printf "%.3f", $1 / 30}')
FADE=$(awk -v d="$DUR" 'BEGIN{printf "%.3f", d - 2.5}')
ffmpeg -y -loglevel error -framerate 30 -i "$WORK/frames/f%08d.png" -i "$WORK/frames/f.wav" -stream_loop -1 -i "$WORK/music.wav" \
    -filter_complex "[1:a]volume=0.55[sfx];[2:a]volume=1.9,afade=t=in:d=0.6,afade=t=out:st=$FADE:d=2.5[mus];[sfx][mus]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[a]" \
    -map 0:v -map "[a]" -t "$DUR" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$OUT"
echo "wrote $OUT ($DUR s)"
