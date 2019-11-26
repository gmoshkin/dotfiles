#!/usr/bin/env python3
import math

def factors(n):
    if n in fac_cache:
        return fac_cache[n]
    m = 2
    res = []
    cur_n = n
    while m <= cur_n:
        if cur_n % m == 0:
            power = math.log(*sorted([cur_n, m], reverse=True))
            if power.is_integer():
                power = int(power)
                res.extend([m] * power)
                cur_n = cur_n // (m ** power)
            else:
                res.extend(factors(m))
                cur_n = cur_n // m
        else:
            m += 1
    fac_cache[n] = res
    return res

def factors_slow(n):
    res = []
    cur_n = n
    cur_f = 2
    cur_p = 0
    while True:
        if cur_n % cur_f == 0:
            cur_p += 1
            cur_n = cur_n // cur_f
        else:
            if cur_p > 0:
                yield cur_f, cur_p
                cur_p = 0
            cur_f += 1
        if cur_n == 1:
            yield cur_f, cur_p
            break

def primeFactors(n):
    from collections import defaultdict
    bag = defaultdict(lambda: 0)
    for f in factors(n):
        bag[f] += 1
    return pretty_factor_items(sorted(bag.items()))

def pretty_factor_items(items):
    return ''.join('(%s**%s)' % (f, p) if p != 1 else '(%s)' % f for f, p in items)


if __name__ == '__main__':
    fac_cache = {
        1: [],
        2: [2],
        3: [3],
        4: [2, 2],
        5: [5],
        6: [2, 3],
        7: [7],
        8: [2, 2, 2],
        9: [3, 3],
        10: [2, 5],
        11: [11],
    }
    import functools, sys
    try:
        arg = sys.argv[1]
        arg = int(arg)
        fs = factors(arg)
        prod = functools.reduce(int.__mul__, fs)
        print(f'{prod}:', *fs)
        print(primeFactors(arg))
        print(pretty_factor_items(factors_slow(arg)))
    except ValueError:
        print(f"'{arg}' is not an integer")
    except IndexError:
        print(f"need an integer as argument")
    except TypeError:
        print(f"number {arg} has no factors")
