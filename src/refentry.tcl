
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

    pack .ref
    focus -force .ref.ref
    raise .ref
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
