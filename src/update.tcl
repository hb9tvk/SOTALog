
proc updateProgress {token total current} {
    set prg [expr $current * 100 / $total]
    .cfg.progress configure -value $prg
}

proc updateCallsAndSummits {} {

    global cwd updated

    .cfg.ok configure -state disabled
    .cfg.cancel configure -state disabled
    .cfg.update configure -state disabled
    .cfg.call configure -state disabled
    .cfg.okrprt configure -state disabled

    ttk::progressbar .cfg.progress -mode determinate
    label .cfg.progresslabel -font sotasmall
    grid .cfg.progresslabel -row 6 -column 0
    grid .cfg.progress -row 6 -column 1 -sticky ew

    if  {[catch {
        .cfg.progresslabel configure -text "Updating summit list:"
        set t [::http::geturl http://sota.hb9tvk.org/sotalog/summits.thm -timeout 600000 -progress updateProgress]
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
        .cfg.progresslabel configure -text "Updating SOTA callsigns:"
        set t [::http::geturl http://sota.hb9tvk.org/sotalog/sotacalls.txt -timeout 120000]
        set sc [::http::data $t]
        ::http::cleanup $t
    } msg]} {
        tk_messageBox -icon error -message "Error updating calls: $msg" -type ok
    } else {
        set fh [open [file join $cwd sotacalls.txt] w]
        puts $fh $sc
        close $fh
    }

    grid remove .cfg.progress
    grid remove .cfg.progresslabel
    destroy .cfg.progress
    destroy .cfg.progresslabel

    tk_messageBox -icon info -message "Summits and calls updated successfully" -type ok
    set updated 1
    .cfg.ok configure -state normal
    .cfg.cancel configure -state normal
    .cfg.update configure -state normal
    .cfg.call configure -state normal
    .cfg.okrprt configure -state normal


}
