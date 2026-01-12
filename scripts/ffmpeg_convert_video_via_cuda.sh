/mnt/d/tools/ffmpeg-2025-08-04-git-9a32b86307-full_build/bin/ffmpeg.exe \
    -hwaccel cuda \
    -hwaccel_output_format cuda \
    -i "$1" \
    -vf "scale_cuda=1024:464" \
    -map 0:v:0 -c:v hevc_nvenc \
    -map 0:a:1 \
    -map 0:s:0 -c:s mov_text \
    -ac 2 \
    "$2"
