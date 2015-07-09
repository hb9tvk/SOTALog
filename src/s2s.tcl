
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
    wm title .s2s "S2S entry"

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
