
# MAIN
#
# The startup sequence runs inside the namespace, so it can use the same bare
# names the modules use among themselves.
#
# It first locates the directory holding the data files (names.txt,
# sotacalls.txt, summits.thm, kx3.ini) and receiving the logs this session
# writes.  Four cases, in order of precedence:
#
#   SOTALOG_HOME    explicit override, useful for development and testing
#   starkit         argv0 points inside the mounted VFS, so climb out of it
#   macOS .app      argv0 is <bundle>/Contents/Resources/script; climb to the
#                   directory the bundle itself sits in.  This is keyed on the
#                   bundle path rather than on the platform, so running the
#                   plain script on macOS still behaves like everywhere else
#   otherwise       the directory the script was started from

namespace eval ::sotalog {
    variable argv0path [file normalize $::argv0]
    variable cwd

    if {[info exists ::env(SOTALOG_HOME)]} {
        set cwd $::env(SOTALOG_HOME)
    } elseif {[info exists ::starkit::mode]} {
        set cwd [file dirname [file dirname $argv0path]]
    } elseif {[string match */Contents/Resources/* $argv0path]} {
        set cwd [file dirname [file dirname [file dirname [file dirname [file dirname $argv0path]]]]]
    } else {
        set cwd [file dirname $argv0path]
    }

    logMsg info "SOTALog $SOTALOG_VERSION starting, data directory: $cwd"

    variable s2s ""
    variable mode CW

    createFonts
    enterRef
}

# The reference dialog runs until the operator has entered a valid summit.
vwait ::sotalog::enteredRef

namespace eval ::sotalog {
    loadConfig

    # The fonts exist by now - createFonts runs before the reference dialog,
    # which is what the operator sees first - so the configured size is applied
    # to them here, before the log window is built from them.
    if {$uiScale != 100} { scaleFonts [expr {$uiScale / 100.0}] }

    loadNames
    loadSotaCalls
    initCounter
    initSerial

    variable sinfo "Alt: $summits($ref,alt) Pts: $summits($ref,pts)"
    logwindow "$ref \"$summits($ref,name)\"" "$sinfo Mode: $mode"
    openLog $ref

    logMsg info "activation $ref, my call $myCall, logging to $logfile"
}
