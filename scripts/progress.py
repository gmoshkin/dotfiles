#!/usr/bin/env python3
import time

def bar(n, outof, max):
    if n == outof:
        return chr(0x2588) * max
    full, rest = divmod(max * n, outof)
    bits = 8 * rest // outof
    return (chr(0x2588) * full +
            (chr(0x2588 + (8 - bits)) if bits else ' ') +
            ' ' * (max - full - 1))

def progress(I, J, M1, M2):
    for i in range(I + 1):
        for j in range(J + 1):
            bar1 = bar(i, I, M1)
            bar2 = bar(j, J, M2)
            print('\r{i:3d}/{I:3d} {b1} {j:3d}/{J:3d} {b2}'.format(i=i,
                                                                   I=I,
                                                                   b1=bar1,
                                                                   j=j,
                                                                   J=J,
                                                                   b2=bar2),
                  end='')
            time.sleep(.1)

if __name__ == '__main__':
    progress(5, 80, 10, 40)
