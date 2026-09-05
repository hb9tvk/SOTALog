#!/usr/bin/env tclsh
#
# Runs the SOTALog test suite.  Each .test file runs in its own interpreter,
# because the ones that exercise the log format build the real Tk window and
# that can only be done once per process.
#
#   tclsh tools/test.tcl              every test file
#   tclsh tools/test.tcl pure         only files whose name matches "pure"
#
# tcltest always exits zero from cleanupTests, so the exit status of a test
# file says nothing about whether its tests passed.  This runner reads the
# summary line each file prints instead, and treats a file that produced no
# summary at all - one that crashed before finishing - as a failure.

set root [file dirname [file dirname [file normalize [info script]]]]
set pattern [expr {[llength $argv] ? [lindex $argv 0] : ""}]

set files {}
foreach f [lsort [glob -nocomplain -directory [file join $root tests] *.test]] {
    if {$pattern eq "" || [string match *$pattern* [file tail $f]]} { lappend files $f }
}
if {![llength $files]} {
    puts stderr "no test files matched \"$pattern\""
    exit 1
}

set failures {}
set totals [dict create Total 0 Passed 0 Skipped 0 Failed 0]

foreach f $files {
    set name [file tail $f]
    puts "===== $name ====="
    catch {exec [info nameofexecutable] $f 2>@1} output
    puts $output

    if {![regexp {Total\s+(\d+)\s+Passed\s+(\d+)\s+Skipped\s+(\d+)\s+Failed\s+(\d+)} \
            $output -> total passed skipped failed]} {
        puts stderr "$name: produced no test summary - it crashed or exited early"
        lappend failures $name
        continue
    }
    foreach k {Total Passed Skipped Failed} v [list $total $passed $skipped $failed] {
        dict incr totals $k $v
    }
    if {$failed > 0} { lappend failures $name }
}

puts ""
puts [format "%d files: %d tests, %d passed, %d skipped, %d failed" \
    [llength $files] [dict get $totals Total] [dict get $totals Passed] \
    [dict get $totals Skipped] [dict get $totals Failed]]

if {[llength $failures]} {
    puts stderr "FAILED: [join $failures {, }]"
    exit 1
}
exit 0
