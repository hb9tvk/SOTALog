#!/usr/bin/env tclsh
#
# Concatenates the modules listed in src/modules.tcl into ./sotalog.tcl, the
# single file the starkit wrap expects at SOTALog.vfs/lib/SOTALog/sotalog.tcl.
#
# Written in Tcl rather than shell so it runs identically on Windows, macOS
# and Linux with the interpreter the project already requires:
#
#   tclsh build.tcl

set root [file dirname [file normalize [info script]]]
set src [file join $root src]
set out [file join $root sotalog.tcl]

source [file join $src modules.tcl]

set fh [open $out w]
fconfigure $fh -translation lf -encoding utf-8

puts $fh "# GENERATED FILE - do not edit."
puts $fh "# Built from src/ by build.tcl; edit the modules there instead."
puts $fh ""

foreach module $sotalogModules {
    set path [file join $src $module]
    if {![file exists $path]} {
        puts stderr "build.tcl: missing module $module (listed in src/modules.tcl)"
        exit 1
    }
    set mh [open $path r]
    fconfigure $mh -encoding utf-8
    puts $fh [read $mh]
    close $mh
}
close $fh

# Only meaningful on POSIX; Windows has no permission bits to set.
catch {file attributes $out -permissions rwxr-xr-x}

puts "built $out from [llength $sotalogModules] modules ([file size $out] bytes)"
