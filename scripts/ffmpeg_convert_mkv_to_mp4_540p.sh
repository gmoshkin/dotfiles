convert() {
    ffmpeg -i "$1" -vcodec libx265 -vf "scale=960:540" -map 0:v:0 -map 0:a:1 "${1%.mkv}.mp4"
}
