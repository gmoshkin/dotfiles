#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import yaml
import os
import datetime
import argparse

arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('-c', '--config',
                        default=os.path.expanduser('~/.config/alarms.yaml'))
arg_parser.add_argument('-p', '--preamble',
                        default='SHELL=/bin/bash')
arg_parser.add_argument('-r', '--command',
                        default='/usr/sbin/etherwake 9C:5C:8E:84:B6:33')
arg_parser.add_argument('-o', '--offset',
                        type=float, default=5)
args = arg_parser.parse_args()

with open(args.config) as f:
    days = yaml.load(f)

dow_map = {
    'mon' : 1,
    'tue' : 2,
    'wed' : 3,
    'thu' : 4,
    'fri' : 5,
    'sat' : 6,
    'sun' : 7,
    'all' : '*',
    'weekd' : '1,2,3,4,5',
    'weeke' : '6,7',
}
ofs = datetime.timedelta(seconds=args.offset*60)

def prepk(k):
    k = k.lower()
    if k[:4] == 'week':
        k = k[:5]
    else:
        k = k[:3]
    return k

def prepv(v):
    if isinstance(v, int):
        return '{}:{}'.format(v // 60, v % 60)
    else:
        return v

print(args.preamble)
for k, vs in days.items():
    dow = dow_map[prepk(k)]
    if not isinstance(vs, list):
        vs = [vs]
    for v in vs:
        time = datetime.datetime.strptime(prepv(v), '%H:%M')
        min_hour = (time - ofs).strftime('%M %H')
        print('{} * * {} {}'.format(min_hour, dow, args.command))
