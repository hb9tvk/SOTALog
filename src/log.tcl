# Diagnostic logging.
#
# Messages go to stderr, so they appear in the terminal when the app is
# started with tclsh (a console binary).  Under wish, or inside a wrapped
# starkit, there is no console attached and the write fails - hence the catch.
# Losing a log line must never take the application down.
#
# Verbosity comes from the SOTALOG_DEBUG environment variable:
#   unset or 0   errors only (default)
#   1            errors and informational messages
#   2            everything

namespace eval ::sotalog {
    array set logLevels {error 0 info 1 debug 2}

    set logLevel 0
    if {[info exists ::env(SOTALOG_DEBUG)] && [string is integer -strict $::env(SOTALOG_DEBUG)]} {
        set logLevel $::env(SOTALOG_DEBUG)
    }
}
catch {fconfigure stderr -buffering line}

proc ::sotalog::logMsg {level msg} {
    variable logLevel
    variable logLevels

    if {![info exists logLevels($level)]} { set level error }
    if {$logLevels($level) > $logLevel} { return }
    catch {puts stderr "[clock format [clock seconds] -format %H:%M:%S] $level: $msg"}
}
