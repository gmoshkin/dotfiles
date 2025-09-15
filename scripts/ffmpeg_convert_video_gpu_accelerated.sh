set -e

convert() {
    VIDEO_TRACK=0
    AUDIO_TRACK=8
    SUBTITLE_TRACK=1
    path/to/ffmpeg.exe \
        -hwaccel cuda \
        -hwaccel_output_format cuda \
        -i "$1" \
        -map "0:v:$VIDEO_TRACK" -c:v hevc_nvenc \
        -map "0:a:$AUDIO_TRACK" \
        -map "0:s:$SUBTITLE_TRACK" -c:s mov_text \
        -ac 2 \
        "$2"
}
