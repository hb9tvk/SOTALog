
# Summit-to-summit entry.
#
# Three fields - association, region, summit number - each narrowing a list of
# candidates as the operator types.  The candidates come from the set-like
# arrays summits.thm provides: assocs is keyed "HB", regions "HB/BE", and refs
# "HB/BE-003".  Each field shows only the part it is responsible for, so the
# fixed prefix is stripped from what is displayed.

# Replaces the suggestion pane, which is kept read-only between updates.
proc ::sotalog::showS2sSuggestions {matches} {
    .s2s.suggest configure -state normal
    .s2s.suggest delete 1.0 end
    .s2s.suggest insert end $matches
    .s2s.suggest configure -state disabled
}

# Red while what has been typed so far matches nothing known.
proc ::sotalog::markS2sField {entry matches} {
    if {[string length $matches]} {
        $entry configure -fg black
    } else {
        $entry configure -fg red
    }
}

# The candidates for one field: keys of a set-like array matching the glob,
# with the fixed prefix removed so the pane shows only what is being typed.
# Both are shown, and the field is coloured unless no entry is given - the
# focusin branches list candidates without passing judgement on the contents.
proc ::sotalog::s2sSuggest {arrayName pattern strip {entry ""}} {
    upvar #0 $arrayName candidates

    set matches [lsort [array names candidates -glob $pattern]]
    if {$strip ne ""} { regsub -all $strip $matches "" matches }
    showS2sSuggestions $matches
    if {$entry ne ""} { markS2sField $entry $matches }
    return $matches
}

proc ::sotalog::saveS2s {} {
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

proc ::sotalog::validateNum {validation action new vaction newval} {
    set curreg [.s2s.ass get]/[.s2s.reg get]

    if {$vaction eq "key" && $action == 1} {
        if {$new eq ","} { return 0 }
        after idle [list .s2s.num configure -validate $validation]
        if {![regexp {[0-9]} $new]} { return 0 }

        .s2s.num insert insert $new
        s2sSuggest refs *${curreg}-*[.s2s.num get]* ${curreg}- .s2s.num
        return 1
    }
    if {$vaction eq "key" && $action == 0} {
        s2sSuggest refs *${curreg}-*${newval}* ${curreg}- .s2s.num
        return 1
    }
    if {$vaction eq "focusin"} {
        # No leading star here, unlike the two branches above.  It makes no
        # practical difference, because a reference never has anything before
        # its region, but it is left as it was.
        s2sSuggest refs ${curreg}-*[.s2s.num get]* ${curreg}-
    }
    return 1
}

proc ::sotalog::validateReg {validation action new vaction newval} {
    global regions

    set curass [.s2s.ass get]

    if {$vaction eq "key" && $action == 1} {
        if {$new eq ","} { return 0 }
        after idle [list .s2s.reg configure -validate $validation]
        if {$new eq " " || $new eq "-"} {
            focus .s2s.num
            return 0
        }
        if {![regexp {[A-Za-z0-9/]} $new]} { return 0 }

        .s2s.reg insert insert [string toupper $new]
        s2sSuggest regions *${curass}/[.s2s.reg get]* ${curass}/ .s2s.reg

        # Every region code is two characters, so the second one finishes it.
        if {[string length [.s2s.reg get]] == 2} {
            focus .s2s.num
            return 0
        }
        return 1
    }
    if {$vaction eq "key" && $action == 0} {
        s2sSuggest regions *${curass}/${newval}* ${curass}/ .s2s.reg
        return 1
    }
    if {$vaction eq "focusout"} {
        if {![string length [array names regions -exact ${curass}/[.s2s.reg get]]]} {
            .s2s.reg configure -fg red
        }
    }
    if {$vaction eq "focusin"} {
        s2sSuggest regions *${curass}/[.s2s.reg get]* ${curass}/
    }
    return 1
}

proc ::sotalog::validateAss {validation action new vaction newval} {
    global assocs

    if {$vaction eq "key" && $action == 1} {
        if {$new eq ","} { return 0 }
        after idle [list .s2s.ass configure -validate $validation]
        if {$new eq " " || $new eq "/"} {
            if {![string length [array names assocs -exact [.s2s.ass get]]]} {
                .s2s.ass configure -fg red
            }
            focus .s2s.reg
            return 0
        }
        if {![regexp {[A-Za-z0-9/]} $new]} { return 0 }

        .s2s.ass insert insert [string toupper $new]
        # Nothing to strip: an association code is the whole key.
        set matches [s2sSuggest assocs *[.s2s.ass get]* "" .s2s.ass]

        # Three characters is the longest an association code gets.
        if {[string length [.s2s.ass get]] == 3} {
            focus .s2s.reg
            return 0
        }
        # Only one candidate left, so it is the answer: fill it in and move on.
        if {[llength $matches] == 1} {
            .s2s.ass delete 0 end
            .s2s.ass insert end $matches
            focus .s2s.reg
        }
        return 1
    }
    if {$vaction eq "key" && $action == 0} {
        s2sSuggest assocs *${newval}* "" .s2s.ass
        return 1
    }
    if {$vaction eq "focusout"} {
        if {![string length [array names assocs -exact [.s2s.ass get]]]} {
            .s2s.ass configure -fg red
        }
    }
    return 1
}

# Builds the dialog and its bindings.  Kept separate from s2sDialog so that
# the entry validation can be exercised without entering the modal loop.
proc ::sotalog::s2sWidgets {} {
    global assocs s2s

    toplevel .s2s
    wm title .s2s "S2S entry"

    bind .s2s <Return> {set ::Modal.Result 1}
    bind .s2s <Escape> {set ::Modal.Result 0}
    bind .s2s <comma>  {set ::Modal.Result 0}
    bind .s2s <Home> { focus [tk_focusPrev [focus]]}
    bind .s2s <End> { focus [tk_focusNext [focus]]}

    label .s2s.slash -text "/" -font sotahuge
    label .s2s.dash -text "-" -font sotahuge

    entry .s2s.ass -width 4 -font sotahuge -bd 1 -validatecommand {::sotalog::validateAss %v %d %S %V %P} -validate all
    entry .s2s.reg -width 3 -font sotahuge -bd 1 -validatecommand {::sotalog::validateReg %v %d %S %V %P} -validate all
    entry .s2s.num -width 4 -font sotahuge -bd 1 -validatecommand {::sotalog::validateNum %v %d %S %V %P} -validate all

    text .s2s.suggest -background white -wrap word -font sotamono -foreground blue \
    -width 40 -height 8
    .s2s.suggest insert end [lsort [array names assocs]]
    .s2s.suggest configure -state disabled

    # Reopening the dialog starts from whatever summit is already selected.
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
}

proc ::sotalog::s2sDialog {} {
    s2sWidgets

    focus .s2s.ass
    if {[Show.Modal .s2s {set ::Modal.Result 0}]} {
        saveS2s
    }
    destroy .s2s
}
