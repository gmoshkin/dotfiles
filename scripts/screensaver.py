#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import termbox
from random import randint, random
from math import pi, sin, cos
from itertools import zip_longest
from argparse import ArgumentParser

def parse_args():
    arg_parser = ArgumentParser(description='TODO')
    arg_parser.add_argument('mode')
    return arg_parser.parse_args().mode

class PixelScreen:
    bottom_half = 0x2584  # '▄'
    full = 0x2588  # '█'
    empty = 0x20  # ' '

    def __init__(self, width=None, height=None):
        self.width = width or None
        self.height = height or None
        if self.width and self.height:
            self.clear()

    def put_cell(self, point, color):
        x, y = point
        if self.height > y and self.width > x:
            self.cells[y][x] = color

    def display(self, tb):
        def grouper(iterable, n, fillvalue=None):
            args = [iter(iterable)] * n
            return zip_longest(*args, fillvalue=fillvalue)

        for y, line_group in enumerate(grouper(self.cells, 2, [])):
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

    def clear(self):
        self.cells = [
            [termbox.DEFAULT] * self.width for y in range(self.height)
        ]

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
            step = -1
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
            dStraight = 2 * dx
            ofs = 1  # doesn't matter
            dDiag = dStraight + 2 * dy
            d0 = dStraight + dy
            step = 1
    return dx, dy, coord, dStraight, dDiag, d0, ofs, step

def draw_line(screen, start, end, color):
    if start[0] > end[0]:
        start, end = end, start
    if not screen:
        print(start, end)
    dx, dy, coord, dStraight, dDiag, d, ofs, step = get_ds(start, end)
    # if dy > dx:
    #     screen.cells[start[1]][start[0]] = color
    #     screen.cells[end[1]][end[0]] = color
    #     return {}
    if screen:
        screen.put_cell(start, termbox.WHITE)
        screen.put_cell(end, termbox.WHITE)

    j = start[1 - coord]
    if not screen:
        print('dx', 'dy', 'coord', 'dStraight', 'dDiag', 'd', 'ofs', 'step')
        print(dx, dy, coord, dStraight, dDiag, d, ofs, step)
        print('range', start[coord], end[coord] + step, step, ':',
              list(range(start[coord], end[coord] + step, step)))
    for i in range(start[coord], end[coord] + step, step):
        if screen:
            if coord:
                screen.put_cell((j, i), color)
            else:
                screen.put_cell((i, j), color)
        else:
            print ('xy'[coord], i, 'xy'[1-coord], j)
        if d > 0:
            j += ofs
            d += dDiag
        else:
            d += dStraight
        if not screen:
            print('d:', d)
    return {
        'dx' : dx,
        'dy' : dy,
        'dStraight' : dStraight,
        'dDiag' : dDiag,
        'range' : list(range(start[0], end[0] + 1)),
    }

def put_text(tb, position, text, fg=termbox.DEFAULT, bg=termbox.DEFAULT):
    x, y = position
    for i, c in enumerate(text):
        tb.change_cell(x + i, y, ord(c), fg, bg)

class App:

    def __init__(self, tb, fps=0):
        self.tb = tb
        self.width = tb.width()
        self.height = tb.height()
        if fps > 0:
            self.get_event = lambda: tb.peek_event(timeout=1000 / fps)
        else:
            self.get_event = lambda: tb.poll_event()
        self.quit_keys = [ termbox.KEY_ESC ]

    def handle_resize(self, w, h):
        self.width = w
        self.height = h

    def handle_key(self, ch, key, mod):
        for k in self.quit_keys:
            if ch == k or k == key:
                self.run_app = False

    def handle_mouse(self, x, y):
        pass

    def update(self):
        pass

    def display(self):
        message = 'Empty app'
        position = int(self.width / 2 - len(message) / 2), int(self.height / 2)
        put_text(self.tb, position, message, termbox.BLUE, termbox.DEFAULT)

    def run_loop(self):
        self.tb.clear()
        self.display()
        self.tb.present()
        self.run_app = True
        while self.run_app:
            event = self.get_event()
            while event:
                (kind, ch, key,  mod, w, h, x, y) = event
                {
                    termbox.EVENT_RESIZE: lambda: self.handle_resize(w, h),
                    termbox.EVENT_KEY: lambda: self.handle_key(ch, key, mod),
                    termbox.EVENT_MOUSE: lambda: self.handle_mouse(x, y),
                }[kind]()
                event = self.tb.peek_event()
            self.update()
            self.tb.clear()
            self.display()
            self.tb.present()

