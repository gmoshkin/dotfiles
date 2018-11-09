#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import shlex
import datetime
import re

def parse_args():
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('input')
    arg_parser.add_argument('description', nargs='*')
    arg_parser.add_argument('-s', '--start')
    duration_args = arg_parser.add_mutually_exclusive_group()
    duration_args.add_argument('-e', '--end')
    duration_args.add_argument('-d', '--duration')
    arg_parser.add_argument('--strict', default='-2')
    arg_parser.add_argument('-q', '--quality', default='15')
    return arg_parser.parse_args()

def add_arg(flag, value):
    if not value:
        return []
    return [flag, str(value)]

def parse_time(time):
    if not time:
        return 0
    seconds = 0
    try:
        for piece in time.split(':'):
            seconds = seconds * 60 + int(piece)
        return seconds
    except ValueError:
        raise Exception("unknown time format '{}'".format(time))

def time_diff(start, end):
    if not end:
        return None
    diff = parse_time(end) - parse_time(start)
    if isinstance(diff, datetime.timedelta):
        return int(diff.total_seconds())
    return diff

file_pattern = r'r6s-(?P<date>\d\d\d\d.\d\d.\d\d)-\d\d(?:\.\d\d){3}-(?P<descr>.*)-UNTRIMMED.mp4'

def gen_output(input, descr):
    if isinstance(descr, list):
        descr = '-'.join(descr)
    m = re.match(file_pattern, input)
    if not m:
        return descr
    if not descr:
        descr = m.group('descr').split('@')[0]
    return 'r6s-{date}-{descr}.mp4'.format(date=m.group('date'),
                                           descr=descr)


def main(args):
    cmd = (
        ['ffmpeg'] + add_arg('-i', args.input) + add_arg('-ss', args.start) +
        add_arg('-t', args.duration) + add_arg('-t', time_diff(args.start,
                                                               args.end)) +
        add_arg('-strict', args.strict) + add_arg('-crf', args.quality) +
        [gen_output(args.input, args.description)]
    )
    print(' '.join(shlex.quote(arg) for arg in cmd))

if __name__ == '__main__':
    main(parse_args())
