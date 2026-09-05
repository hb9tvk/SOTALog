#!/usr/bin/env tclsh
#
# Parses every module without starting the GUI, so a typo is caught before the
# app is launched.  Sourcing is the only real syntax check Tcl offers: a body
# with unbalanced braces fails here, though an error inside a proc body only
# shows up when that proc actually runs.
#
#   tclsh tools/check.tcl

set root [file dirname [file dirname [file normalize [info script]]]]
set src [file join $root src]

source [file join $src modules.tcl]

set failed 0
foreach module $sotalogModules {
    # main.tcl starts the application rather than defining procedures, so it
    # is listed but deliberately not executed here.
    if {$module eq "main.tcl"} { continue }

    if {[catch {source [file join $src $module]} err]} {
        puts stderr "FAIL $module: $err"
        incr failed
    } else {
        puts "ok   $module"
    }
}

if {$failed} {
    puts stderr "$failed module(s) failed to load"
    exit 1
}
puts "[llength $sotalogModules] modules listed, all loadable,\n    [llength [info procs ::sotalog::*]] procedures defined in ::sotalog"
exit 0