def random_circle_point(center, radius):
    angle = 2 * pi * random()
    x = center[0] + radius * cos(angle)
    y = center[1] + radius * sin(angle)
    return int(x), int(y)

def is_inside(circle, point):
    (cx, cy), r = circle
    x, y = point
    return (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2

def random_color():
    colors = [
        termbox.DEFAULT,
        termbox.BLACK,
        termbox.RED,
        termbox.GREEN,
        termbox.YELLOW,
        termbox.BLUE,
        termbox.MAGENTA,
        termbox.CYAN,
        termbox.WHITE,
    ]
    return colors[randint(0, len(colors) - 1)]

def random_rect_point(w, h):
    return randint(0, w - 1), randint(0, h - 1)

def random_rect_edge_point(w, h):
    frac = random()
    n = randint(0, 3)
    if n % 2:
        return int(w * frac), (h - 1) * (n // 2)
    else:
        return (w - 1) * (n // 2), int(h * frac)

def random_circle(w, h):
    c = randint(0, w - 1), randint(0, h - 1)
    r = randint(7, min(w, h) // 2)
    return c, r

class LinesScreenSaver(App):
    def __init__(self, tb, circle1=((20, 20), 15), circle2=((45, 50), 25),
                 color1=termbox.RED, color2=termbox.BLUE):
        super().__init__(tb, fps=1)
        self.quit_keys.append('q')
        self.lines = []
        self.height *=  2
        self.screen = PixelScreen(self.width, self.height)
        self.circle1 = circle1
        self.circle2 = circle2
        self.color1 = color1
        self.color2 = color2
        self.circle = ((self.width // 2, self.height // 2),
                        int(.45 * min(self.width, self.height)))
        self.color = random_color()

    def update(self):
        if len(self.lines) % 60 == 0:
            self.circle = random_circle(self.width, self.height)
            self.color = random_color()
        start = random_circle_point(*self.circle)
        end = random_circle_point(*self.circle)
        # start = random_rect_edge_point(self.width, self.height)
        # end = random_rect_edge_point(self.width, self.height)
        # color = random_color()
        # if is_inside(self.circle2, start) and is_inside(self.circle1, end):
            # color = self.color2
        self.lines.append((start, end, self.color))
        # self.lines.append((self.circle[0],
        #                    (self.circle[0][0] + self.circle[1],
        #                     self.circle[0][1]), color))

    def display(self):
        for l in self.lines:
            draw_line(self.screen, *l)
        self.screen.display(self.tb)
        put_text(self.tb, (0, 0), '{}'.format(self.circle))

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

class Line:
    def __init__(self, start, end, color):
        self.start = list(start)
        self.end = list(end)
        self.color = color

    def process_keys(self, ch, key, mod):
        what, coord, ofs = {
            's': (self.start, 1, +1),  # 'down'),
            'w': (self.start, 1, -1),  # 'up'),
            'd': (self.start, 0, +1),  # 'right'),
            'a': (self.start, 0, -1),  # 'left'),
            'j': (self.end, 1, +1),  # 'down'),
            'k': (self.end, 1, -1),  # 'up'),
            'l': (self.end, 0, +1),  # 'right'),
            'h': (self.end, 0, -1),  # 'left'),
        }[ch]
        what[coord] += ofs

    def draw(self, screen):
        draw_line(screen, self.start, self.end, self.color)


def line_control(t):
    ps = PixelScreen(t.width(), t.height() * 2)
    run_app = True
    line = Line((0, 0), (10, 10), termbox.BLUE)
    t.clear()
    line.draw(ps)
    ps.display(t)
    t.present()
    while run_app:
        event_here = t.poll_event()
        while event_here:
            (type, ch, key, mod, w, h, x, y) = event_here
            if type == termbox.EVENT_KEY:
                if key == termbox.KEY_ESC or ch == 'q':
                    run_app = False
                else:
                    line.process_keys(ch, key, mod)
            if type == termbox.EVENT_RESIZE:
                ps.resize(width=w, height=h * 2)
            event_here = t.peek_event()
        t.clear()
        ps.clear()
        line.draw(ps)
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

def draw_for_a_sec(t, screen, foo, timeout=1):
    foo(screen)
    screen.display(t)
    t.present()
    if timeout > 0:
        t.peek_event(timeout=timeout * 1000)
    else:
        t.poll_event()

def debug_draw_line(t):
    t.clear()
    t.present()
    ps = PixelScreen(t.width(), t.height() * 2)

    # ps.cells[1][1] = termbox.RED
    # ps.cells[0][1] = termbox.CYAN
    # ps.cells[1][0] = termbox.MAGENTA
    # ps.cells[0][0] = termbox.GREEN
    # ps.cells[2][2] = termbox.BLUE

    # # draw_dir(ps, (0, 50), (25, -25), termbox.BLUE)
    # draw_dir(ps, (0, 0), (10, 10), termbox.BLUE)
    # draw_dir(ps, (0, 10), (10, 0), termbox.MAGENTA)
    # draw_dir(ps, (0, 0), (9, 10), termbox.CYAN)
    # draw_dir(ps, (25, 25), (25, -25), termbox.BLUE)
    # draw_dir(ps, (50, 0), (25, 20), termbox.BLUE)
    # draw_dir(ps, (75, 25), (25, -20), termbox.BLUE)
    # draw_dir(ps, (100, 0), (25, 15), termbox.BLUE)
    # # draw_dir(ps, (125, 25), (25, -15), termbox.BLUE)

    draw_dir(ps, (0, 0), (10, 7), termbox.BLUE)
    draw_dir(ps, (11, 7), (10, -7), termbox.RED)
    draw_dir(ps, (0, 8), (7, 10), termbox.GREEN)
    draw_dir(ps, (0, 29), (7, -10), termbox.MAGENTA)

    ps.display(t)
    t.present()
    t.poll_event()

    # draw_for_a_sec(t, ps,
    #                lambda ps:draw_dir(ps, (0, 50), (25, -25), termbox.BLUE),
    #                timeout=-1)
    # draw_for_a_sec(t, ps,
    #                lambda ps: draw_dir(ps, (0, 25), (25, 25), termbox.RED),
    #                timeout=-1)
    # draw_for_a_sec(t, ps,
    #                lambda ps: draw_dir(ps, (25, 50), (10, -25), termbox.GREEN),
    #                timeout=-1)
    # draw_for_a_sec(t, ps,
    #                lambda ps: draw_dir(ps, (25, 25), (10, 25), termbox.YELLOW),
    #                timeout=-1)

    # draw_dir(ps, (25, 25), (25, 25), termbox.RED)
    # for i in range(16):
    #     draw_dir(ps, (2 + i*25, 50), (25, -25 + 2* i), termbox.DEFAULT + i)
    #     ps.display(t)
    #     t.present()
    #     t.peek_event(timeout=1000)

def random_lines(t):
    LinesScreenSaver(t).run_loop()

def run_app(t):
    app = App(t)
    app.quit_keys.append('q')
    app.run_loop()

def main():
    mode = parse_args()
    with termbox.Termbox() as t:
        {
            'r': random_dots,
            'd': debug_draw_line,
            'l': line_control,
            'a': run_app,
            'rl': random_lines,
        }.get(mode, lambda x: print('unknown mode'))(t)
        pass

if __name__ == '__main__':
    main()
