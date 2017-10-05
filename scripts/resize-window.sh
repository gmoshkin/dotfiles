#!/bin/bash

width=${1:-80}
height=${2:-30}
xdotool getwindowfocus windowsize --usehints --sync $width $height
