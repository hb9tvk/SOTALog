
proc updateCallsAndSummits {} {
    
    global cwd updated
    
    .cfg.ok configure -state disabled
    .cfg.cancel configure -state disabled
    .cfg.update configure -state disabled
    .cfg.call configure -state disabled
    .cfg.okrprt configure -state disabled
    
    if  {[catch {
        set t [::http::geturl http://sota.hb9tvk.org/sotalog/summits.thm -timeout 120000]
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
    set updated 1
    .cfg.ok configure -state normal
    .cfg.cancel configure -state normal
    .cfg.update configure -state normal
    .cfg.call configure -state normal
    .cfg.okrprt configure -state normal
}
