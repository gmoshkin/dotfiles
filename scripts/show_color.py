#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re

def rgb2hex(rgb):
    return '#{:06x}'.format(rgb[0] * 2**16 + rgb[1] * 2 ** 8  + rgb[2])

def hex2rgb(hex):
    m = re.match(r'#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})', hex,
                 re.IGNORECASE)
    return tuple(int(c, base=16) for c in m.groups())

def show_color(rgb):
    r, g, b = rgb
    print('\033[90m\033[48;2;{r};{g};{b}m{hex}\033[0m'.format(r=r, g=g, b=b,
                                                              hex=rgb2hex(rgb)))

if __name__ == '__main__':
    if len(sys.argv) > 1:
        show_color(hex2rgb(sys.argv[1]))
    else:
        from pymouse import PyMouse
        from pyscreenshot import grab
        show_color(grab().getpixel(PyMouse().position()))
