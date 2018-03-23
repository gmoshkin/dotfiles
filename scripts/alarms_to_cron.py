#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from ruamel import yaml
import os
import datetime

preamble = 'SHELL=/bin/bash'
command = '/usr/sbin/etherwake 9C:5C:8E:84:B6:33'

with open(os.path.expanduser('~/.config/alarms.yaml')) as f:
    days = yaml.load(f, Loader=yaml.RoundTripLoader)

dow_map = {
    'mon' : 1,
    'tue' : 2,
    'wed' : 3,
    'thu' : 4,
    'fri' : 5,
    'sat' : 6,
    'sun' : 7,
    'all' : '*'
}
_5min = datetime.timedelta(seconds=5*60)
print(preamble)
for k, vs in days.items():
    dow = dow_map[k.lower()[:3]]
    if not isinstance(vs, list):
        vs = [vs]
    for v in vs:
        time = datetime.datetime.strptime(v, '%H:%M')
        min_hour = (time - _5min).strftime('%M %H')
        print('{} * * {} {}'.format(min_hour, dow, command))
