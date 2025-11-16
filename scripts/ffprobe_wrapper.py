#!/usr/bin/env python3

import json
import subprocess
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(usage=f'''
pass a video file name as argument:

    {sys.argv[0]} video.mkv

or pipe in json output of ffprobe on stdin:

    ffprobe -v quiet -of json -show_streams video.mkv | {sys.argv[0]}

''')
    parser.add_argument('filename', nargs='?')
    args = parser.parse_args()

    ffprobe_output = None
    if args.filename:
        ffprobe_output = run_ffprobe(args.filename)
    elif not sys.stdin.isatty():
        ffprobe_output = sys.stdin.buffer.read()
    else:
        parser.print_usage()
        sys.exit(1)

    data = json.loads(ffprobe_output)
    streams = data['streams']
    count_by_type = dict()
    table = []
    for i, stream in enumerate(streams):
        row = []

        type = stream['codec_type']
        count = count_by_type.get(type, 0)
        count_by_type[type] = count + 1

        codec_name = stream['codec_long_name']
        width = stream.get('width')
        height = stream.get('height')

        duration = stream.get('duration')
        tags = stream['tags']
        if not duration:
            duration = tags.get('duration') or tags.get('DURATION')

        language = tags.get('language')

        channel_layout = stream.get('channel_layout')

        # column type
        row.append(f'{type} #{count}')
        # column language
        row.append(language or '')

        # column extra info
        if channel_layout:
            row.append(channel_layout)
        elif width:
            row.append(f'{width}x{height}')
        else:
            row.append('')

        # column duration
        if duration:
            t = None
            if ':' in duration:
                t = parse_duration(duration)

            try:
                t = float(duration)
            except ValueError:
                pass

            if t is not None:
                duration = pretty_duration(t)

            row.append(duration)
        else:
            row.append('')

        # column codec name
        row.append(codec_name)
        table.append(row)

    column_widths = []
    for row in table:
        if len(column_widths) == 0:
            column_widths = [len(c) for c in row]
            continue

        assert len(column_widths) == len(row)
        for i in range(len(row)):
            l = len(row[i] or '')
            if l > column_widths[i]:
                column_widths[i] = l

    type_len, lang_len, extra_len, duration_len, codec_len = column_widths
    for row in table:
        builder = []
        type, lang, extra, duration, codec = row

        builder.append(type)
        builder.append(' ' * (type_len - len(type)))
        builder.append('  ')

        builder.append(lang)
        builder.append(' ' * (lang_len - len(lang)))
        builder.append('  ')

        builder.append(extra)
        builder.append(' ' * (extra_len - len(extra)))
        builder.append('  ')

        builder.append(duration)
        builder.append(' ' * (duration_len - len(duration)))
        builder.append('  ')

        builder.append(codec)
        builder.append(' ' * (codec_len - len(codec)))

        print(''.join(builder))



def run_ffprobe(input_file: str) -> bytes:
    output = subprocess.check_output(["ffprobe", "-v", "quiet", "-of", "json", "-show_streams", input_file])
    return output

def parse_duration(s: str) -> 'float | None':
    parts = s.split(':')
    if len(parts) != 3:
        return None

    hours, minutes, seconds = parts

    try:
        hours = int(hours)
    except ValueError:
        return None

    try:
        minutes = int(minutes)
    except ValueError:
        return None

    try:
        seconds = float(seconds)
    except ValueError:
        return None

    return hours * 3600 + minutes * 60 + seconds


def pretty_duration(d):
    minutes, seconds = divmod(d, 60)
    if minutes == 0:
        if seconds >= 0.001:
            return f'{seconds:.3f}s'
        elif seconds >= 0.000001:
            return f'{seconds:.6f}s'
        else:
            return f'{seconds:.9f}s'

    hours, minutes = divmod(int(minutes), 60)
    if hours == 0:
        return f'{minutes:02}:{seconds:06.3f}'
    else:
        return f'{hours:02}:{minutes:02}:{seconds:06.3f}'


if __name__ == '__main__':
    main()
