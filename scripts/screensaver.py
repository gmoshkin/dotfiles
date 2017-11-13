#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import termbox
from random import randint, random, choice
from math import pi, sin, cos, ceil
from itertools import zip_longest
from argparse import ArgumentParser
from collections import defaultdict
from PIL import Image
from time import sleep
from datetime import datetime
# from pyinotify import (
#     ProcessEvent, WatchManager, ThreadedNotifier, IN_MODIFY, IN_DELETE, IN_CREATE
# )
from os import path

def parse_args():
    arg_parser = ArgumentParser(description='TODO')
    arg_parser.add_argument('mode')
    arg_parser.add_argument('args', nargs='*')
    args = arg_parser.parse_args()
    return args.mode, args.args

def grouper(iterable, n, fillvalue=None):
    args = [iter(iterable)] * n
    return zip_longest(*args, fillvalue=fillvalue)

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
                elif bot == top:
                    tb.change_cell(x, y, self.full, bot, top)
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

class StubTB:
    quit_event = (termbox.EVENT_KEY, 'q', None, None, None, None, None, None)
    def __init__(self):
        self.events = [
            # (kind, ch, key,  mod, w, h, x, y)
            (termbox.EVENT_RESIZE, None, None, None, 50, 50, None, None),
            (termbox.EVENT_KEY, 'j', None, None, None, None, None, None),
            self.quit_event,
        ]

    def width(self):
        return 100

    def height(self):
        return 60

    def peek_event(self, timeout=0):
        sleep(timeout / 1000)
        self.poll_event()

    def poll_event(self):
        if self.events:
            return self.events.pop()
        else:
            return self.quit_event

    def select_output_mode(self, mode):
        pass

    def change_cell(self, x, y, ch, fg, bg):
        print('tb.change_cell({}, {}, {}, {}, {})'.format(x, y, ch, fg, bg))
        pass

    def clear(self):
        pass

    def present(self):
        pass

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
        self.key_callbacks = defaultdict(lambda: [])

    def handle_resize(self, w, h):
        self.width = w
        self.height = h

    def handle_key(self, ch, key, mod):
        for k in self.quit_keys:
            if ch == k or k == key:
                self.run_app = False
        for k in [ch, key]:
            for cb in self.key_callbacks[k]:
                cb()

    def add_key_callback(self, key, callback):
        self.key_callbacks[key].append(callback)

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
    r = randint(min(w, h) // 5, min(w, h) // 2)
    return c, r

class PixelScreenApp(App):

    def __init__(self, tb, fps=0, clear=True):
        super().__init__(tb, fps)
        self.do_clear = clear
        self.height *=  2
        self.screen = PixelScreen(self.width, self.height)
        self.quit_keys.append('q')
        self.tb.select_output_mode(termbox.OUTPUT_256)

    def handle_resize(self, w, h):
        self.width, self.height = w, 2 * h
        self.screen.resize(self.width, self.height)

    def display_before(self):
        pass

    def display_after(self):
        pass

    def display(self):
        if self.do_clear:
            self.screen.clear()
        self.display_before()
        self.screen.display(self.tb)
        self.display_after()


def channel2cterm(x):
    ctermRatio = 256 / 6
    return int(x / ctermRatio)

def rgb2term(rgb):
    r = channel2cterm(rgb[0])
    g = channel2cterm(rgb[1])
    b = channel2cterm(rgb[2])
    return int(16 + 36 * r + 6 * g + b)

def rgba2term(rgba):
    if rgba[3] < .3 * 256:
        return termbox.DEFAULT
    r = channel2cterm(rgba[0])
    g = channel2cterm(rgba[1])
    b = channel2cterm(rgba[2])
    return int(16 + 36 * r + 6 * g + b)

# class FileWatcher:
#     class Handler(ProcessEvent):
#         def __init__(self, callback):
#             self.callback = callback

#         def process_IN_MODIFY(self, event):
#             self.callback()

#         def process_IN_CREATE(self, event):
#             self.callback()

#     def __init__(self, filename, callback):
#         self.filename = filename
#         self.callback = callback
#         wm = WatchManager()
#         wm.add_watch(filename, IN_MODIFY | IN_CREATE)
#         self.notifier = ThreadedNotifier(wm, self.Handler(callback))

#     def start(self):
#         self.notifier.start()

class ImageViewer(PixelScreenApp):

    def __init__(self, tb, image='/home/gmoshkin/Pictures/sad.png'):
        super().__init__(tb, fps=1)
        try:
            self.orig_image = Image.open(image)
            self.filename = image
            self.last_file_mtime = path.getmtime(self.filename)
        except AttributeError:
            self.filename = None
            self.orig_image = image
        self.scale_image()
        self.tb.select_output_mode(termbox.OUTPUT_256)
        # if self.filename:
        #     fw = FileWatcher(self.filename, self.handle_modify)
        #     fw.start()

    def handle_modify(self):
        self.orig_image = Image.open(self.filename)
        self.scale_image()

    def handle_resize(self, w, h):
        super().handle_resize(w, h)
        self.scale_image()

    def scale_image(self):
        orig_width, orig_height = self.orig_image.size
        if self.width * orig_height < self.height * orig_width:
            ratio = self.width / orig_width
        else:
            ratio = self.height / orig_height
        self.scaled_size = tuple(ceil(old * ratio)
                                 for old in self.orig_image.size)
        self.scaled_image = self.orig_image.resize(self.scaled_size,
                                                   Image.ANTIALIAS)
        with open('/tmp/scaled_image', 'w') as f:
            print(datetime.now(), file=f)
            print(self.scaled_image.size, file=f)
            for c in self.scaled_image.getdata():
                print(c, file=f, end=' ')

    def update(self):
        mtime = path.getmtime(self.filename)
        if mtime != self.last_file_mtime:
            self.last_file_mtime = mtime
            self.handle_modify()

    def display_before(self):
        start_x = (self.width - self.scaled_size[0]) // 2
        start_y = (self.height - self.scaled_size[1]) // 2
        image_data = self.scaled_image.getdata()
        if len(image_data[0]) > 3:
            convert = rgba2term
        else:
            convert = rgb2term
        for j, row in enumerate(grouper(image_data, self.scaled_size[0])):
            for i, c in enumerate(row):
                self.screen.put_cell((start_x + i, start_y + j), convert(c))

class LinesScreenSaver(PixelScreenApp):
    colors = [
        termbox.BLACK,
        termbox.RED,
        termbox.RED | termbox.BOLD,
        termbox.GREEN,
        termbox.YELLOW,
        termbox.BLUE,
        termbox.MAGENTA,
        termbox.MAGENTA | termbox.BOLD,
        termbox.CYAN,
        termbox.WHITE,
    ]
    circles_count = 7
    def __init__(self, tb, circle1=((20, 20), 15), circle2=((45, 50), 25),
                 color1=termbox.RED, color2=termbox.BLUE):
        super().__init__(tb, fps=1)
        self.lines = []
        self.circle1 = circle1
        self.circle2 = circle2
        self.color1 = color1
        self.color2 = color2
        self.circle = ((self.width // 2, self.height // 2),
                        int(.45 * min(self.width, self.height)))
        self.color = random_color()
        self.curr_colors = list(self.colors)
        self.refresh()
        self.add_key_callback('R', self.refresh)
        self.add_key_callback('C', self.clear)

    def clear(self):
        self.lines = []

    def random_color(self):
        if not self.curr_colors:
            self.curr_colors = list(self.colors)
        color = choice(self.curr_colors)
        self.curr_colors.remove(color)
        return color

    def refresh(self):
        self.curr_color = self.random_color()
        self.circles = [ random_circle(self.width, self.height)
                        for _ in range(self.circles_count) ]

    def update(self):
        # if len(self.lines) % 20 == 0:
        #     self.circle = random_circle(self.width, self.height)
        #     self.color = random_color()
        if len(self.lines) % 120 == 0:
            self.refresh()
        circle = choice(self.circles)
        start = random_circle_point(*circle)
        end = random_circle_point(*circle)
        # start = random_rect_edge_point(self.width, self.height)
        # end = random_rect_edge_point(self.width, self.height)
        # color = random_color()
        # if is_inside(self.circle2, start) and is_inside(self.circle1, end):
            # color = self.color2
        self.lines.append((start, end, self.curr_color))
        # self.lines.append((self.circle[0],
        #                    (self.circle[0][0] + self.circle[1],
        #                     self.circle[0][1]), color))

    def display_before(self):
        for l in self.lines:
            draw_line(self.screen, *l)

    def display_after(self):
        put_text(self.tb, (0, 0), '{}'.format(len(self.lines)))

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
        try:
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
        except KeyError:
            pass
        try:
            self.color += {
                '+': 1,
                '-': -1,
            }[ch]
        except KeyError:
            pass

    def draw(self, screen):
        draw_line(screen, self.start, self.end, self.color)


def line_control(t):
    ps = PixelScreen(t.width(), t.height() * 2)
    run_app = True
    line = Line((0, 0), (4, 11), termbox.MAGENTA | termbox.BOLD)
    # line = Line((20, 0), (10, 10), termbox.RED)
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

def run_app(t):
    app = App(t)
    app.quit_keys.append('q')
    app.run_loop()

def image_viewer(tb, args):
    ImageViewer(tb, args[0]).run_loop()

def main():
    mode, args = parse_args()
    with termbox.Termbox() as t:
        torun = {
            'r': random_dots,
            'd': debug_draw_line,
            'l': line_control,
            'a': run_app,
            'rl': LinesScreenSaver,
            'i': image_viewer,
        }.get(mode, lambda x: print('unknown mode'))
        if isinstance(torun, type) and issubclass(torun, App):
            torun(t).run_loop()
        else:
            if args:
                torun(t, args=args)
            else:
                torun(t)
        pass

if __name__ == '__main__':
    # ImageViewer(StubTB()).run_loop()
    main()
