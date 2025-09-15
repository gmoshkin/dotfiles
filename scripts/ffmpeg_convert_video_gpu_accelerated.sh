set -e

convert() {
    VIDEO_TRACK=0
    AUDIO_TRACK=8
    SUBTITLE_TRACK=1
    path/to/ffmpeg.exe \
        -hwaccel cuda \
        -hwaccel_output_format cuda \
        -i "$1" \
        -map 0:v:0 -c:v hevc_nvenc \
        -map 0:a:8 \
        -map 0:s:1 -c:s mov_text \
        -ac 2 \
        "$2"
}
