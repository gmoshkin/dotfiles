# `-ac 2` converts audio to stereo (it could originally be 6 channels or some shit like that)
# `-map 0:v:0` use only the first video stream (start at 0)
# `-map 0:a:1` use only the second audio stream (start at 0)
# `-vf "scale=768:432"` rescale video to given resolution
ffmpeg -i "$1" -vcodec libx265 -vf "scale=768:432" -map 0:v:0 -map 0:a:1 -ac 2 "${1%.mkv}.mp4"
