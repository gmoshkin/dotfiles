#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pymouse import PyMouse
from pyscreenshot import grab

def rgb2hex(rgb):
    return '#{:06x}'.format(rgb[0] * 2**16 + rgb[1] * 2 ** 8  + rgb[2])

def show_color(rgb):
    r, g, b = rgb
    print('\033[90m\033[48;2;{r};{g};{b}m{hex}\033[0m'.format(r=r, g=g, b=b,
                                                              hex=rgb2hex(rgb)))

if __name__ == '__main__':
    show_color(grab().getpixel(PyMouse().position()))
