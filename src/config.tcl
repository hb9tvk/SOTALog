
# The settings sotalog.conf may carry, in the order they are written.
# Anything else in the file is ignored.
namespace eval ::sotalog {
    set configSettings {myCall oneKeyReport entryMode utcDate bands uiScale}
}

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
proc ::sotalog::parseConfig {text} {
    variable configSettings

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

# Keeps only bands the application knows, in the order the master table lists
# them, so that a hand-edited or older configuration cannot leave the band
# panel holding something meaningless.  An empty result falls back to the
# default selection: with no bands at all there is nothing to log on.
proc ::sotalog::normaliseBands {requested} {
    variable allBands
    variable defaultBands

    set chosen {}
    foreach {wavelength frequency} $allBands {
        if {[lsearch -exact $requested $wavelength] >= 0} { lappend chosen $wavelength }
    }

    foreach unknown $requested {
        if {[lsearch -exact $chosen $unknown] < 0} {
            logMsg error "sotalog.conf names an unknown band, ignored: $unknown"
        }
    }

    if {![llength $chosen]} {
        logMsg error "no usable band in the configuration, falling back to the default selection"
        return $defaultBands
    }
    return $chosen
}

proc ::sotalog::saveConfig {} {

    variable myCall
    variable oneKeyReport
    variable entryMode
    variable utcDate
    variable cwd
    variable configSettings
    variable allBands
    variable bands
    variable bandSelected
    variable uiScale

    if {[string length [.cfg.call get]]} {
        set myCall [.cfg.call get]
    }
    if {$entryMode} {
	set utcDate [.cfg.utcDate get]
    }

    # The band checkbuttons write into bandSelected; collect them back in the
    # order the master table lists them.  Refusing an empty selection rather
    # than silently substituting the defaults: with no bands there is nothing
    # to log on, and quietly changing what was ticked would be worse than
    # saying so.
    if {[array exists bandSelected]} {
        set chosen {}
        foreach {wavelength frequency} $allBands {
            if {[info exists bandSelected($wavelength)] && $bandSelected($wavelength)} {
                lappend chosen $wavelength
            }
        }
        if {[llength $chosen]} {
            set bands $chosen
        } else {
            showMessage warning "Bands" \
                "At least one band has to be selected.\nThe previous selection has been kept."
        }
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

proc ::sotalog::loadConfig {} {

    variable myCall
    variable oneKeyReport
    variable entryMode
    variable cwd
    variable utcDate
    variable bands
    variable defaultBands
    variable uiScale
    variable defaultUiScale

    set myCall HB9TVK/P
    set oneKeyReport 1
    set entryMode 0
    set utcDate [clock format [clock seconds] -format %d/%m/%Y]
    set bands $defaultBands
    set uiScale $defaultUiScale

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

    # The band selection is the one setting that has to be checked: it names
    # things rather than being a number or a string, and the panel is built
    # from it.
    set bands [normaliseBands $bands]
    set uiScale [normaliseUiScale $uiScale]
}

proc ::sotalog::configDialog {} {

    variable myCall
    variable oneKeyReport
    variable entryMode
    variable updated
    variable utcDate
    variable allBands
    variable bands
    variable bandSelected
    variable uiScale
    variable minUiScale
    variable maxUiScale

    toplevel .cfg 
    wm title .cfg "Configuration"
    
    set ok {set ::sotalog::modalResult 1}
    set cancel {set ::sotalog::modalResult 0}
    
    set oldEmo $entryMode
    set oldBands $bands
    set oldScale $uiScale
    set updated 0

    bind .cfg <Return> $ok
    bind .cfg <Escape> $cancel

    label .cfg.callLabel -text "My Call:" -font sotasmall
    entry .cfg.call -width 11 -font sotasmall -bd 1 -validatecommand {::sotalog::validateCall %v %d %S %V} -validate all
    .cfg.call insert 0 $myCall
    
    label .cfg.okrprtLabel -text "One-Key rprt:" -font sotasmall
    checkbutton .cfg.okrprt -variable ::sotalog::oneKeyReport 
    if {$oneKeyReport} {
        .cfg.okrprt select
    } else {
        .cfg.okrprt deselect
    }
    
    label .cfg.entrymodeLabel -text "UTC Entry mode:" -font sotasmall
    checkbutton .cfg.entrymode -variable ::sotalog::entryMode -command {
	    if {$::sotalog::entryMode} {
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

    # Which bands get a button in the log window.  Laid out five to a row so
    # that fifteen of them do not make the dialog taller than the screen the
    # application is likely to be running on.
    labelframe .cfg.bands -text "Bands shown in the log window" -font sotasmall
    array unset bandSelected
    set i 0
    foreach {wavelength frequency} $allBands {
        set bandSelected($wavelength) \
            [expr {[lsearch -exact $bands $wavelength] >= 0}]
        checkbutton .cfg.bands.b$wavelength -text $wavelength -font sotasmall \
            -variable ::sotalog::bandSelected($wavelength) -takefocus 0
        grid .cfg.bands.b$wavelength -row [expr {$i / 5}] -column [expr {$i % 5}] -sticky w
        incr i
    }
    
    # Everything in the log window is drawn from point-sized fonts, so one
    # slider scales the lot.  It takes effect on restart, along with the band
    # selection and the entry mode.
    label .cfg.uiscaleLabel -text "Display size (%):" -font sotasmall
    scale .cfg.uiscale -from $minUiScale -to $maxUiScale -resolution 10 \
        -orient horizontal -length 200 -font sotasmall -takefocus 0 \
        -variable ::sotalog::uiScale

    label .cfg.updateCallsAndSummits -text "Update summits, calls and names" -font sotasmall
    button .cfg.update -text Update -command ::sotalog::updateCallsAndSummits
    
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

    grid .cfg.bands -row 4 -column 0 -columnspan 2 -sticky ew -padx 4 -pady 4

    grid .cfg.uiscaleLabel -row 5 -column 0
    grid .cfg.uiscale -row 5 -column 1 -sticky w

    grid .cfg.updateCallsAndSummits -row 6 -column 0
    grid .cfg.update -row 6 -column 1
    grid .cfg.cancel -row 7 -column 0
    grid .cfg.ok -row 7 -column 1
	
    set res [Show.Modal .cfg $cancel .cfg.call]
    
    if {$res} {
        saveConfig
	if {$oldEmo != $entryMode || $oldBands ne $bands || $oldScale != $uiScale || $updated == 1} {
	    showMessage info "Restart needed" "SOTALog needs to be restarted for changes to be applied"
	    exit 0
	}
    }
    destroy .cfg
}
