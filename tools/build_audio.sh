#!/bin/sh
# Пересоздаёт все звуки и перекодирует короткие wav в ogg (экономия места для веб-сборки).
cd "$(dirname "$0")" || exit 1
python3 gen_audio.py && python3 gen_audio2.py || exit 1
cd ../assets/audio || exit 1
[ -f music_tavern.ogg ] && mv music_tavern.ogg music/tavern_day.ogg
for f in $(find . -name "*.wav"); do
  ffmpeg -y -loglevel error -i "$f" -c:a libvorbis -q:a 3 "${f%.wav}.ogg" && rm "$f"
done
