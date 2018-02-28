#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import numpy as np

def draw_triangle(buf, points, colors):
    p1, p2, p3 = points
    c1, c2, c3 = colors
    draw_line(buf, p1, p2, c1, c2)
    draw_line(buf, p2, p3, c2, c3)
    draw_line(buf, p3, p1, c3, c1)

def barycentric(a, b, c, p):
    (ax, ay), (bx, by), (cx, cy), (px, py) = a, b, c, p
    dev = (by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
    ba = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / dev
    bb = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / dev
    return np.array((ba, bb, (1 - ba - bb)))

class Ds():
    def __init__(self, ds, dm, d0, ofs, dr=0):
        self.dsx, self.dsy  = ds
        self.dmx, self.dmy = dm
        self.dx, self.dy = d0
        self.ofsx, self.ofsy = ofs
        self.dr = dr
        self.x = self.y = 0

    def move(self):
        if self.dx > 0:
            self.x = self.ofsx
            self.dx += self.dmx
        else:
            self.x = 0
            self.dx += self.dsx
        if self.dy > 0:
            self.y = self.ofsy
            self.dy += self.dmy
        else:
            self.y = 0
            self.dy += self.dsy
        return self.x, self.y, self.dr

    def get_vect(self):
        return np.array(self.x, self.y)

def draw_triangle_beta(buf, points, colors):
    (p1, c1), (p2, c2), (p3, c3) = sorted(zip(points, colors),
                                          key=lambda _: _[0][0])

    ds1 = get_ds_beta(p1, p2)
    ds2 = get_ds_beta(p1, p3)
    ds3 = get_ds_beta(p2, p3)

    x, y = p1
    t1 = p1.copy()
    t2 = p1.copy()
    def _put(x, y):
        put(buf, x, y, np.dot(barycentric(p1, p2, p3, (x, y)), (c1, c2, c3)))
    while (t1 != p2).any():
        _put(*t1)
        t1 += ds1.move()[:2]
        while t1[0] > t2[0]:
            t2 += ds2.move()[:2]
            m, M = t1[1], t2[1]
            if m > M:
                m, M = M, m
            for y in range(m, M + 1):
                _put(t2[0], y)
    while t1[0] != p3[0]:
        _put(*t1)
        t1 += ds3.move()[:2]
        while t1[0] > t2[0]:
            t2 += ds2.move()[:2]
            m, M = t1[1], t2[1]
            if m > M:
                m, M = M, m
            for y in range(m, M + 1):
                _put(t2[0], y)


def get_ds(start, end):
    dx, dy = end[0] - start[0], start[1] - end[1]
    step = ofs = 1
    if dy >= 0:
        if dx >= dy:
            ofs = -1
        else:
            step = -1
    dy = dy if dy >= 0 else -dy
    coord = int(dx < dy)
    m = min((dx, dy))
    M = max((dx, dy))
    dStraight = 2 * m
    dDiag = dStraight - 2 * M
    d0 = dStraight - M
    r0 = 0
    dr = 1 / M
    return coord, dStraight, dDiag, d0, ofs, step, r0, dr

def put(buf, x, y, val):
    if 0 <= x < buf.shape[1] and 0 <= y < buf.shape[0]:
        buf[y, x] = val

def get_ds_beta(start, end):
    sub = np.subtract(end, start)
    ofs = np.sign(sub)
    sub = np.abs(sub)
    bus = np.flip(sub, 0)
    dstop = 2 * sub
    dmove = dstop - 2 * bus
    dinit = dstop - bus
    return Ds(dstop, dmove, dinit, ofs, 1 / max(sub))

def draw_line_beta(buf, start, end, color_start, color_end=None):
    if color_end is None:
        color_end = color_start
    if start[0] > end[0]:
        start, end = end, start
        color_end, color_start = color_start, color_end
    ds = get_ds_beta(start, end)

    r = 0
    x, y = start
    while (x, y) != end:
        color = color_start * (1 - r) + color_end * r
        put(buf, x, y, color)
        dx, dy, dr = ds.move()
        x += dx
        y += dy
        r += dr
    put(buf, x, y, color)

def draw_line(buf, start, end, color_start, color_end=None):
    if color_end is None:
        color_end = color_start
    if start[0] > end[0]:
        start, end = end, start
        color_end, color_start = color_start, color_end
    coord, dStraight, dDiag, d, ofs, step, r0, dr = get_ds(start, end)

    j = start[1 - coord]
    r = r0
    for i in range(start[coord], end[coord] + step, step):
        color = color_start * (1 - r) + color_end * r
        if coord:
            put(buf, j, i, color)
        else:
            put(buf, i, j, color)
        if d > 0:
            j += ofs
            d += dDiag
        else:
            d += dStraight
        r += dr

def draw_buf(buf):
    for top_row, bot_row in zip(*([iter(buf)] * 2)):
        for top, bot in zip(top_row, bot_row):
            draw_2cell(top, bot)
        print()

def draw_2cell(top, bot):
    print('\033[48;2;{};{};{}m\033[38;2;{};{};{}m\u2584\033[0m'.format(
        *top.astype(int), *bot.astype(int)), end='')

def from_hex(h):
    if h[0] == '#':
        h = h[1:]
    res = np.empty(3)
    for i in range(3):
        res[i] = int(h[i * 2: (i + 1) * 2], base=16)
    return res

if __name__ == '__main__':
    bg = from_hex('#002b36')
    RED = from_hex('#dc322f')
    GREEN = from_hex('#859900')
    BLUE = from_hex('#268bd2')
    width, height = 80, 40
    buf = np.full((height, width, 3), bg)
    p1, p2, p3 = np.array([(0, 0), (3, 10), (10, 2)])
    draw_line(buf, (0, 0), (9, 5), RED, GREEN)
    draw_line(buf, (10, 5), (19, 0), RED, GREEN)
    draw_line(buf, (20, 0), (24, 10), RED, GREEN)
    draw_line(buf, (25, 10), (29, 0), RED, GREEN)

    draw_line_beta(buf, (0, 5+ 0), (9,  5+ 5), RED, GREEN)
    draw_line_beta(buf, (10,5+ 5), (19, 5+ 0), RED, GREEN)
    draw_line_beta(buf, (20,5+ 0), (24, 5+10), RED, GREEN)
    draw_line_beta(buf, (25,5+10), (29, 5+ 0), RED, GREEN)

    draw_line(buf , (29 , 10) , (25 , 20) , RED , GREEN)
    draw_line(buf , (24 , 20) , (20 , 10) , RED , GREEN)
    draw_line(buf , (19 , 10) , (10 , 15) , RED , GREEN)
    draw_line(buf , (9  , 15) , (0  , 10) , RED , GREEN)

    ofs = (0, 20)
    draw_triangle(buf, (p1 + ofs, p2 + ofs, p3 + ofs), (RED, GREEN, BLUE))
    ofs = (10, 20)
    draw_triangle(buf,
                  (p3 + ofs + (0, 10),
                   p2 + ofs + (0, -10),
                   p1 + ofs + (0, 10)),
                  (RED, GREEN, BLUE))
    ofs = (20, 20)
    draw_triangle_beta(buf, (p1 + ofs, p2 + ofs, p3 + ofs), (RED, GREEN, BLUE))
    ofs = (30, 20)
    draw_triangle_beta(buf, (p3 + ofs + (0, 10),
                             p2 + ofs + (0, -10),
                             p1 + ofs + (0, 10)), (RED, GREEN, BLUE))
    ofs = (40, 20)
    draw_triangle(buf, (np.array((0, 0)) + ofs,
                        np.array((8, 0)) + ofs,
                        np.array((4, 10)) + ofs), (RED, GREEN, BLUE))
    ofs = (50, 20)
    draw_triangle_beta(buf, (np.array((0, 0)) + ofs,
                             np.array((8, 0)) + ofs,
                             np.array((4, 10)) + ofs), (RED, GREEN, BLUE))
    draw_buf(buf)
