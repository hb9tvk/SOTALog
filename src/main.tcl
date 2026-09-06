
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

    # The band table pairs each wavelength with the frequency the CSV records.
    variable bandlist [list 60m 5.0MHz 40m 7.0MHz 30m 10.1MHz 20m 14.0MHz \
                            17m 18.0MHz 15m 21.0MHz 12m 24.8MHz 10m 28MHz]
    variable w2f
    array set w2f $bandlist

    variable s2s ""
    variable mode CW

    createFonts
    enterRef
}

# The reference dialog runs until the operator has entered a valid summit.
vwait ::sotalog::enteredRef

namespace eval ::sotalog {
    loadConfig

    loadNames
    loadSotaCalls
    initCounter
    initSerial

    variable sinfo "Alt: $summits($ref,alt) Pts: $summits($ref,pts)"
    logwindow "$ref \"$summits($ref,name)\"" "$sinfo Mode: $mode"
    openLog $ref

    logMsg info "activation $ref, my call $myCall, logging to $logfile"
}
