#!/usr/bin/env python3

import argparse
import sys
import json
from datetime import datetime

def main():
    parser = argparse.ArgumentParser(usage=f'''
pass a picodata audit file name as argument:

    {sys.argv[0]} path/to/audit.log

or pipe in picodata audit stream on stdin:

    cat path/to/audit.log | {sys.argv[0]}

specify output file with `-o`

''')
    parser.add_argument('filename', nargs='?')
    parser.add_argument('-o', '--output')
    args = parser.parse_args()

    if args.output is None or args.output == '-':
        output = sys.stdout
    else:
        output = open(args.output, 'w')

    if args.filename:
        with open(args.filename, 'r') as f:
            input = f.read()
    elif not sys.stdin.isatty():
        input = sys.stdin.read()
    else:
        parser.print_usage()
        sys.exit(1)

    for line in input.splitlines():
        data = json.loads(line)
        id = data.pop('id')
        title = data.pop('title')
        message = data.pop('message')
        severity = data.pop('severity')
        timestamp = datetime.strptime(data.pop('time'), '%Y-%m-%dT%H:%M:%S.%f%z')
        timestamp = timestamp.strftime('%Y-%m-%d %H:%M:%S.%f')
        if severity == "low":
            level = "I"
        elif severity == "medium":
            level = "W"
        elif severity == "high":
            level = "E"
        else:
            level = severity
        extra = " " + json.dumps(data) if data else ""
        print(f'{timestamp} {id} {level}> {title}: {message}{extra}', file=output)


if __name__ == "__main__":
    main()
