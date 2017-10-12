#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from argparse import ArgumentParser
from itertools import zip_longest
import math
import os
from PIL import Image

def parse_args():
    descr="Convert a text file into a braille image"
    arg_parser = ArgumentParser(description=descr)
    arg_parser.add_argument("filename")
    arg_parser.add_argument("--scale", "-s",
                            help="Scale the image by a factor",
                            type=float)
    arg_parser.add_argument("--threshold", "-t",
                            help="Alpha threshold",
                            type=int,
                            default=10)
    arg_parser.add_argument("--format", "-f",
                            choices=['braille', 'pixels'],
                            default='braille')
    args = arg_parser.parse_args()
    return args

def grouper(iterable, n, fillvalue=None):
    args = [iter(iterable)] * n
    return zip_longest(*args, fillvalue=fillvalue)

def to_braille(iterable, is_visible, default):
    braille_empty = 0x2800
    braille_cells = [
        [0x1, 0x8],
        [0x2, 0x10],
        [0x4, 0x20],
        [0x40, 0x80],
    ]
    result = []
    for line_group in grouper(iterable, 4, []):
        max_len = max(len(l) for l in line_group)
        braille_line = [ braille_empty ] * math.ceil(max_len / 2)
        for i, line in enumerate(line_group):
            for braille_j, pair in enumerate(grouper(line, 2, default)):
                for j, c in enumerate(pair):
                    if is_visible(c):
                        braille_line[braille_j] += braille_cells[i][j]
        result.append(braille_line)
        print(''.join([chr(c) for c in braille_line]))

def to_pixels(iterable, is_visible, default):
    pixels_empty = ' '
    pixels_top = '\u2580'
    pixels_bottom = '\u2584'
    pixels_full = '\u2588'
    cell_states = [
        [pixels_empty, pixels_bottom],
        [pixels_top, pixels_full],
    ]
    result = []
    for line_group in grouper(iterable, 2, []):
        pixel_line = []
        for top, bottom in zip(*line_group):
            pixel_line.append(cell_states[is_visible(top)][is_visible(bottom)])
        result.append(pixel_line)
        print(''.join(pixel_line))

def scale(image, ratio):
    old_size = image.size
    new_size = tuple(math.ceil(old * ratio) for old in old_size)
    return image.resize((new_size), Image.ANTIALIAS)

def main():
    args = parse_args()
    filename = args.filename
    converters = {
        "braille" : to_braille,
        "pixels" : to_pixels,
    }
    convert = converters[args.format]
    if os.path.splitext(filename)[1] == '.png':
        image = Image.open(filename)
        if args.scale:
            image = scale(image, args.scale)
        width = image.size[0]
        default = (0, 0, 0, 0)
        threshold = args.threshold
        convert(grouper(image.getdata(), width, default),
                lambda x: x[3] > threshold,
                default)
    else:
        with open(filename, 'r') as f:
            convert(f, lambda x: not x.isspace(), default=' ')


if __name__ == "__main__":
    main()
