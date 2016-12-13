#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys

class Color:
    Reset   = "[00m"
    Black   = "[30m"
    Red     = "[31m"
    Green   = "[32m"
    Yellow  = "[33m"
    Blue    = "[34m"
    Magenta = "[35m"
    Cyan    = "[36m"
    White1  = "[37m"
    Orange  = "[91m"
    Gray01  = "[92m"
    Gray02  = "[93m"
    Gray03  = "[94m"
    Purple  = "[95m"
    Gray04  = "[96m"
    White2  = "[97m"

width = int(sys.argv[1])
username = sys.argv[2]
hostname = sys.argv[3]
pwd = sys.argv[4]
date = ' '.join(sys.argv[5:])

sep_color = Color.Reset
pwd_color = Color.Blue
uname_color = Color.Green
hname_color = Color.Yellow
date_color = Color.Green
colon_color = Color.Reset
dollar_color = Color.Reset
reset_color = Color.Reset

left = ''.join([
    sep_color, "╭", "(",
    uname_color, username, "@",
    hname_color, hostname,
    colon_color, ":",
    pwd_color, pwd,
    sep_color, ")",
])
right = ''.join([
    sep_color, "(",
    date_color, date,
    sep_color, ")"
])

filler_width = width
filler_width -= len(left.decode("utf-8"))
filler_width -= len(right.decode("utf-8"))
filler_width += 9 * len(Color.Reset)
filler = sep_color + "─" * filler_width

prompt = ''.join([
    sep_color, "╰",
    dollar_color, "$",
    reset_color
])

status_line = left + filler + right
prompt_line = prompt

print(status_line)
print(prompt_line)
# ╭(mgn@tsar:/home/mgn)───────────────────────────────────(Вт 13 дек 2016 18:55)
# ╰$
