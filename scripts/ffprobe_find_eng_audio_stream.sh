ffprobe -v quiet -of json -show_streams "$1" < /dev/null |
    jq '.streams[]|select(.codec_type == "audio")|.tags.language' |
    nl -v0 |
    grep eng
