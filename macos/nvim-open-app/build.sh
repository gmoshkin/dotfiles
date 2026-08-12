#!/bin/bash
#
# Compiles nvim-open.applescript into an app bundle and registers it with
# LaunchServices, so that it shows up in Finder's "Open With", accepts files
# dropped on it, and is what double-clicking a text file does.
#
# The bundle is generated, not committed: osacompile writes a binary script and
# a plist, and both are reproducible from the .applescript next to this file.
# Which file types it claims lives in file-types.swift.
#
#   ./build.sh                            -> ~/Applications/NvimOpen.app
#   ./build.sh --no-set-default-handlers  -> ...but leave double-click alone
#   DEST=/Applications ./build.sh         -> somewhere else
#
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

app_name="${APP_NAME:-NvimOpen}"
bundle_id="${BUNDLE_ID:-com.gmoshkin.nvim-open}"
dest="${DEST:-$HOME/Applications}"
app="$dest/$app_name.app"

lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Changing the default application makes macos ask you to confirm it, once per
# file type, so it is worth being able to say no
set_default_handlers=yes
for arg in "$@"; do
    case "$arg" in
        --no-set-default-handlers) set_default_handlers=no ;;
        *) echo "unknown option '$arg'" >&2; exit 1 ;;
    esac
done

if [ ! -x "$HOME/dotfiles/jai/nvim-open" ]; then
    echo "warning: ~/dotfiles/jai/nvim-open is missing; build it with 'jai jai/build.jai - nvim-open'" >&2
    echo "         and symlink it to the platform binary. The app calls it by that path." >&2
fi

# osacompile refuses to write over an existing bundle. Only ever delete one we
# recognise as ours, and never with -f: if this is something else, or the
# deletion fails, that is for you to look at rather than for the script to
# steamroll
if [ -e "$app" ]; then
    if [ ! -f "$app/Contents/Resources/Scripts/main.scpt" ]; then
        echo "'$app' exists and is not an applet bundle; remove it yourself and rerun" >&2
        exit 1
    fi
    rm -r "$app"
fi

mkdir -p "$dest"
osacompile -o "$app" "$here/nvim-open.applescript"

/usr/bin/swift "$here/file-types.swift" declare "$app" "$app_name" "$bundle_id"

# osacompile signs the applet ad-hoc, and editing the plist invalidates that
# signature: `codesign --verify` says "invalid Info.plist (plist or signature
# have been modified)" and Gatekeeper refuses the bundle. Sign it again now that
# the plist is final, under the bundle id rather than osacompile's app name, so
# the signing identity and the id LaunchServices binds to agree.
codesign --force --sign - --identifier "$bundle_id" "$app"

# Otherwise LaunchServices may keep serving whatever it cached for this path
"$lsregister" -f "$app"

if [ "$set_default_handlers" = yes ]; then
    /usr/bin/swift "$here/file-types.swift" set-default "$app"
fi

echo "built $app"
echo
echo "try it:  open -a '$app' <some file>"
echo "or:      right-click a file in Finder -> Open With -> $app_name"
