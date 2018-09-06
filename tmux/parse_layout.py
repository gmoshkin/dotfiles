#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pyparsing import (
    nums, Word, Group, Forward, ZeroOrMore, Literal, Optional
)
import argparse

def named(what, name):
    return what.setResultsName(name)

def parse_layout(string):
    comma = Literal(',').suppress()
    lbr = Literal('[').suppress()
    rbr = Literal(']').suppress()
    lcbr = Literal('{').suppress()
    rcbr = Literal('}').suppress()

    opt_csum = named(Optional(Word(nums + 'abcdefABCDEF') + comma), 'csum')
    size = named(Group(Word(nums) + Literal('x').suppress() + Word(nums)), 'size')
    position = named(Group(Word(nums) + comma + Word(nums)), 'position')
    pane_id = named(Word(nums), 'pane_id')

    container = Forward()
    cont_seq = container + ZeroOrMore(comma + container)
    vert_seq = named(Group(lbr + cont_seq + rbr), 'vertical')
    horiz_seq = named(Group(lcbr + cont_seq + rcbr), 'horizontal')
    contains = comma + pane_id | vert_seq | horiz_seq
    container << named(Group(size + comma + position + contains), 'container')
    layout = opt_csum + container

    return layout.parseString(string)

def walk_layout(layout):
    container = layout
    if 'container' in container:
        container = container['container']
    if 'pane_id' in container:
        pane_id = container['pane_id']
        size_x, size_y = tuple(container['size'])
        pos_x, pos_y = tuple(container['position'])
        print('pane %{} at [{},{}] with size {}x{}'.format(pane_id,
                                                           pos_x, pos_y,
                                                           size_x, size_y))
    else:
        for k in ['horizontal', 'vertical']:
            if k in container:
                break
        else:
            raise Exception('wtf?')
        for c in container[k]:
            walk_layout(c)

if __name__ == '__main__':
    argparser = argparse.ArgumentParser()
    argparser.add_argument('layout')
    args = argparser.parse_args()
    layout = parse_layout(args.layout)
    walk_layout(layout)
