ffmpeg -i "$1" -vcodec libx265 -vf "scale=768:432" -map 0:v:0 -map 0:a:1 "${1%.mkv}.mp4"
