FEATURE="--with-features=huge"
FEATURES=(
    "cscope"
    "fontset"
    "multibyte"
)

GUI="--enable-gui=yes --with-x=yes"
INTERPS=(
    # "python3"
    "python"
    "ruby"
    "perl"
    "lua"
)
PYTHON2CONF="--with-python-config-dir=/usr/lib/python2.7/config-x86_64-linux-gnu"
PYTHON3CONF="--with-python3-config-dir=/usr/lib/python3.5/config-3.5m-x86_64-linux-gnu"

ENABLEINTERPS=""
for interp in ${INTERPS[@]}; do
    ENABLEINTERPS="${ENABLEINTERPS} --enable-${interp}interp=yes"
done

ENABLEFEATURES=""
for feature in ${FEATURES[@]}; do
    ENABLEFEATURES="${ENABLEFEATURES} --enable-${feature}"
done

PREFIX="--prefix=$HOME/.local"

rm -f src/auto/config.cache
./configure $PREFIX $FEATURE $ENABLEFEATURES $ENABLEINTERPS $GUI $PYTHON2CONF
