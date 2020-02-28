#!/bin/bash
FEATURE="--with-features=huge"
FEATURES=(
    "cscope"
    "fontset"
    "multibyte"
    "autoservername"
)

GUI="--enable-gui=yes --with-x=yes" # requires libsm-dev, libxt-dev, libx11-dev
INTERPS=(
    "python3"
    # "mzscheme"
    # "python" # requires libpython-dev
    "ruby" # requires ruby-dev
    "perl" # requires libperl-dev
    "lua" # ???
)
PYTHON2CONF="--with-python-config-dir=/usr/lib/python2.7/config-x86_64-linux-gnu"
P3="${P3:-python3.8}"
PYTHON3CONF="--with-python3-config-dir=/usr/lib/${P3}/config-${P3#python}m-x86_64-linux-gnu"
PYTHON3COMMAND="--with-python3-command=${P3}"

ENABLEINTERPS=""
for interp in ${INTERPS[@]}; do
    ENABLEINTERPS="${ENABLEINTERPS} --enable-${interp}interp=yes"
done

ENABLEFEATURES=""
for feature in ${FEATURES[@]}; do
    ENABLEFEATURES="${ENABLEFEATURES} --enable-${feature}"
done

LUAJIT="--with-luajit" # requires lib-luajit-5.1-dev

PREFIX="--prefix=$HOME/.local"

rm -f src/auto/config.cache
./configure $PREFIX $FEATURE $ENABLEFEATURES $ENABLEINTERPS $GUI $PYTHON3COMMAND $PYTHON3CONF $LUAJIT $@
