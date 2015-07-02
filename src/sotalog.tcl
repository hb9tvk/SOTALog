package provide SOTALog 2.0

package require Tk
package require http

proc createFonts {} {
    global tcl_platform
    font create sotabig
    font configure sotabig -family Helvetica -size 32 -weight bold
    font create sotahuge
    font configure sotahuge -family Helvetica -size 36 -weight bold
    font create sotasmall
    font configure sotasmall -family Helvetica -size 20
    font create sotamini
    font configure sotamini -family Helvetica -size 16
    font create sotamicro
    if {[string match Linux* $tcl_platform(os)]} {
        font configure sotamicro -family Helvetica -size 14
    } else {
        font configure sotamicro -family Helvetica -size 12
    }
    font create sotamono
    font configure sotamono -family Courier -size 16 -weight bold
}

proc Show.Modal {win onclose} {
    set ::Modal.Result {}
    array set options [list -onclose {} -destroy 0 -onclose $onclose ]
    wm transient $win .
    wm protocol $win WM_DELETE_WINDOW [list catch $options(-onclose) ::Modal.Result]
    set x [expr {([winfo width  .] - [winfo reqwidth  $win]) / 2 + [winfo rootx .]} - 150]
    set y [expr {([winfo height .] - [winfo reqheight $win]) / 2 + [winfo rooty .]} - 20]
    wm geometry $win +$x+$y
    raise $win
    focus $win
    grab $win
    tkwait variable ::Modal.Result
    grab release $win
    if {$options(-destroy)} {destroy $win}
    return ${::Modal.Result}
}

proc loadNames {} {

    global names cwd

    set fh [open [file join $cwd names.txt] r]
    while {![eof $fh]} {
        gets $fh line
        set names([lindex $line 0]) [lrange $line 1 end]
    }
    close $fh
}

