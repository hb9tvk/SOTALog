#!/bin/bash
#
# Builds the macOS .app with platypus.  Requires platypus and a tclsh on the
# PATH; Apple's bundled /usr/bin/tclsh is deprecated, so this uses whichever
# tclsh is installed (Homebrew's tcl-tk, for instance) and falls back to the
# system one.
set -e
cd "$(dirname "$0")"

# Single source of truth: the version lives in src/init.tcl.
VERSION=$(sed -n 's/^set SOTALOG_VERSION \(.*\)$/\1/p' src/init.tcl)
if [ -z "$VERSION" ]; then
    echo "make-macosx.sh: could not read SOTALOG_VERSION from src/init.tcl" >&2
    exit 1
fi

TCLSH=$(command -v tclsh || echo /usr/bin/tclsh)

tclsh build.tcl

rm -rf "SOTALog-${VERSION}.app"
platypus -a "SOTALog-${VERSION}" -o None -p "$TCLSH" -V "$VERSION" \
    -u "Peter Kohler HB9TVK" -I org.kohler.sotalog -R -i sotalog.icns \
    -y sotalog.tcl "SOTALog-${VERSION}.app"

echo "built SOTALog-${VERSION}.app"
