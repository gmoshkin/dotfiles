#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from subprocess import check_output, call
from sys import argv, exit
from re import match

default_ofs = 10

current = float(check_output(['xbacklight', '-get']))
out_of_10 = round(current / 10)

if len(argv) < 2:
    print(int(round(current)))
    exit(0)

m = match(r'(?P<sign>[-+]?)(?P<number>[0-9]*)', argv[1])
if not m.group(0):
    print(int(round(current)))
    exit(0)

number = default_ofs if not m.group('number') else float(m.group('number'))

actions = {
    '' : lambda n: n / 10,
    '-' : lambda n: out_of_10 - n / 10,
    '+' : lambda n: out_of_10 + n / 10
}
new = int(round(actions[m.group('sign')](number)) * 10) + 1

call(['xbacklight', '-set', str(new)])
