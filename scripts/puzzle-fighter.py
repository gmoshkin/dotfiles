#!/usr/bin/env python3

class Moves:
    def L(x1, x2, first_top):
        if x1 > 0 and x2 > 0:
            return -1, -1, first_top
        else:
            return 0, 0, first_top

    def R(x1, x2, first_top):
        if x1 < 5 and x2 < 5:
            return +1, +1, first_top
        else:
            return 0, 0, first_top

    def rotate(x1, x2, first_top, not_clockwise):
        if x1 < x2:
            return 0, -1, not_clockwise(False)
        elif x1 == x2:
            if not_clockwise(first_top):
                if x2 < 5:
                    return 0, +1, first_top
                else:
                    return -1, 0, first_top
            else:
                if x2 > 0:
                    return 0, -1, first_top
                else:
                    return +1, 0, first_top
        else:
            return 0, +1, not_clockwise(True)

    def A(x1, x2, first_top):
        return __class__.rotate(x1, x2, first_top, lambda b: b)

    def B(x1, x2, first_top):
        return __class__.rotate(x1, x2, first_top, lambda b: not b)

    @classmethod
    def do_move(cls, move, x1, x2, first_on_top):
        o1, o2, first_on_top = cls.__dict__[move](x1, x2, first_on_top)
        x1 += o1
        x2 += o2
        return x1, x2, first_on_top

def crash_adjacent(game_state, x0, y0, cell):
    marked = set()
    to_traverse = [(x0, y0)]
    target = cell.upper()
    while to_traverse:
        cur_p = cur_x, cur_y = to_traverse.pop()
        if cur_p in marked:
            continue
        else:
            marked.add(cur_p)
        for x_ofs, y_ofs in [(-1, 0), (0, 1), (1, 0), (0, -1)]:
            neighbour = neighbour_x, neighbour_y = cur_x + x_ofs, cur_y + y_ofs
            try:
                if game_state[neighbour_x][neighbour_y] == target:
                    to_traverse.append(neighbour)
            except IndexError:
                pass
    modified_cols = set()
    if len(marked) > 1:
        for x, y in marked:
            game_state[x][y] = ' '
            modified_cols.add(x)
    return modified_cols

see_states = False

def log(*args, **kwargs):
    if see_states:
        if args and hasattr(args[0], '__call__'):
            print(args[0]())
        else:
            print(*args, **kwargs)

import operator

def crash_gems(game_state):
    cols = set()
    for x, col in enumerate(game_state):
        for y, cell in enumerate(col):
            if cell.islower():
                log(f'crash gem {cell}')
                log(lambda: pretty_game_state(game_state))
                new_cols = crash_adjacent(game_state, x, y, cell)
                if new_cols:
                    log(f'crashed some')
                    log(lambda: pretty_game_state(game_state))
                cols |= new_cols
    return cols

def drop_gems(game_state, modified_cols):
    something_dropped = False
    for x in modified_cols:
        col = game_state[x]
        nonempty = [cell for cell in col if cell != ' ']
        if not all(new == old for new, old in zip(nonempty, col)):
            something_dropped = True
            col[:] = nonempty + [' '] * (len(col) - len(nonempty))

    return something_dropped

def perform_actions(gem_pair, game_state):
    need_to_crash = False
    for (kind, x) in gem_pair:
        if kind.islower():
            need_to_crash = True
        y = game_state[x].index(' ')
        game_state[x][y] = kind
    while need_to_crash:
        modified_cols = crash_gems(game_state)
        need_to_crash = drop_gems(game_state, modified_cols)

        if need_to_crash:
            log('dropped some')
            log(lambda: pretty_game_state(game_state))

def pretty_game_state(gs):
    return '\n'.join(''.join(cell if cell != ' ' else '_' for cell in row)
                     for row in reversed(list(zip(*gs))))

from copy import deepcopy

def puzzle_fighter(instructions, cols=6, rows=12, start_col=3):
    game_state = [[' '] * rows for _ in range(cols)]
    for (gem1, gem2), moves in instructions:
        x1, x2, first_on_top = start_col, start_col, True
        for move in moves:
            x1, x2, first_on_top = Moves.do_move(move, x1, x2, first_on_top)
        if first_on_top:
            gem_pair = [(gem2, x2), (gem1, x1)]
        else:
            gem_pair = [(gem1, x1), (gem2, x2)]
        last_game_state = deepcopy(game_state)
        try:
            perform_actions(gem_pair, game_state)
        except ValueError:
            return last_game_state

    return pretty_game_state(game_state)

def assert_eq(actual, expected, msg):
    ofs = '' if expected.count('\n') or actual.count('\n') else '    '
    if isinstance(actual, str) and isinstance(expected, list):
        expected = '\n'.join(expected)
    assert expected == actual, f'''{msg}
expected:
{ofs}{expected}
but got:
{ofs}{actual}'''

if __name__ == '__main__':
    for (move, (x1, x2, f)), expected in [
        (('L', (1, 1, True)),  (-1, -1, True)),
        (('L', (0, 0, True)),  (0, 0, True)),
        (('R', (4, 4, True)),  (1, 1, True)),
        (('R', (5, 5, True)),  (0, 0, True)),
        (('A', (0, 0, True)),  (0, 1, True)),
        (('A', (0, 0, False)), (1, 0, False)),
        (('A', (1, 1, False)), (0, -1, False)),
        (('A', (1, 2, True)),  (0, -1, False)),
    ]:
        assert_eq(actual=Moves.__dict__[move](x1, x2, f),
                  expected=expected,
                  msg="moves don't work")

    assert_eq(puzzle_fighter([
        ['BR', 'LLL'],
        ['BY', 'LL'],
        ['BG', 'ALL'],
        ['BY', 'BRR'],
        ['RR', 'AR'],
    ]), [
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '_B____',
        'BB__RR',
        'RYG_YB',
    ], 'wrong game state')

    assert_eq(puzzle_fighter([
        ['BR','LLL'],
        ['BY','LL'],
        ['BG','ALL'],
        ['BY','BRR'],
        ['RR','AR'],
        ['GY','A'],
        ['BB','AALLL'],
        ['GR','A'],
        ['RY','LL'],
        ['GG','L'],
        ['GY','BB'],
        ['bR','ALLL'],
        ['gy','AAL']
    ]), [
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '______',
        '____R_',
        '_R__YR',
        'RR__RB',
    ], 'wrong game state')

#     see_states = True
#     assert_eq(puzzle_fighter([
#         ['GR', 'ALLL'],
#         ['GG', 'ALLL'],
#         ['RG', 'AAL'],
#         ['RB', 'BLL'],
#         ['RG', 'ALL'],
#         ['BB', 'RR'],
#         ['BR', 'BB'],
#         ['BR', 'ALLL'],
#         ['YB', 'R'],
#         ['BG', 'BBRR'],
#         ['YR', 'AAR'],
#         ['RR', 'L'],
#         ['RR', 'ABLL'],
#         ['GY', 'BRR'],
#         ['BB', 'R'],
#         ['gB', 'RR'],
#         ['BR', 'ALL'],
#         ['Gr', 'BB'],
#         ['Rb', 'R'],
#         ['GG', 'B'],
#         ['bB', 'LL']
#     ]), [
#         '______',
#         '______',
#         '______',
#         '______',
#         '______',
#         '______',
#         '______',
#         '____R_',
#         '__GGY_',
#         '__GGYB',
#         'GGGRYB',
#         'GRRBBB',
#     ], 'wrong game state')
