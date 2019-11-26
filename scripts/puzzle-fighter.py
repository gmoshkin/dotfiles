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

def drop_gems(gem_pair, ft, game_state):
    for (kind, x) in gem_pair:
        # TODO: find first empty slot and put the letter in there


def puzzle_fighter(instructions, cols=6, rows=12, start_col=3):
    game_state = [[' '] * rows for _ in range(cols)]
    for (gem1, gem2), moves in instructions:
        x1, x2, first_on_top = start_col, start_col, True
        for move in moves:
            o1, o2, first_on_top = Moves.__dict__[move](x1, x2, first_on_top)
            x1 += o1
            x2 += o2
            if first_on_top:
                gem_pair = [(gem2, x2), (gem1, x1)]
            else:
                gem_pair = [(gem1, x1), (gem2, x2)]
        drop_gems(gem_pair, first_on_top, game_state)

if __name__ == '__main__':
    for move, (x1, x2, f) in [
        ('L', (1, 1, True)),
        ('L', (0, 0, True)),
        ('R', (4, 4, True)),
        ('R', (5, 5, True)),
        ('A', (0, 0, True)),
        ('A', (0, 0, False)),
        ('A', (1, 1, False)),
        ('A', (1, 2, True)),
    ]:
        print((x1, x2, f), f'={move}=>', Moves.__dict__[move](x1, x2, f))

    puzzle_fighter([
        ['BR', 'LLL'],
        ['BY', 'LL'],
        ['BG', 'ALL'],
        ['BY', 'BRR'],
        ['RR', 'AR'],
    ])
