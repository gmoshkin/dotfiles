#!/bin/bash

# name     hex         r   g   b   32bit integer
# base03:  #002b36     0  43  54   -16766154
# base02:  #073642     7  54  66   -16304574
# base01:  #586e75    88 110 117   -10981771
# base00:  #657b83   101 123 131   -10126461
# base0:   #839496   131 148 150    -8153962
# base1:   #93a1a1   147 161 161    -7102047
# base2:   #eee8d5   238 232 213    -1120043
# base3:   #fdf6e3   253 246 227     -133405
# yellow:  #b58900   181 137   0    -4880128
# orange:  #cb4b16   203  75  22    -3454186
# red:     #dc322f   220  50  47    -2346449
# magenta: #d33682   211  54 130    -2935166
# violet:  #6c71c4   108 113 196    -9670204
# blue:    #268bd2    38 139 210   -14251054
# cyan:    #2aa198    42 161 152   -13983336
# green:   #859900   133 153   0    -8021760

CLRFGBASE03='[90m'
CLRFGBASE02='[30m'
CLRFGBASE01='[92m'
CLRFGBASE00='[93m'
CLRFGBASE0='[94m'
CLRFGBASE1='[96m'
CLRFGBASE2='[37m'
CLRFGBASE3='[97m'

CLRBGBASE03='[100m'
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
CLRBGORANGE='[101m'
CLRBGVIOLET='[105m'

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
    show_color orange  ${CLRFGORANGE}  invert
    show_color yellow  ${CLRFGYELLOW}  invert
    show_color green   ${CLRFGGREEN}   invert
    show_color cyan    ${CLRFGCYAN}    invert
    show_color blue    ${CLRFGBLUE}    invert
    show_color violet  ${CLRFGVIOLET}  invert
    show_color magenta ${CLRFGMAGENTA} invert
    show_color base03  ${CLRFGBASE03}  invert
    show_color base02  ${CLRFGBASE02}  invert
    show_color base01  ${CLRFGBASE01}  invert
    show_color base00  ${CLRFGBASE00}  invert
    show_color base0   ${CLRFGBASE0}   invert
    show_color base1   ${CLRFGBASE1}   invert
    show_color base2   ${CLRFGBASE2}   invert
    show_color base3   ${CLRFGBASE3}   invert

    # show_color red     ${CLRBGRED}
    # show_color orange  ${CLRBGORANGE}
    # show_color yellow  ${CLRBGYELLOW}
    # show_color green   ${CLRBGGREEN}
    # show_color cyan    ${CLRBGCYAN}
    # show_color blue    ${CLRBGBLUE}
    # show_color violet  ${CLRBGVIOLET}
    # show_color magenta ${CLRBGMAGENTA}
    # show_color base03  ${CLRBGBASE03}
    # show_color base02  ${CLRBGBASE02}
    # show_color base01  ${CLRBGBASE01}
    # show_color base00  ${CLRBGBASE00}
    # show_color base0   ${CLRBGBASE0}
    # show_color base1   ${CLRBGBASE1}
    # show_color base2   ${CLRBGBASE2}
    # show_color base3   ${CLRBGBASE3}

    show_color red     ${CLRFGRED}
    show_color orange  ${CLRFGORANGE}
    show_color yellow  ${CLRFGYELLOW}
    show_color green   ${CLRFGGREEN}
    show_color cyan    ${CLRFGCYAN}
    show_color blue    ${CLRFGBLUE}
    show_color violet  ${CLRFGVIOLET}
    show_color magenta ${CLRFGMAGENTA}
    show_color base03  ${CLRFGBASE03}
    show_color base02  ${CLRFGBASE02}
    show_color base01  ${CLRFGBASE01}
    show_color base00  ${CLRFGBASE00}
    show_color base0   ${CLRFGBASE0}
    show_color base1   ${CLRFGBASE1}
    show_color base2   ${CLRFGBASE2}
    show_color base3   ${CLRFGBASE3}
}
