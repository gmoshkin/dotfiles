#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import termbox
from random import randint
from itertools import zip_longest

class PixelScreen:
    bottom_half = 0x2584 # '▄'
    full = 0x2588 # '█'
    empty = 0x20 # ' '

    def __init__(self, width=None, height=None):
        self.width = width or None
        self.height = height or None
        if self.width and self.height:
            self.cells = [
                [termbox.DEFAULT] * self.width for y in range(self.height)
            ]

    def display(self, tb):
        def grouper(iterable, n, fillvalue=None):
            args = [iter(iterable)] * n
            return zip_longest(*args, fillvalue=fillvalue)

        for y, line_group in enumerate(grouper(self.cells, 2, [])):
            pixel_line = []
            if y > tb.height():
                break
            for x, (top, bot) in enumerate(zip(*line_group)):
                if x > tb.width():
                    break
                if bot == termbox.DEFAULT:
                    if bot == top:
                        tb.change_cell(x, y, self.empty, bot, top)
                    else:
                        tb.change_cell(x, y, self.bottom_half,
                                       top | termbox.REVERSE, bot)
                else:
                    tb.change_cell(x, y, self.bottom_half, bot, top)

    def resize(self, width=None, height=None):
        old_width = self.width
        old_height = self.height
        self.width = width or self.width
        self.height = height or self.height
        if self.width > old_width:
            for row in self.cells:
                row.extend([termbox.DEFAULT] * (self.width - old_width))
        if self.height > old_height:
            self.cells.extend([
                [termbox.DEFAULT] * self.width for y in range(self.height - old_height)
            ])


def random_dots(t):
    t.clear()
    t.present()
    width = t.width()
    height = t.height()
    # cells = [ [ termbox.DEFAULT for _ in range(width) ] for __ in range(height) ]
    ps = PixelScreen(width, height * 2)
    colors = [
        termbox.BLACK,
        termbox.RED,
        termbox.GREEN,
        termbox.YELLOW,
        termbox.BLUE,
        termbox.MAGENTA,
        termbox.CYAN,
        termbox.WHITE,
    ]
    run_app = True
    while run_app:
        event_here = t.peek_event(timeout=1000)
        while event_here:
            (type, ch, key, mod, w, h, x, y) = event_here
            if type == termbox.EVENT_KEY and key == termbox.KEY_ESC:
                run_app = False
            if type == termbox.EVENT_RESIZE:
                ps.resize(width=w, height=h * 2)
            event_here = t.peek_event()
        new_x = randint(0, ps.width - 1)
        new_y = randint(0, ps.height - 1)
        new_color = colors[randint(0, len(colors) - 1)]
        ps.cells[new_y][new_x] = new_color
        t.clear()
        ps.display(t)
        # t.change_cell(new_x, new_y, ord(' '), termbox.DEFAULT, new_color)
        # cells[new_y][new_x] = new_color
        # t.clear()
        # for y, row in enumerate(cells):
        #     for x, c in enumerate(row):
        #         t.change_cell(x, y, ord(' '), termbox.DEFAULT, c)
        t.present()

with termbox.Termbox() as t:
    random_dots(t)
    # t.clear()
    # t.present()
    # ps = PixelScreen(t.width(), t.height() * 2)
    # ps.cells[1][1] = termbox.RED
    # ps.cells[0][1] = termbox.CYAN
    # ps.cells[1][0] = termbox.MAGENTA
    # ps.cells[0][0] = termbox.GREEN
    # ps.cells[2][2] = termbox.BLUE
    # ps.display(t)
    # t.present()
    # t.peek_event(timeout=1000)
