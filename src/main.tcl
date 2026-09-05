
# MAIN
#
# Locate the directory holding the data files (names.txt, sotacalls.txt,
# summits.thm, kx3.ini) and receiving the logs this session writes.  Four
# cases, in order of precedence:
#
#   SOTALOG_HOME    explicit override, useful for development and testing
#   starkit         argv0 points inside the mounted VFS, so climb out of it
#   macOS .app      argv0 is <bundle>/Contents/Resources/script; climb to the
#                   directory the bundle itself sits in.  This is keyed on the
#                   bundle path rather than on the platform, so running the
#                   plain script on macOS still behaves like everywhere else
#   otherwise       the directory the script was started from

set argv0path [file normalize $argv0]

if {[info exists env(SOTALOG_HOME)]} {
    set cwd $env(SOTALOG_HOME)
} elseif {[info exists ::starkit::mode]} {
    set cwd [file dirname [file dirname $argv0path]]
} elseif {[string match */Contents/Resources/* $argv0path]} {
    set cwd [file dirname [file dirname [file dirname [file dirname [file dirname $argv0path]]]]]
} else {
    set cwd [file dirname $argv0path]
}

::sotalog::logMsg info "SOTALog $::SOTALOG_VERSION starting, data directory: $cwd"

set bandlist [list 60m 5.0MHz 40m 7.0MHz 30m 10.1MHz 20m 14.0MHz 17m 18.0MHz 15m 21.0MHz 12m 24.8MHz 10m 28MHz]
array set w2f $bandlist

set modes [list CW SSB]
set s2s ""
set mode CW

::sotalog::createFonts

::sotalog::enterRef
vwait enteredRef
::sotalog::loadConfig

::sotalog::loadNames
::sotalog::loadSotaCalls
::sotalog::initCounter
::sotalog::initSerial

set sinfo "Alt: $summits($ref,alt) Pts: $summits($ref,pts)"
::sotalog::logwindow "$ref \"$summits($ref,name)\"" "$sinfo Mode: $mode"
::sotalog::openLog $ref

::sotalog::logMsg info "activation $ref, my call $myCall, logging to $logfile"
