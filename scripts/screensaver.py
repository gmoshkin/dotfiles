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

def get_ds(start, end):
    dx, dy = end[0] - start[0], start[1] - end[1]
    if dy >= 0:  # ↗
        if dx >= dy:  # major direction: →
            coord = 0
            dStraight = 2 * dy
            ofs = -1
            dDiag = dStraight - 2 * dx
            d0 = dStraight - dx
            step = 1
        else:         # major direction: ↑
            coord = 1
            dStraight = 2 * dx
            ofs = 1  # doesn't matter
            dDiag = dStraight - 2 * dy
            d0 = dStraight - dy
            step = 1
    else:  # ↘
        if dx >= -dy:  # major direction: →
            coord = 0
            dStraight = -2 * dy
            ofs = 1
            dDiag = dStraight - 2 * dx
            d0 = dStraight - dx
            step = 1
        else:         # major direction: ↓
            coord = 1
            dStraight = -2 * dx
            ofs = 1  # doesn't matter
            dDiag = dStraight - 2 * dy
            d0 = dStraight - dy
            step = -1
    return dx, dy, coord, dStraight, dDiag, d0, ofs, step

def draw_line(screen, start, end, color):
    if start[0] > end[0]:
        start, end = end, start
    dx, dy, coord, dStraight, dDiag, d, ofs, step = get_ds(start, end)
    # if dy > dx:
    #     screen.cells[start[1]][start[0]] = color
    #     screen.cells[end[1]][end[0]] = color
    #     return {}
    screen.cells[start[1]][start[0]] = termbox.WHITE
    screen.cells[end[1]][end[0]] = termbox.WHITE

    j = start[1 - coord]
    for i in range(start[coord], end[coord] + 1, step):
        if coord:
            screen.cells[i][j] = color
        else:
            screen.cells[j][i] = color
        if d > 0:
            j += ofs
            d += dDiag
        else:
            d += dStraight
    return {
        'dx' : dx,
        'dy' : dy,
        'dStraight' : dStraight,
        'dDiag' : dDiag,
        'range' : list(range(start[0], end[0] + 1)),
    }


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

def draw_dir(screen, start, direction, color):
    end = start[0] + direction[0], start[1] + direction[1]
    return draw_line(screen, start, end, color)

debug = None

def draw_for_a_sec(t, screen, foo, timeout=1):
    foo(screen)
    screen.display(t)
    t.present()
    if timeout > 0:
        t.peek_event(timeout=timeout * 1000)
    else:
        t.poll_event()

with termbox.Termbox() as t:
    # random_dots(t)
    t.clear()
    t.present()
    ps = PixelScreen(t.width(), t.height() * 2)
    ps.cells[1][1] = termbox.RED
    ps.cells[0][1] = termbox.CYAN
    ps.cells[1][0] = termbox.MAGENTA
    ps.cells[0][0] = termbox.GREEN
    ps.cells[2][2] = termbox.BLUE
    # draw_dir(ps, (0, 50), (25, -25), termbox.BLUE)
    draw_for_a_sec(t, ps,
                   lambda ps:draw_dir(ps, (0, 50), (25, -25), termbox.BLUE),
                   timeout=-1)
    draw_for_a_sec(t, ps,
                   lambda ps: draw_dir(ps, (0, 25), (25, 25), termbox.RED),
                   timeout=-1)
    draw_for_a_sec(t, ps,
                   lambda ps: draw_dir(ps, (25, 50), (10, -25), termbox.GREEN),
                   timeout=-1)
    draw_for_a_sec(t, ps,
                   lambda ps: draw_dir(ps, (25, 25), (10, 25), termbox.YELLOW),
                   timeout=-1)
    # draw_dir(ps, (25, 25), (25, 25), termbox.RED)
    # for i in range(16):
    #     draw_dir(ps, (2 + i*25, 50), (25, -25 + 2* i), termbox.DEFAULT + i)
    #     ps.display(t)
    #     t.present()
    #     t.peek_event(timeout=1000)

if debug:
    for k, v in debug.items():
        print(k, v)

print(get_ds((00, 10), (10, -1)))
print(get_ds((00, 10), (10, 0)))
print(get_ds((00, 10), (10, 1)))
print(get_ds((00, 10), (10, 9)))
print(get_ds((00, 10), (10, 10)))
print(get_ds((00, 10), (10, 11)))
print(get_ds((25, 50), (35, 25)))
print(get_ds((25, 25), (35, 50)))
