# Shared setup for the SOTALog test suite.
#
# Tests run against the modules in src/ directly - the same files run.tcl
# loads - not against the concatenated build output, so a failure points at
# the module that actually contains the fault.

package require tcltest
package require Tk

# The suite drives the real widgets, but nothing needs to be on screen.
wm withdraw .

namespace eval sotalogtest {
    namespace export *

    variable root [file dirname [file dirname [file normalize [info script]]]]
    variable now 0
    variable sandboxes {}

    # The band table main.tcl builds at startup.  Repeated here so that tests
    # of the log format need not run the whole startup sequence.
    variable bandlist {60m 5.0MHz 40m 7.0MHz 30m 10.1MHz 20m 14.0MHz
                       17m 18.0MHz 15m 21.0MHz 12m 24.8MHz 10m 28MHz}
}

# Sources every application module except main.tcl, which starts the app.
proc sotalogtest::loadModules {} {
    variable root
    uplevel #0 [list source [file join $root src modules.tcl]]
    foreach m $::sotalogModules {
        if {$m eq "main.tcl"} continue
        uplevel #0 [list source [file join $root src $m]]
    }

    # The application lives in ::sotalog; the tests call its procedures by
    # their bare names, as the modules do among themselves.
    uplevel #0 {namespace import -force ::sotalog::*}
}

# A scratch directory standing in for the application's data directory.
#
# Explicitly under the system temp directory: tcltest's own temporaryDirectory
# defaults to the working directory, which puts test logs in the repository.
# Every sandbox is remembered so removeSandboxes can take them away again.
proc sotalogtest::sandbox {} {
    variable root
    variable sandboxes

    set base ""
    foreach v {TMPDIR TEMP TMP} {
        if {[info exists ::env($v)] && [file isdirectory $::env($v)]} {
            set base $::env($v)
            break
        }
    }
    if {$base eq ""} { set base [file join $root .testtmp] }

    set dir [file join $base sotalog-test-[pid]-[clock clicks]]
    file mkdir $dir
    lappend sandboxes $dir
    return $dir
}

# Removes every sandbox this test file created.  Call it before cleanupTests.
proc sotalogtest::removeSandboxes {} {
    variable sandboxes

    foreach dir $sandboxes { catch {file delete -force $dir} }
    set sandboxes {}
}

# saveLog and openLog stamp the QSO and the log file name from the system
# clock.  Freeze it so the expected records are stable; the suite also pins
# TZ, because the CSV carries a local date next to a UTC time.
proc sotalogtest::freezeClock {seconds} {
    variable now
    set now $seconds
    if {[info commands ::sotalogtest::realClock] eq ""} {
        rename ::clock ::sotalogtest::realClock
        proc ::clock {args} {
            if {[lindex $args 0] eq "seconds"} { return $::sotalogtest::now }
            return [::sotalogtest::realClock {*}$args]
        }
    }
}

# Brings up the real main window together with the globals saveLog and
# readLog depend on.  It deliberately skips main.tcl's startup sequence:
# these tests are about what reaches the log files, and loading the 13 MB
# summit list to get there would cost seconds per test for no benefit.
proc sotalogtest::startLogWindow {dir {entryModeOn 0}} {
    variable bandlist

    set ::sotalog::cwd $dir
    set ::sotalog::myCall HB9TVK/P
    set ::sotalog::ref HB/BE-003
    set ::sotalog::s2s ""
    set ::sotalog::mode CW
    set ::sotalog::entryMode $entryModeOn
    set ::sotalog::utcDate 05/09/2026
    set ::sotalog::oneKeyReport 1
    set ::sotalog::box {}
    set ::sotalog::sinfo "Alt: 3967 Pts: 10"
    set ::sotalog::bandlist $bandlist
    array set ::sotalog::w2f $bandlist
    array set ::sotalog::names {}
    set ::sotalog::sotacalls {}

    if {[lsearch -exact [font names] sotabig] < 0} { createFonts }
    initCounter
    logwindow "$::sotalog::ref \"Eiger\"" "$::sotalog::sinfo Mode: $::sotalog::mode"
    wm withdraw .
    openLog $::sotalog::ref
}

# The entry widgets validate every keystroke and rewrite themselves as they
# go, so tests set them directly with validation off.
proc sotalogtest::setEntry {w value} {
    $w configure -validate none
    $w delete 0 end
    if {$value ne ""} { $w insert 0 $value }
}

# Fills in one QSO and saves it, the way pressing Return in the app would.
proc sotalogtest::logQso {args} {
    array set q {call "" rsts "" rstr "" rem "" utc ""}
    array set q $args
    setEntry .sotalog.call $q(call)
    setEntry .sotalog.rsts $q(rsts)
    setEntry .sotalog.rstr $q(rstr)
    setEntry .sotalog.rem  $q(rem)
    if {$::sotalog::entryMode} { setEntry .sotalog.utc $q(utc) }
    saveLog
}

proc sotalogtest::readFile {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set data [read $fh]
    close $fh
    return $data
}

# Fake summit data for the S2S tests: small, so they need neither the 13 MB
# summit list nor the startup sequence that loads it.  All three are set-like
# arrays, keyed the way summits.thm stores them.
proc sotalogtest::loadFakeSummitData {} {
    array set ::sotalog::assocs  {HB 1 HB0 1 OE 1 DL 1 DM 1 F 1}
    array set ::sotalog::regions {HB/BE 1 HB/VS 1 HB/JU 1 HB0/LI 1 OE/TI 1 DL/BW 1}
    array set ::sotalog::refs    {HB/BE-001 1 HB/BE-003 1 HB/BE-013 1 HB/VS-001 1 OE/TI-437 1}
    array set ::sotalog::summits {
        HB/VS-001,name Dufourspitze HB/VS-001,alt 4633 HB/VS-001,pts 10
        HB/BE-003,name Eiger        HB/BE-003,alt 3967 HB/BE-003,pts 10
    }
}

# Builds the S2S dialog without entering its modal loop.
proc sotalogtest::startS2sDialog {} {
    if {[lsearch -exact [font names] sotabig] < 0} { createFonts }
    s2sWidgets
    wm withdraw .s2s
}

# Runs one entry validation the way Tk would.
#
# Tk suppresses re-entrant validation while a validatecommand is running, so a
# direct call has to do the same: the validators insert into the widget
# themselves, which would otherwise trigger validation again and recurse.
proc sotalogtest::typeInto {entry command char} {
    $entry configure -validate none
    set result [$command all 1 $char key [$entry get]]
    $entry configure -validate all
    return $result
}

# The same, for a deletion: %d is 0 and %P is the value the entry would have.
proc sotalogtest::deleteFrom {entry command remaining} {
    $entry configure -validate none
    set result [$command all 0 "" key $remaining]
    $entry configure -validate all
    return $result
}

proc sotalogtest::suggestions {} {
    return [string trim [.s2s.suggest get 1.0 end]]
}

# Runs a validation command the way Tk would, with re-entrancy suppressed.
#
# Tk disables validation while a validatecommand runs; a direct call has to do
# the same, because these procedures insert into the widget themselves and
# would otherwise trigger validation again and recurse.  The command and its
# arguments vary - the entry validators take %v %d %S %V %P, the report ones
# drop %P - so they are passed through verbatim.
proc sotalogtest::validateKey {entry args} {
    $entry configure -validate none
    set result [uplevel #0 $args]
    $entry configure -validate all
    return $result
}
