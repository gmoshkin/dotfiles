#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

def assert_eq(expected, actual, msg):
    assert expected == actual, '{m} (expected {e}, got {a})'.format(m=msg,
                                                                    e=expected,
                                                                    a=actual)

def assert_expr(expr, msg):
    assert expr, '{m}'.format(m=msg)

def perr(*args, **kwargs):
    print(*args, **kwargs, file=sys.stderr)

class Matrix:
    def __init__(self, rows=None):
        self.verify_rows(rows)
        self._rows = rows

    @staticmethod
    def verify_rows(rows):
        assert_expr(all(len(row) == len(rows[0]) for row in rows[1:]),
                    "matrix's rows must all have the same length (got {})".format(
                        [len(row) for row in rows]))

    @staticmethod
    def generate(size):
        rows, cols = size
        return Matrix([list(tup) for tup in
                       zip(*([iter(range(1, 1 + rows * cols))] * cols))])

    @property
    def size(self):
        if len(self._rows) > 0:
            return len(self._rows), len(self._rows[0])
        return 0, 0

    @property
    def empty(self):
        return len(self._rows) == 0 or len(self._rows[0]) == 0

    @property
    def height(self):
        return len(self._rows)

    @property
    def width(self):
        return len(self._rows[0])

    @staticmethod
    def from_str(string):
        return Matrix([
            [int(val) for val in row.split(',')]
            for row in string.split(';')
        ])

    @property
    def T(self):
        return self.transposed()

    def transposed(self):
        return Matrix([list(tup) for tup in  zip(*self._rows)])

    def flatten(self):
        return [cell for row in self._rows for cell in row]

    def row(self, s, e=None):
        if e:
            return self._rows[s:e]
        return self._rows[s]

    def col(self, j):
        if j < 0:
            j %= self.width
        return self.flatten()[j::self.width]

    def pill(self):
        rows, cols = self.size
        vector = self.flatten()
        if rows < 2 or cols < 2:
            return Layer(vector), Matrix([])
        return (Layer(self.row(0) +
                      self.col(-1)[1:-1] +
                      self.row(-1)[::-1] +
                      self.col(0)[1:-1][::-1]),
                Matrix([row[1:-1] for row in self.row(1,-1)]))

    def wrapped(self, layer):
        toprow, rside, botrow, lside = layer.split(self.size)
        return Matrix.vert(Matrix([toprow]),
                           Matrix.horiz(Matrix([lside]).T,
                                        self,
                                        Matrix([rside]).T),
                           Matrix([botrow]))

    def __repr__(self):
        return '\n'.join([' '.join(str(c) for c in row) for row in self._rows])

    @staticmethod
    def vert(*matrices):
        return Matrix([row for m in matrices for row in m])

    @staticmethod
    def horiz(*matrices):
        return Matrix([row for m in matrices for row in
                       (m.T if isinstance(m, Matrix) else Matrix(m).T)]).T

    def __iter__(self):
        return iter(self._rows)

    def rotated(self, n=1):
        if self.empty:
            return self
        outer_layer, insides = self.pill()
        if insides.empty:
            return outer_layer.rotated(n).fold(self.size)
        return insides.rotated(n).wrapped(outer_layer.rotated(n))

class Layer:
    def __init__(self, elements):
        self._elems = elements

    @property
    def size(self):
        return len(self._elems)

    @staticmethod
    def propper_length(size):
        rows, cols = size
        return (rows + cols) * 2 + 4

    @staticmethod
    def generate(something):
        if isinstance(something, int):
            return Layer(list(range(1, 1 + something)))
        if isinstance(something, tuple):
            return Layer.generate(Layer.propper_length(something))
        if isinstance(something, Matrix):
            return Layer.generate(something.size)

    def split(self, size):
        assert_eq(actual=self.size, expected=Layer.propper_length(size),
                  msg="Cannot split layer for this size")
        rows, cols = (val + 2 for val in size)
        s, e = 0, cols
        toprow = self.elem(s, e)
        s = e; e += rows - 2
        rside = self.elem(s, e)
        s = e; e += cols
        botrow = self.elem(s, e)[::-1]
        s = e; e += rows - 2
        lside = self.elem(s, e)[::-1]
        return toprow, rside, botrow, lside

    def elem(self, s, e=None):
        if e:
            return self._elems[s:e]
        return self._elems[s]

    def rotated(self, n=1):
        if n > self.size:
            n %= self.size
        return Layer(self._elems[n:] + self._elems[:n])

    def reversed(self):
        return Layer(self._elems[::-1])

    def fold(self, size):
        rows, cols = size
        assert_expr(rows <= 2 or cols <= 2,
                    "Cannot fold a layer to size {}".format(size))
        if rows == 1:
            return Matrix([self._elems])
        if cols == 1:
            return Matrix([self._elems]).T
        if rows == 2:
            return Matrix([self._elems[:cols], self._elems[cols:][::-1]])
        if cols == 2:
            return (self.rotated().reversed().fold((cols, rows))).T
        return Matrix([self._elems[:cols]]) + self._elems[cols:cols + rows - 2]

    def __repr__(self):
        return ' '.join(str(v) for v in self._elems)


