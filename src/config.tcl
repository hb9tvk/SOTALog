
proc saveConfig {} {
    
    global myCall oneKeyReport cwd
    
    if {[string length [.cfg.call get]]} {
        set myCall [.cfg.call get]
    }
    catch {
        set fh [open [file join $cwd sotalog.conf] w]
        puts $fh "set myCall $myCall"
        puts $fh "set oneKeyReport $oneKeyReport"
        close $fh
    }    
}

proc loadConfig {} {

    global myCall oneKeyReport cwd

    if {[file exists [file join $cwd sotalog.conf]]} {
        set fh [open [file join $cwd sotalog.conf] r]
        set cnf [read $fh]
        eval $cnf
        close $fh
    } else {
        set myCall HB9TVK/P
        set oneKeyReport 1
        configDialog
    }
}

proc configDialog {} {

    global myCall oneKeyReport
   
    toplevel .cfg 
    wm title .cfg "Configuration"
    
    set ok {set ::Modal.Result 1}
    set cancel {set ::Modal.Result 0}
    

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
    
    label .cfg.updateCallsAndSummits -text "Update calls and summits" -font sotasmall
    button .cfg.update -text Update -command updateCallsAndSummits
    
    button .cfg.ok -text Ok -command $ok
    button .cfg.cancel -text Cancel -command $cancel
	
    grid .cfg.callLabel -row 0 -column 0
    grid .cfg.call -row 0 -column 1
    grid .cfg.okrprtLabel -row 1 -column 0
    grid .cfg.okrprt -row 1 -column 1
    grid .cfg.updateCallsAndSummits -row 2 -column 0
    grid .cfg.update -row 2 -column 1
    grid .cfg.cancel -row 4 -column 0
    grid .cfg.ok -row 4 -column 1
	
    focus .cfg.call

    set res [ Show.Modal .cfg $cancel]
    
    if {$res} {
        saveConfig
    }
    destroy .cfg
}
