package provide SOTALog 2.1

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
