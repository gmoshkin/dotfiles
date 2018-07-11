FEATURE="--with-features=huge"
FEATURES=(
    "cscope"
    "fontset"
    "multibyte"
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
PYTHON3CONF="--with-python3-config-dir=/usr/lib/python3.7/config-3.7m-x86_64-linux-gnu"

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
./configure $PREFIX $FEATURE $ENABLEFEATURES $ENABLEINTERPS $GUI $PYTHON3CONF $LUAJIT
