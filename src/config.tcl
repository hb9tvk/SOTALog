
proc saveConfig {} {
    
    global myCall oneKeyReport entryMode utcDate cwd
    
    if {[string length [.cfg.call get]]} {
        set myCall [.cfg.call get]
    }
    if {$entryMode} {
	set utcDate [.cfg.utcDate get]
    }
    catch {
        set fh [open [file join $cwd sotalog.conf] w]
        puts $fh "set myCall $myCall"
        puts $fh "set oneKeyReport $oneKeyReport"
	puts $fh "set entryMode $entryMode"
	puts $fh "set utcDate $utcDate"
        close $fh
    }    
}

proc loadConfig {} {

    global myCall oneKeyReport entryMode cwd utcDate
    
    set myCall HB9TVK/P
    set oneKeyReport 1
    set entryMode 0
    set utcDate [clock format [clock seconds] -format %d/%m/%Y]

    if {[file exists [file join $cwd sotalog.conf]]} {
        set fh [open [file join $cwd sotalog.conf] r]
        set cnf [read $fh]
        eval $cnf
        close $fh
    } else {
        configDialog
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
