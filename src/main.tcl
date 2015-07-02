
# MAIN
# determine working directory to find data files

set cwd [file dirname [file normalize $argv0]]
if {[info exists ::starkit::mode]} {
    set cwd [file dirname [file dirname [file normalize $argv0]]]
}

if {$tcl_platform(os) == "Darwin"} {
    set cwd [file dirname [file dirname [file dirname [file dirname [file normalize $argv0]]]]]
}

set bandlist [list 40m 7.0MHz 30m 10.1MHz 20m 14.0MHz 17m 18.0MHz 15m 21.0MHz \
    12m 24.8MHz 10m 28MHz " 6m" 50MHz]
array set w2f $bandlist


set modes [list CW SSB]
set s2s ""
set mode CW

createFonts

enterRef
vwait enteredRef
loadConfig

loadNames
loadSotaCalls
initCounter
initSerial

set sinfo "Alt: $summits($ref,alt) Pts: $summits($ref,pts)"
logwindow "$ref \"$summits($ref,name)\"" "$sinfo Mode: $mode"
openLog $ref
