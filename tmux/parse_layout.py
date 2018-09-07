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

class Container:
    def __init__(self, size=None, position=None):
        self.size = size
        self.position = position

class PaneContainer(Container):
    def __init__(self, pane_id=None, size=None, position=None):
        self.pane_id = pane_id
        super().__init__(size, position)

    def get_panes(self):
        return [self]

    def get_min_size(self):
        return 1, 1

    def __repr__(self):
        return "PaneContainer({}, {}, {})".format(self.pane_id,
                                                  self.size,
                                                  self.position)

    def expand(self, size, pos=None):
        self.size = size
        if pos:
            self.position = pos

class SequenceContainer(Container):
    def __init__(self, containers=None, size=None, position=None):
        self.containers = containers
        super().__init__(size, position)
        self._cur_piece = None
        self._cur_remainder = None

    def get_panes(self):
        return [p for c in self.containers for p in c.get_panes()]

    def divide(self, what=None, howmany=None, weight=None):
        if weight:
            this_one_gets = self._cur_remainder and 1 or 0
            self._cur_remainder -= this_one_gets
            return self._cur_piece * weight + this_one_gets
        elif what and howmany:
            self._cur_piece, self._cur_remainder = divmod(what, howmany)

    def expand(self, size, pos=None):
        self.size = w, h = size
        if pos:
            self.position = pos
        self._expand()

    def _get_min_size(self):
        return zip(*[c.get_min_size() for c in self.containers])

class HorizontalSequence(SequenceContainer):
    def __init__(self, containers=None, size=None, position=None):
        super().__init__(containers, size, position)

    def get_min_size(self):
        min_ws, min_hs = self._get_min_size()
        return sum(min_ws) + len(self.containers) - 1, max(min_hs)

    def _expand(self):
        w, h = self.size
        w -= len(self.containers) - 1
        min_ws, _ = self._get_min_size()
        self.divide(w, sum(min_ws))
        for c in self.containers:
            c_w, _ = c.get_min_size()
            c.expand((self.divide(weight=c_w), h))

class VerticalSequence(SequenceContainer):
    def __init__(self, containers=None, size=None, position=None):
        super().__init__(containers, size, position)

    def get_min_size(self):
        min_ws, min_hs = self._get_min_size()
        return max(min_ws), sum(min_hs) + len(self.containers) - 1

    def _expand(self):
        # FIXME: fucking duplication ☹
        w, h = self.size
        h -= len(self.containers) - 1
        _, min_hs = self._get_min_size()
        self.divide(h, sum(min_hs))
        for c in self.containers:
            _, c_h = c.get_min_size()
            c.expand((w, self.divide(weight=c_h)))

class Layout:
    def __init__(self, container=None):
        self.container = container

    def show_panes(self):
        for p in self.container.get_panes():
            print(p)

    def compress(self):
        min_size = self.container.get_min_size()
        self.container.expand(min_size, pos=(0, 0))

def walk_layout(layout):
    container = layout
    if 'container' in container:
        container = container['container']
    if 'pane_id' in container:
        pane_id = container['pane_id']
        size_x, size_y = (int(_) for _ in container['size'])
        pos_x, pos_y = (int(_) for _ in container['position'])
        # print('pane %{} at [{},{}] with size {}x{}'.format(pane_id,
        #                                                    pos_x, pos_y,
        #                                                    size_x, size_y))
        return PaneContainer(pane_id, (size_x, size_y), (pos_x, pos_y))
    else:
        for key, constructor in [('horizontal', HorizontalSequence),
                                 ('vertical', VerticalSequence)]:
            if key in container:
                break
        else:
            raise Exception('wtf?')
        containers = [walk_layout(c) for c in container[key]]
        size_x, size_y = (int(_) for _ in container['size'])
        pos_x, pos_y = (int(_) for _ in container['position'])
        return constructor(containers=containers,
                           size=(size_x, size_y),
                           position=(pos_x, pos_y))

if __name__ == '__main__':
    argparser = argparse.ArgumentParser()
    argparser.add_argument('layout')
    args = argparser.parse_args()
    layout = parse_layout(args.layout)
    l = Layout(walk_layout(layout))
    l.show_panes()
    l.compress()
    l.show_panes()
    print(l.container.get_min_size())

# TODO: how do I print this picture for a layout?
# vertical{pane,horizontal{pane,pane,pane}}:
# ┌─────┐
# │     │
# ├─┬─┬─┤
# │ │ │ │
# └─┴─┴─┘
# or even this one?
# ┌─────┐
# ├─┬─┬─┤
# └─┴─┴─┘
# or maybe this one?
#       5
# ┌───────────┐
# │    5x1    │
# ├───┬───┬───┤ 3
# │1x1│1x1│1x1│
# └───┴───┴───┘
# vertical{horizontal{pane,vertical{pane,
#                                   pane}},
#          horizontal{pane,pane,pane},
#          pane}:
# ┌──┬──┐
# │  ├──┤
# ├─┬┴┬─┤
# ├─┴─┴─┤
# └─────┘
#       5
# ┌─────┬─────┐
# │     │ 2x1 │
# │ 2x3 ├─────┤
# │     │ 2x1 │
# ├───┬─┴─┬───┤ 7
# │1x1│1x1│1x1│
# ├───┴───┴───┤
# │    5x1    │
# └───────────┘
# ┌─┬─┐
# ├─┤ │
# ├─┴─┤
# └───┘
#       3
# ┌─────┬─────┐
# │ 1x1 │     │
# ├─────┤ 1x3 │
# │ 1x1 │     │ 3
# ├─────┴─────┤
# │    3x1    │
# └───────────┘
