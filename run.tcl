#!/usr/bin/env tclsh
#
# Development launcher.
#
# Sources each module from src/ separately, so an error trace names the real
# file and line instead of pointing somewhere inside the concatenated build
# output.  Packaged builds run that concatenated sotalog.tcl instead; this
# file is not shipped.
#
# Start it with tclsh, not wish.  tclsh is a console binary, so the Tk window
# comes up *and* puts / logMsg output lands in the terminal - on Windows wish
# is a GUI-subsystem binary and silently discards anything written to stdout.
#
#   tclsh run.tcl
#   SOTALOG_DEBUG=2 tclsh run.tcl
#
# Data files (names.txt, sotacalls.txt, summits.thm, kx3.ini) and the files
# the app writes are resolved relative to this script's directory, because
# main.tcl derives them from argv0.

set sotalogRoot [file dirname [file normalize [info script]]]
set sotalogSrc [file join $sotalogRoot src]

source [file join $sotalogSrc modules.tcl]

foreach sotalogModule $sotalogModules {
    source [file join $sotalogSrc $sotalogModule]
}
