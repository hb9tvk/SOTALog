
# The settings sotalog.conf may carry, in the order they are written.
# Anything else in the file is ignored.
set configSettings {myCall oneKeyReport entryMode utcDate}

# Reads "set <name> <value>" lines and returns the settings it recognised.
#
# The file used to be run through eval, which made it a script rather than
# data.  That had two consequences, and the activation date field has no
# validation, so both were one keystroke away: a value containing a space -
# a date typed as "5 September 2026" - stopped the application starting with
# a Tcl stack trace, and a value containing a bracket was executed.  A file
# left half-written by a crash did the same.
#
# The value is taken verbatim to the end of the line, so nothing inside it can
# change how the rest of the line is read.
proc parseConfig {text} {
    global configSettings

    set settings [dict create]
    set lineNumber 0

    foreach line [split $text \n] {
        incr lineNumber
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} { continue }

        if {![regexp {^set[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+(.*)$} $line -> name value]} {
            logMsg error "sotalog.conf line $lineNumber is not a setting, ignored: $line"
            continue
        }
        if {[lsearch -exact $configSettings $name] < 0} {
            logMsg error "sotalog.conf line $lineNumber names an unknown setting, ignored: $name"
            continue
        }
        dict set settings $name $value
    }

    return $settings
}

proc saveConfig {} {

    global myCall oneKeyReport entryMode utcDate cwd configSettings

    if {[string length [.cfg.call get]]} {
        set myCall [.cfg.call get]
    }
    if {$entryMode} {
	set utcDate [.cfg.utcDate get]
    }

    # Written to a temporary file and renamed, so that a crash or a flat
    # battery part way through cannot leave a half-written configuration
    # behind - which is one of the ways the old code failed to start.
    set path [file join $cwd sotalog.conf]
    set tmp $path.new
    if {[catch {
        set fh [open $tmp w]
        foreach name $configSettings {
            puts $fh "set $name [set $name]"
        }
        close $fh
        file rename -force $tmp $path
    } msg]} {
        catch {file delete $tmp}
        logMsg error "could not save sotalog.conf: $msg"
    }
}

proc loadConfig {} {

    global myCall oneKeyReport entryMode cwd utcDate

    set myCall HB9TVK/P
    set oneKeyReport 1
    set entryMode 0
    set utcDate [clock format [clock seconds] -format %d/%m/%Y]

    set path [file join $cwd sotalog.conf]
    if {![file exists $path]} {
        configDialog
        return
    }

    if {[catch {open $path r} fh]} {
        logMsg error "could not read sotalog.conf, using defaults: $fh"
        return
    }
    set text [read $fh]
    close $fh

    # Every setting already holds its default, so one the file does not
    # mention, or one it gets wrong, simply keeps it.
    dict for {name value} [parseConfig $text] {
        set $name $value
    }
}

proc configDialog {} {

    global myCall oneKeyReport entryMode updated utcDate
   
    toplevel .cfg 
    wm title .cfg "Configuration"
    
    set ok {set ::Modal.Result 1}
    set cancel {set ::Modal.Result 0}
    
    set oldEmo $entryMode
    set updated 0

    bind .cfg <Return> $ok
    bind .cfg <Escape> $cancel

    label .cfg.callLabel -text "My Call:" -font sotasmall
    entry .cfg.call -width 11 -font sotasmall -bd 1 -validatecommand {validateCall %v %d %S %V} -validate all
    .cfg.call insert 0 $myCall
    
    label .cfg.okrprtLabel -text "One-Key rprt:" -font sotasmall
    checkbutton .cfg.okrprt -variable oneKeyReport 
    if {$oneKeyReport} {
        .cfg.okrprt select
    } else {
        .cfg.okrprt deselect
    }
    
    label .cfg.entrymodeLabel -text "UTC Entry mode:" -font sotasmall
    checkbutton .cfg.entrymode -variable entryMode -command {
	    if {$entryMode} {
		.cfg.utcDate configure -state normal
	    } else {
		.cfg.utcDate configure -state disabled
	    }
    }
    if {$entryMode} {
        .cfg.entrymode select
    } else {
        .cfg.entrymode deselect
    }
    
    label .cfg.utcDateLabel -text "Activation Date (dd/mm/yyyy):" -font sotasmall
    entry .cfg.utcDate -width 10 -font sotasmall -bd 1
    .cfg.utcDate insert 0 $utcDate
    
    if {! $entryMode} {
	.cfg.utcDate configure -state disabled
    }
    
    label .cfg.updateCallsAndSummits -text "Update calls and summits" -font sotasmall
    button .cfg.update -text Update -command updateCallsAndSummits
    
    button .cfg.ok -text Ok -command $ok
    button .cfg.cancel -text Cancel -command $cancel
	
    grid .cfg.callLabel -row 0 -column 0
    grid .cfg.call -row 0 -column 1
    grid .cfg.okrprtLabel -row 1 -column 0
    grid .cfg.okrprt -row 1 -column 1
    grid .cfg.entrymodeLabel -row 2 -column 0
    grid .cfg.entrymode -row 2 -column 1
    grid .cfg.utcDateLabel -row 3 -column 0
    grid .cfg.utcDate -row 3 -column 1

    grid .cfg.updateCallsAndSummits -row 4 -column 0
    grid .cfg.update -row 4 -column 1
    grid .cfg.cancel -row 5 -column 0
    grid .cfg.ok -row 5 -column 1
	
    focus .cfg.call

    set res [ Show.Modal .cfg $cancel]
    
    if {$res} {
        saveConfig
	if {$oldEmo != $entryMode || $updated == 1} {
	    tk_messageBox -icon info -message "SOTALog needs to be restarted for changes to be applied" -type ok
	    exit 0
	}
    }
    destroy .cfg
}
