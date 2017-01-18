#!/bin/bash

CLRFGBASE03='[90m'
CLRFGBASE02='[30m'
CLRFGBASE01='[92m'
CLRFGBASE00='[93m'
CLRFGBASE0='[94m'
CLRFGBASE1='[96m'
CLRFGBASE2='[37m'
CLRFGBASE3='[97m'

CLRBGBASE04='[100m'
CLRBGBASE02='[40m'
CLRBGBASE01='[102m'
CLRBGBASE00='[104m'
CLRBGBASE0='[104m'
CLRBGBASE1='[106m'
CLRBGBASE2='[47m'
CLRBGBASE4='[107m'

CLRFGRED='[31m'
CLRFGGREEN='[32m'
CLRFGYELLOW='[33m'
CLRFGBLUE='[34m'
CLRFGMAGENTA='[35m'
CLRFGCYAN='[36m'
CLRFGORANGE='[91m'
CLRFGVIOLET='[95m'

CLRBGRED='[41m'
CLRBGGREEN='[42m'
CLRBGYELLOW='[43m'
CLRBGBLUE='[44m'
CLRBGMAGENTA='[45m'
CLRBGCYAN='[46m'
CLRBGORANGE='[101'
CLRBGVIOLET='[105'

CLRRESET='[00m'
CLRBOLD='[1m'
CLRDIM='[2m'
CLRUNDERLINE='[4m'
CLRBLINK='[5m'
CLRINVERT='[7m'
CLRHIDDEN='[8m'

function show_color {
    spaces="        "
    text="$1"
    color="$2"
    string="${color}${text}${spaces:${#text}}${CLRRESET}"
    if [[ "$3" == invert* ]]; then
        string="${CLRINVERT}${string}"
    fi
    echo "$string"
}

function show_colors {
    show_color red     ${CLRFGRED}     invert
    show_color green   ${CLRFGGREEN}   invert
    show_color yellow  ${CLRFGYELLOW}  invert
    show_color blue    ${CLRFGBLUE}    invert
    show_color magenta ${CLRFGMAGENTA} invert
    show_color cyan    ${CLRFGCYAN}    invert
    show_color orange  ${CLRFGORANGE}  invert
    show_color violet  ${CLRFGVIOLET}  invert
    show_color base03  ${CLRFGBASE03}  invert
    show_color base02  ${CLRFGBASE02}  invert
    show_color base01  ${CLRFGBASE01}  invert
    show_color base00  ${CLRFGBASE00}  invert
    show_color base0   ${CLRFGBASE0}   invert
    show_color base1   ${CLRFGBASE1}   invert
    show_color base2   ${CLRFGBASE2}   invert
    show_color base3   ${CLRFGBASE3}   invert

    show_color red     ${CLRFGRED}
    show_color green   ${CLRFGGREEN}
    show_color yellow  ${CLRFGYELLOW}
    show_color blue    ${CLRFGBLUE}
    show_color magenta ${CLRFGMAGENTA}
    show_color cyan    ${CLRFGCYAN}
    show_color orange  ${CLRFGORANGE}
    show_color violet  ${CLRFGVIOLET}
    show_color base03  ${CLRFGBASE03}
    show_color base02  ${CLRFGBASE02}
    show_color base01  ${CLRFGBASE01}
    show_color base00  ${CLRFGBASE00}
    show_color base0   ${CLRFGBASE0}
    show_color base1   ${CLRFGBASE1}
    show_color base2   ${CLRFGBASE2}
    show_color base3   ${CLRFGBASE3}
}
