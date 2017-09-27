ffmpeg -y -f x11grab -s 100x100 -i :0.0+0,900 -pix_fmt rgb24 -r 5 ~/capture.gif