proc loadSotaCalls {} {

    global sotacalls cwd

    set fh [open [file join $cwd sotacalls.txt] r]
    set sotacalls [read $fh]
    close $fh
}
proc readLog {} {
    global logfile bandlist band cwd mode

    set fh [open [file join $cwd $logfile] r]
    while {![eof $fh]} {
        gets $fh csvline
        if {![string length $csvline]} { continue }
        set csvline [split $csvline ,]
        set call [lindex $csvline 7]
        set utc [lindex $csvline 4]
        set fq [lindex $csvline 5]
        set mode [lindex $csvline 6]
        set pos [lsearch -exact $bandlist $fq]
        incr pos -1
        set band [lindex $bandlist $pos]
        set allrem [string trim [lindex [lrange $csvline 9 end] 0] \"]
        set rsts ""
        set rstr ""
        set rem ""
        regexp {RSTS:([0-9]{3})} $allrem - rsts
        regexp {RSTR:([0-9]{3}) (.*)$} $allrem - rstr rem
        insertLog $utc $call $rsts $rstr $rem
    }
}

proc openLog {ref} {

    global logfile adif

    regsub / $ref _ ref
    set logfile "[clock format [clock seconds] -format %Y-%m-%d]_${ref}.csv"
    set adif  "[clock format [clock seconds] -format %Y-%m-%d]_${ref}.adi"
    if {[file exists $logfile]} {
	readLog
    }		
}

proc saveLog {} {

    global box band ref logfile w2f adif myCall s2s cwd mode

    if {[string length [.sotalog.call get]] == 0} {
        clear
        return
    }
    set utc [clock format [clock seconds] -gmt true -format %H%M]

    insertLog $utc [.sotalog.call get] [.sotalog.rsts get] [.sotalog.rstr get] [.sotalog.rem get] 

    set csvdate [clock format [clock seconds] -format %d/%m/%Y]
    set call [string trim [.sotalog.call get]]
    if {![string length $s2s]} {
        set rem "RSTS:[.sotalog.rsts get] RSTR:[.sotalog.rstr get] [.sotalog.rem get]"
    } else {
        set rem "RSTS:[.sotalog.rsts get] RSTR:[.sotalog.rstr get] S2S:$s2s [.sotalog.rem get]"
    }
    #set csv "$myCall,$csvdate,$utc,$ref,$w2f($band),CW,$call,RSTS:[.sotalog.rsts get] RSTR:[.sotalog.rstr get] [.sotalog.rem get]" 
    set csv "V2,$myCall,$ref,$csvdate,$utc,$w2f($band),$mode,$call,$s2s,\"${rem}\"" 
    set fh [open [file join $cwd $logfile] a]
    puts $fh $csv
    close $fh
    # <qso_date:8:d>20120728 <time_on:4>1208 <call:6>OM3CHR <band:3>30M 
    # <mode:2>CW <rst_sent:3>599 <rst_rcvd:3>599 <station_callsign:8>HB9TVK/P <APP_DXKeeper_TEMP:14>SOTA HB/LU-021 <eor>

    set ad "<qso_date:8:d>[clock format [clock seconds] -format %Y%m%d] "
    append ad "<time_on:4>$utc "
    append ad "<call:[string length $call]>$call "
    append ad "<band:[string length $band]>[string toupper $band] "
    append ad "<mode:[string length $mode]>$mode "
    append ad "<rst_sent:3>[.sotalog.rsts get] "
    append ad "<rst_rcvd:3>[.sotalog.rstr get] "
    append ad "<station_callsign:[string length $myCall]>$myCall "
    #append ad "<APP_DXKeeper_TEMP:[expr [string length $ref] + 5]>SOTA $ref <eor>"
    set comment "SOTA $ref"
    if {[string length $s2s]} {
        append comment " S2S with $s2s"
    }
    if {[string length [.sotalog.rem get]]} {
        append comment " Remark: [.sotalog.rem get]"
    }
    append ad "<comment:[string length $comment]>$comment <eor>"
    
    set fh [open [file join $cwd $adif] a]
    puts $fh $ad
    close $fh
    clear
}

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
set kx3bands [list BN03\; 40m BN04\; 30m BN05\; 20m BN06\; 17m BN07\; 15m \
    BN08\; 12m BN09\; 10m BN10\; " 6m"]
array set kx32b $kx3bands

proc kx3band {} {
    global serial kx32b band

    set response [read $serial 5]
    if {[info exists kx32b($response)]} {
	set band $kx32b($response)
    }
}

proc kx3poll {} {
    global serial

    #puts "poll..."
    catch {
        if {[string length $serial]} {
            puts -nonewline $serial "BN;"
            flush $serial
        }
    }
    after 1000 kx3poll
}

proc initSerial {} {
    global serial cwd

    if {![file exists kx3.ini]} {
        return
    }
    set fh [open [file join $cwd kx3.ini] r]
    set sp [read $fh]
    close $fh

    if {[catch {
		set serial [open $sp r+]
		fconfigure $serial -mode 38400,n,8,1 -blocking 1 -translation auto -buffering none
		fileevent $serial readable kx3band
	    } msg]} {
        #puts "boing: $msg"
        set serial ""
        return
    }
    kx3poll
}

proc enterRef {} {

    wm title . "Enter SOTA REF"
    wm protocol . WM_DELETE_WINDOW {
        exit
    }

    frame .ref
    bind . <Return> { saveRef }

    label .ref.label -text "Enter SOTA REF:" -font sotabig
    entry .ref.ref -width 11 -font sotabig -bd 1 -validatecommand {processRef %v %d %S %V} -validate all

    grid .ref.label -row 0 -column 0
    grid .ref.ref -row 0 -column 1

    focus .ref.ref
    pack .ref

}

proc processRef {validation action new vaction} {
    if {$vaction == "key" && $action == 1} {
        if {$new == "."} { set new "/" }
        .ref.ref insert insert [string toupper $new]
        after idle [list .ref.ref configure -validate $validation]
        return 1
    }
    return 1
}

proc saveRef {} {

    global enteredRef ref summits refs assocs regions cwd
    
    set ref [.ref.ref get]

    if {![regexp {[0-9]+$} $ref refnum]} {
        tk_messageBox -icon error -message "Invalid SOTA REF" -type ok
        return
    }
    regsub {[0-9]+$} $ref [format %03d [string trimleft $refnum 0]] ref
    
    if {![regexp {\-} $ref]} {
        regsub {([0-9]+)$} $ref -& ref
    }
    set fh [open [file join $cwd summits.thm] r]
    array set summits [gets $fh]
    array set refs [gets $fh]
    array set assocs [gets $fh]
    array set regions [gets $fh]
    close $fh
    if {![info exists summits(${ref},name)]} {
        tk_messageBox -icon error -message "Unknown SOTA REF" -type ok
        return
    }
    set enteredRef 1
    destroy .ref
}

proc saveS2s {} {
    global s2s summits

    if {[string length [.s2s.num get]]} {
        set s2s [.s2s.ass get]/[.s2s.reg get]-[format %03d [string trimleft [.s2s.num get] 0]]
        if {[info exists summits($s2s,name)]} {
            .sotalog.s2s configure -text "S2S: $s2s $summits($s2s,name) / $summits($s2s,pts) Pts"
        }
        if {![regexp {([A-Z0-9]+)/([A-Z0-9]+)-([0-9]+)} $s2s]} {
            set s2s ""
            .sotalog.s2s configure -text ""
        }
    } else {
        set s2s ""
        .sotalog.s2s configure -text ""
    }
}

proc validateNum {validation action new vaction newval} {
    global assocs regions refs
    set curreg [.s2s.ass get]/[.s2s.reg get]
    if {$vaction == "key" && $action == 1} {
        if {$new == ","} { return 0 }
        after idle [list .s2s.num configure -validate $validation]

        if {![regexp {[0-9]} $new]} {
            return 0
        }

        .s2s.num insert insert $new
        set matches [lsort [array names refs -glob *${curreg}-*[.s2s.num get]*]]
        regsub -all "${curreg}-" $matches "" matches
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
        if {![string length $matches]} {
            .s2s.num configure -fg red
        } else {
            .s2s.num configure -fg black
        }        
        return 1
    }
    if {$vaction == "key" && $action == 0} {
        set matches [lsort [array names refs -glob *${curreg}-*${newval}*]]
        regsub -all "${curreg}-" $matches "" matches
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
        if {![string length $matches]} {
            .s2s.num configure -fg red
        } else {
            .s2s.num configure -fg black
        }
        return 1
    }

    if {$vaction == "focusin"} {
        set matches [lsort [array names refs -glob ${curreg}-*[.s2s.num get]*]]
        regsub -all "${curreg}-" $matches "" matches
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
    }
    return 1
}

proc validateReg {validation action new vaction newval} {
    global assocs regions
    set curass [.s2s.ass get]
    if {$vaction == "key" && $action == 1} {
        if {$new == ","} { return 0 }
        after idle [list .s2s.reg configure -validate $validation]
        if {$new == " " || $new == "-"} {
            focus .s2s.num
            return 0
        }
        if {![regexp {[A-Za-z0-9/]} $new]} {
            return 0
        }

        .s2s.reg insert insert [string toupper $new]
        set matches [lsort [array names regions -glob *${curass}/[.s2s.reg get]*]]
        regsub -all "${curass}/" $matches "" matches
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
        if {![string length $matches]} {
            .s2s.reg configure -fg red
        } else {
            .s2s.reg configure -fg black
        }
        if {[string length [.s2s.reg get]] ==2} {
            focus .s2s.num
            return 0
        }
        
        return 1
    }
    if {$vaction == "key" && $action == 0} {
        set matches [lsort [array names regions -glob *${curass}/${newval}*]]
        regsub -all "${curass}/" $matches "" matches
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
        if {![string length $matches]} {
            .s2s.reg configure -fg red
        } else {
            .s2s.reg configure -fg black
        }
        return 1
    }
    if {$vaction == "focusout"} {
        if {![string length [array names regions -exact ${curass}/[.s2s.reg get]]]} {
            .s2s.reg configure -fg red
        }
    }
    if {$vaction == "focusin"} {
        set matches [lsort [array names regions -glob *${curass}/[.s2s.reg get]*]]
        regsub -all "${curass}/" $matches "" matches
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
    }
    return 1
}

proc validateAss {validation action new vaction newval} {
    global assocs
    if {$vaction == "key" && $action == 1} {
        if {$new == ","} { return 0 }
        after idle [list .s2s.ass configure -validate $validation]
        if {$new == " " || $new == "/"} {
            if {![string length [array names assocs -exact [.s2s.ass get]]]} {
                .s2s.ass configure -fg red
            }
            focus .s2s.reg
            return 0
        }
        if {![regexp {[A-Za-z0-9/]} $new]} {
            return 0
        }

        .s2s.ass insert insert [string toupper $new]
        set matches [lsort [array names assocs -glob *[.s2s.ass get]*]]
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
        if {![string length $matches]} {
            .s2s.ass configure -fg red
        } else {
            .s2s.ass configure -fg black
        }
        if {[string length [.s2s.ass get]] == 3}  {
            focus .s2s.reg
            return 0
        }
        if {[llength $matches] == 1} {
            .s2s.ass del 0 end
            .s2s.ass insert end $matches
            focus .s2s.reg
        }
        return 1
    }
    if {$vaction == "key" && $action == 0} {
        set matches [lsort [array names assocs -glob *${newval}*]]
        .s2s.suggest configure -state normal
        .s2s.suggest delete 1.0 end
        .s2s.suggest insert end $matches
        .s2s.suggest configure -state disabled
        if {![string length $matches]} {
            .s2s.ass configure -fg red
        } else {
            .s2s.ass configure -fg black
        }
        return 1
    }
    if {$vaction == "focusout"} {
        if {![string length [array names assocs -exact [.s2s.ass get]]]} {
            .s2s.ass configure -fg red
        }
    }
    return 1
}

proc s2sDialog {} {
    global assocs s2s
    
    toplevel .s2s 
    wm title . "S2S entry"

    set ok {set ::Modal.Result 1}
    set cancel {set ::Modal.Result 0}

    bind .s2s <Return> $ok
    bind .s2s <Escape> $cancel
    bind .s2s <comma> $cancel
    bind .s2s <Home> { focus [tk_focusPrev [focus]]}
    bind .s2s <End> { focus [tk_focusNext [focus]]}

    
    label .s2s.slash -text "/" -font sotahuge
    label .s2s.dash -text "-" -font sotahuge

    entry .s2s.ass -width 4 -font sotahuge -bd 1 -validatecommand {validateAss %v %d %S %V %P} -validate all
    entry .s2s.reg -width 3 -font sotahuge -bd 1 -validatecommand {validateReg %v %d %S %V %P} -validate all
    entry .s2s.num -width 4 -font sotahuge -bd 1 -validatecommand {validateNum %v %d %S %V %P} -validate all
    
    text .s2s.suggest -background white -wrap word -font sotamono -foreground blue \
    -width 40 -height 8
    .s2s.suggest insert end [lsort [array names assocs]]
    .s2s.suggest configure -state disabled
    
    if {[string length $s2s]} {
        if {[regexp {([A-Z0-9]+)/([A-Z0-9]+)-([0-9]+)} $s2s - a r n]} {
            .s2s.ass insert end $a
            .s2s.reg insert end $r
            .s2s.num insert end $n
        }
    }

    grid .s2s.ass -row 0 -column 0
    grid .s2s.slash -row 0 -column 1
    grid .s2s.reg -row 0 -column 2
    grid .s2s.dash -row 0 -column 3
    grid .s2s.num -row 0 -column 4
    grid .s2s.suggest -row 1 -column 0 -columnspan 5
        
    focus .s2s.ass
    set res [Show.Modal .s2s $cancel]
    
    if {$res} {
        saveS2s
    }
    destroy .s2s
}

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

proc updateCallsAndSummits {} {
    
    global cwd
    
    .cfg.ok configure -state disabled
    .cfg.cancel configure -state disabled
    .cfg.update configure -state disabled
    .cfg.call configure -state disabled
    .cfg.okrprt configure -state disabled
    
    if  {[catch {
        set t [::http::geturl http://sota.hb9tvk.org/sotalog/summits.thm -timeout 30000]
        set su [::http::data $t]
        ::http::cleanup $t
    } msg]} {
        tk_messageBox -icon error -message "Error updating summits: $msg" -type ok
    } else {
        set fh [open [file join $cwd summits.thm] w]
        fconfigure $fh -encoding iso8859-15
        puts $fh $su
        close $fh
    }
    if  {[catch {
        set t [::http::geturl http://sota.hb9tvk.org/sotalog/sotacalls.txt -timeout 30000]
        set sc [::http::data $t]
        ::http::cleanup $t
    } msg]} {
        tk_messageBox -icon error -message "Error updating calls: $msg" -type ok
    } else {
        set fh [open [file join $cwd sotacalls.txt] w]
        puts $fh $sc
        close $fh
    }
    
    tk_messageBox -icon info -message "Summits and calls updated successfully" -type ok
    .cfg.ok configure -state normal
    .cfg.cancel configure -state normal
    .cfg.update configure -state normal
    .cfg.call configure -state normal
    .cfg.okrprt configure -state normal
}
proc getBasecall {call} {
    set numSlash [regexp -all / $call]
    if {$numSlash == 0} {
        return $call
    }
    if {$numSlash == 1} {
        regexp "^(.*)/(.*)" $call - first last
        if {[string length $first] > [string length $last]} {
            return $first
        } else {
            return $last
        }
    }
    if {$numSlash == 2} {
        regexp "^.+/(.+)/" $call - basecall
        return $basecall
    }
    return $call
}

proc processCall {validation action new vaction newval} {

    global names sinfo sotacalls

    if {$vaction == "key" && $action == 1} {
        if {$new == "."} { set new "/" }
    	if {$new == " "} {
            focus .sotalog.rsts
            return 0
        }
        
        if {![regexp {[A-Za-z0-9/]} $new]} { return 0 }
        .sotalog.call insert insert [string toupper $new]
    	after idle [list .sotalog.call configure -validate $validation]
        set basecall [getBasecall [.sotalog.call get]]
        if {[info exists names($basecall)]} {
            .sotalog.info configure -text $names($basecall) -fg blue
        } else {
            .sotalog.info configure -text $sinfo -fg black
        }
        if {[string length [.sotalog.call get]] > 1} {
            updateSuggestions [.sotalog.call get]
        }
    }
    if {$vaction == "key" && $action ==0} {
        if {[string length $newval] > 1} {
            updateSuggestions $newval
        } else {
            .suggest.txt configure -state normal
            .suggest.txt delete 1.0 end
            .suggest.txt configure -state disabled
        }
    }
    return 1
}

proc processRSTs {validation action new vaction} {
    global oneKeyReport mode
    if {$vaction == "key" && $action == 1} {
        after idle [list .sotalog.rsts configure -validate $validation]
        if {$new == " "} {
    	    focus .sotalog.rstr
    	    return 0
    	}
    	if {![regexp {[1-9]} $new]} {
    	    return 0
    	}
        
        if {$oneKeyReport && $mode == "CW"} {
            if {$new < 5} {
                set rst ${new}${new}9
            } else {
                set rst 5${new}9
            }
            .sotalog.rsts delete 0 end
            .sotalog.rsts insert end $rst
            focus .sotalog.rstr
            return 1
        } else {
            .sotalog.rsts insert insert $new
            if {[string length [.sotalog.rsts get]] == 3} {
                focus .sotalog.rstr
            }
            return 1
        }
    }
    return 1
}

proc processRSTr {validation action new vaction} {
    global oneKeyReport mode
    if {$vaction == "key" && $action == 1} {
        after idle [list .sotalog.rstr configure -validate $validation]
        if {$new == " "} {
            focus .sotalog.rem
            return 0
        }
        if {![regexp {[1-9]} $new]} {
            return 0
        }
        if {$oneKeyReport && $mode == "CW"} {
            if {$new < 5} {
                set rst ${new}${new}9
            } else {
                set rst 5${new}9
            }
            .sotalog.rstr delete 0 end
            .sotalog.rstr insert end $rst
            focus .sotalog.rem
            return 1
        } else {
            .sotalog.rstr insert insert $new
            if {[string length [.sotalog.rstr get]] == 3} {
                focus .sotalog.rem
            }
            return 1
        }
        return 1
    }
    return 1
}

proc filterRemark {action key} {
    if {$action == 1} {
        if {$key == " "} { return 1 }
        if {[regexp {[^[:print:]]} $key]} {
            return 0
        }
    }
    return 1
}

proc validateCall {validation action new vaction} {
    if {$vaction == "key" && $action == 1} {
        after idle [list .cfg.call configure -validate $validation]
        if {![regexp {[A-Za-z0-9/]} $new]} {
            return 0
        }
        .cfg.call insert insert [string toupper $new]
        return 1
        }
    return 1
}


proc clear {} {
    global sinfo s2s mode
    .sotalog.call delete 0 end
    .sotalog.rsts delete 0 end
    .sotalog.rstr delete 0 end
    .sotalog.rem delete 0 end
    .loghist.box selection clear 0 end
    .sotalog.info configure -text "$sinfo Mode: $mode" -fg black
    .sotalog.s2s configure -text ""
    set s2s ""
    focus .sotalog.call
}

proc initCounter {} {
    global qsocount bandlist

    foreach {wl fq} $bandlist {
        set qsocount($wl) 0
    }
}

proc modeToggle {} {
    global mode modes sinfo
    set pos [lsearch -exact $modes $mode]
    incr pos
    if {$pos == [llength $modes]} { set pos 0}
    set mode [lindex $modes $pos]
    .sotalog.info configure -text "$sinfo Mode: $mode"
}

proc bandSwitch {up} {
    global band bandlist

    set pos [lsearch -exact $bandlist $band]
    if {$up && $pos == [expr [llength $bandlist] - 2]} {
        set pos -2
    }
    if {! $up && $pos == 0} {
        set pos [llength $bandlist]
    }
    if {$up} {
        incr pos 2
    } else {
        incr pos -2
    }	
    set band [lindex $bandlist $pos]
}

proc updateSuggestions {part} {

    global sotacalls

    set suggest [lsearch -all -glob -inline $sotacalls "*${part}*"]
    .suggest.txt configure -state normal
    .suggest.txt delete 1.0 end
    .suggest.txt insert end $suggest
    .suggest.txt configure -state disabled
}

proc pickSuggestion {x y} {

    set index [lindex [split [.suggest.txt index @$x,$y] .] 1]
    set s [.suggest.txt get 1.0 1.end]
    while {[string index $s $index] != " " && $index > 0} { incr index -1}
    regexp {[A-Za-z0-9/]+} [string range $s $index end] pick
    if {[info exists pick]} {
        .sotalog.call delete 0 end
        .sotalog.call insert end $pick
        focus .sotalog.rsts
    }
}

proc insertLog {utc call rsts rstr rem} {

    global box band qsocount s2s
    
    if {[string length $s2s]} {
        set rem $s2s
    }

    set log [format %-7s%-20s%-10s%-10s%-20s $utc $call $rsts $rstr $rem]
    set box [linsert $box 0 $log]
    if {[expr [llength $box] %2]} { set s 0 } else { set s 1 }

    for {set i 0} {$i < [llength $box]} {incr i} {
	if {$s} {
	    .loghist.box itemconfigure $i -background grey
	} else {
	    .loghist.box itemconfigure $i -background white
	}
	set s [expr $s ^ 1]
    }
    incr qsocount($band)
    .bandmap.l$band configure -text "($qsocount($band))" -font sotamicro
}

proc logwindow {ref info} {

    global band box qsocount bandlist tcl_platform mode

    wm title . "SOTALog by HB9TVK"
    wm geometry . "800x480+0+0"
    update idletasks

    set band 40m

    bind . <Return> { saveLog }
    bind . <Escape> { clear }
    bind . <comma> { clear }
    bind . <Prior> { bandSwitch 0 }
    bind . <Next> { bandSwitch 1 }
    bind . <F10> { configDialog }
    bind . <F9> { s2sDialog }
    bind . <Up> { s2sDialog }
    bind . <F8> { modeToggle }
    bind . <Home> { focus [tk_focusPrev [focus]]}
    bind . <End> { focus [tk_focusNext [focus]]}

    frame .top

    frame .sotalog
    label .sotalog.ref -text $ref -font sotabig
    label .sotalog.info -text $info -font sotabig 

    label .sotalog.lcall -text Call
    label .sotalog.lrsts -text RSTs
    label .sotalog.lrstr -text RSTr
    label .sotalog.lrem -text Remarks
    label .sotalog.s2s -text "" -font sotamini

    entry .sotalog.call -font sotahuge -width 12 -highlightthickness 4 -highlightcolor red -validatecommand {processCall %v %d %S %V %P} -validate all
    entry .sotalog.rsts -width 3 -font sotahuge -highlightthickness 4 -highlightcolor red -validatecommand {processRSTs %v %d %S %V} -validate all
    entry .sotalog.rstr -width 3 -font sotahuge -highlightthickness 4 -highlightcolor red -validatecommand {processRSTr %v %d %S %V} -validate all
    entry .sotalog.rem  -width 6 -font sotahuge -highlightthickness 4 -highlightcolor red -validate key -validatecommand {filterRemark %d %S}

    grid .sotalog.ref -row 0 -column 0 -columnspan 4 -sticky n
    grid .sotalog.info -row 1 -column 0 -columnspan 4 -sticky n
    grid .sotalog.s2s -row 2 -column 0 -columnspan 4 -sticky n
    grid .sotalog.call -row 3 -column 0 -sticky w
    grid .sotalog.rsts -row 3 -column 1
    grid .sotalog.rstr -row 3 -column 2
    grid .sotalog.rem -row 3 -column 3
    grid .sotalog.lcall -row 4 -column 0 -sticky w
    grid .sotalog.lrsts -row 4 -column 1
    grid .sotalog.lrstr -row 4 -column 2
    grid .sotalog.lrem -row 4 -column 3

    frame .bandmap
    set i 0
    foreach {wl fq} $bandlist {
        radiobutton .bandmap.w$wl -text "$wl" -variable band -value "$wl" -font sotamicro \
            -takefocus 0 -selectcolor yellow -indicatoron 0 -pady -2
    	label .bandmap.l$wl -text "($qsocount($band))" -font sotamicro
        grid .bandmap.l$wl -row $i -column 0
        grid .bandmap.w$wl -row $i -column 1 -sticky w
    	incr i
    }

    frame .loghist
    listbox .loghist.box -width 60 -height 5 -listvariable box -selectmode single \
	-font sotamono -activestyle none -takefocus 0 -yscrollcommand {.loghist.scy set}
    scrollbar .loghist.scy -command ".loghist.box yview" -orient v -takefocus 0
    grid .loghist.box -row 0 -column 0
    grid .loghist.scy -row 0 -column 1 -sticky nsew

    frame .suggest
    if {[string match Linux* $tcl_platform(os)]} {
        text .suggest.txt -background white -tabs 15 -wrap word -font sotamono -foreground blue \
	-width 60 -height 7
    } else {
        text .suggest.txt -background white -tabs 15 -wrap word -font sotamono -foreground blue \
	-width 60 -height 4
    }
    .suggest.txt configure -state disabled
    grid .suggest.txt -row 0 -column 0

    bind .suggest.txt <ButtonPress> {pickSuggestion %x %y}
    bind .suggest.txt <ButtonRelease> { focus .sotalog.rsts }
    
    label .footer -text "F9: S2S entry   F10: Configuration" -font sotamicro
    
    grid .sotalog -in .top -row 0 -column 0 -sticky s
    grid .bandmap -in .top -row 0 -column 1 -sticky e
    grid .loghist -in .top -row 1 -column 0 -columnspan 2 -sticky wens
    grid .suggest -in .top -row 2 -column 0 -columnspan 2 -sticky wens
    grid .footer -in .top -row 3 -column 0 -columnspan 2 -sticky s

    pack .top
    focus .sotalog.call

}
# MAIN
# determine working directory to find data files

set cwd [file dirname [file normalize $argv0]]
if {[info exists ::starkit::mode]} {
    set cwd [file dirname [file dirname [file normalize $argv0]]]
}

#if {$tcl_platform(os) == "Darwin"} {
#    set cwd [file dirname [file dirname [file dirname [file dirname [file normalize $argv0]]]]]
#}

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
