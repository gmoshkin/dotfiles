#!/usr/bin/env python3
# -*- coding: utf-8 -*-

sample_input = '''10 3 0.95
1 1 30
2 2 35
0 8 50
7 2 20
7 3 25
10 7 90
9 8 35
5 15 10
8 18 15
1 9 60
'''

if __name__ == '__main__':
    first_line, *city_lines = sample_input.splitlines()
    n_cities, bc_per_mile, decline = first_line.split()
    n_cities, bc_per_mile, decline = int(n_cities), int(bc_per_mile), float(decline)
    assert len(city_lines) == n_cities
    cities = [tuple(int(_) for _ in l.split()) for l in city_lines]
    #TODO
