#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse

def csum(layout):
    res = 0
    for c in layout.strip():
        res = (res >> 1) + ((res & 0x1) << 15) + ord(c)
    return res

if __name__ == '__main__':
    argparser = argparse.ArgumentParser()
    argparser.add_argument('layout')
    args = argparser.parse_args()
    print('{:x}'.format(csum(args.layout)))