def get_size(matr):
    cols = len(matr[0])
    assert_expr(all(len(row) == cols for row in matr),
                "matrix's rows must all have the same length (got {})".format(
                    [len(row) for row in matr]))
    return len(matr), cols

def wrapper_length(size):
    rows, cols = size
    return (rows + cols) * 2 + 4

def wrap_layer(layer, insides):
    rows, cols = (val + 2 for val in get_size(insides))
    assert_eq(actual=len(layer), expected=wrapper_length(get_size(insides)),
              msg="Wrong size of layer!")
    s, e = 0, cols
    toprow = layer[s:e]
    s = e; e += rows - 2
    rside = layer[s:e]
    s = e; e += cols
    botrow = layer[s:e][::-1]
    lside = layer[e:][::-1]
    return ([toprow] +
            transposed([lside] + transposed(insides) + [rside]) +
            [botrow])

def s2m(separators):
    return [[int(val) for val in row.split(',')] for row in separators.split(';')]

def m2v(matr):
    return [cell for row in matr for cell in row]

def transposed(matr):
    return [list(tup) for tup in  zip(*matr)]

def pill_layer(matr):
    rows, cols = get_size(matr)
    vector = m2v(matr)
    if rows < 2:
        return vector
    outer_layer = (matr[0] +
                   vector[cols - 1::cols][1:-1] +
                   matr[-1][::-1] +
                   vector[0: :cols][1:-1][::-1])
    insides = [row[1:-1] for row in matr[1:-1]]
    return outer_layer, insides

def rotate(layer, n=1):
    if n > len(layer):
        n %= len(layer)
    return layer[n:] + layer[:n]

def fold_layer(layer, size):
    rows, cols = size
    assert_expr(rows <= 2 or cols <= 2, "Cannot fold a layer to size {}".format(size))
    if rows == 1:
        return [layer]
    if cols == 1:
        return [[v] for v in layer]
    if rows == 2:
        return [layer[:cols], layer[cols:][::-1]]
    if cols == 2:
        return transposed(fold_layer(rotate(layer)[::-1], (cols, rows)))

def gen_layer(length):
    return list(range(1, 1 + length))

def m(matr):
    for row in matr:
        print (' '.join(str(c) for c in row))

def gen_wrapping_layer(matr):
    return gen_layer(wrapper_length(get_size(matr)))

# matr = fold_layer(gen_layer(2), size=(1, 2))
# matr = wrap_layer(gen_wrapping_layer(matr), insides=matr)
# matr = wrap_layer(gen_wrapping_layer(matr), insides=matr)
# matr = wrap_layer(gen_wrapping_layer(matr), insides=matr)
# m(matr)

def line(n=5):
    print(' '.join(['-'] * n))

def printline(*args, **kwargs):
    print(*args, **kwargs)
    line()

if len(sys.argv) > 3:
    matrix = Matrix.generate((int(sys.argv[1]), int(sys.argv[2])))
    printline(matrix)
    printline(matrix.rotated(int(sys.argv[3])))
# init_size = (3, 2)
# layer = Layer.generate(init_size[0] * init_size[1])
# printline(layer)
# matrix = layer.fold(init_size)
# printline(matrix)
# layer, matrix = matrix.pill()
# printline(layer)
# printline(matrix)
# matrix = layer.fold(init_size)
# printline(matrix)
# printline(matrix.rotated(386))
# layer = Layer.generate(matrix)
# printline(layer)
# printline(matrix)
# matrix = matrix.wrapped(layer)
# printline(matrix)
# printline(matrix.rotated())
# matrix = matrix.wrapped(Layer.generate(matrix))
# printline(matrix)
# printline(matrix.rotated())
