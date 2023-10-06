set -e

INPUT_VIDEO=${INPUT_VIDEO:-PLACEHOLDER}
OUTPUT_VIDEO=${OUTPUT_VIDEO:-out.webm}
ORIG_SIZE=${ORIG_SIZE:-384}
OUT_SIZE=${OUT_SIZE:-100}

mkdir /tmp/frames-orig
ffmpeg -r 1 -i "$INPUT_VIDEO" -r 1 /tmp/frames-orig/frame-%03d.png

RADIUS=$((ORIG_SIZE / 2))
convert \
    -size ${ORIG_SIZE}x${ORIG_SIZE} \
    xc:Black \
    -fill White \
    -draw "circle $RADIUS,$RADIUS $RADIUS,0" \
    -alpha Copy \
    /tmp/mask.png

mkdir /tmp/frames-cropped
for f in $(ls /tmp/frames-orig/*); do
    convert $f \
        -gravity Center \
        mask.png \
        -compose CopyOpacity \
        -composite \
        -trim \
        -resize ${OUT_SIZE}x${OUT_SIZE} \
        /tmp/frames-cropped/$(basename $f)
done

ffmpeg \
    -framerate 40 \
    -pattern_type glob \
    -i '/tmp/frames-cropped/*.png' \
    -c:v libvpx-vp9 \
    "$OUTPUT_VIDEO"

set +e # just in case this file get's sourced
