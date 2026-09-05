# Everything the application defines - procedures and variables alike - lives
# in this namespace, so nothing of ours sits in the global one beside Tcl's
# and Tk's own commands.
#
# Tk callbacks are the exception that has to be written out in full: bindings,
# -validatecommand, -command, fileevent, after and -progress scripts are all
# evaluated at the global level, as are -variable and -listvariable, so a bare
# name in one of those would no longer resolve.  tests/callbacks.test checks
# that none of them is left unqualified.
namespace eval ::sotalog {
    namespace export *

    # The release version, shown in the window title and used by the macOS
    # build, which reads this line out of this file.
    variable SOTALOG_VERSION 2.2.2
}

# The package version keeps only major.minor, so that it goes on matching the
# "package ifneeded SOTALog 2.2" line in SOTALog.vfs/lib/SOTALog/pkgIndex.tcl.
package provide SOTALog \
    [join [lrange [split $::sotalog::SOTALOG_VERSION .] 0 1] .]

package require Tk
package require http

proc ::sotalog::createFonts {} {
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

# Multiplies every application font by factor, for displays too small to show
# the layout at its natural size.  Sizes are held at a floor of 6 points: past
# that the text stops being readable and shrinking further buys nothing.
# Returns 1 if anything actually changed, 0 if every font was already at the
# floor.
proc ::sotalog::scaleFonts {factor} {
    set changed 0
    foreach f {sotahuge sotabig sotasmall sotamini sotamicro sotamono} {
        set size [font configure $f -size]
        set new [expr {int($size * $factor)}]
        if {$new < 6} { set new 6 }
        if {$new != $size} {
            font configure $f -size $new
            set changed 1
        }
    }
    return $changed
}

# Shrinks the fonts until the main window's layout fits a screen of sw x sh,
# and returns the {width height} the window should use.
#
# The layout is built entirely from point-sized fonts and character-counted
# widget widths, so it scales with the display: about 810x477 at 96 dpi, but
# 1170x701 at 200% scaling and only 273x218 if the fonts are taken right down.
# On a display smaller than the layout's natural size - the 320x240 panels
# this has been run on, for instance - the alternative is clipping the surplus
# off with no way to reach it.
proc ::sotalog::fitToScreen {sw sh} {
    update idletasks

    # Widget widths are given in characters, so the layout scales close to
    # linearly with font size; a couple of passes converge.
    for {set pass 0} {$pass < 3} {incr pass} {
        set w [winfo reqwidth .]
        set h [winfo reqheight .]
        if {$w <= $sw && $h <= $sh} { break }
        if {![scaleFonts [expr {min(double($sw) / $w, double($sh) / $h)}]]} { break }
        update idletasks
    }

    set w [winfo reqwidth .]
    set h [winfo reqheight .]

    # Only still oversized if the fonts hit their legibility floor.  Cap at the
    # screen so the window itself remains usable, and warn: at that point the
    # display is genuinely too small for this layout.
    if {$w > $sw || $h > $sh} {
        logMsg error "layout needs ${w}x${h} but the screen is only ${sw}x${sh};\
            the window will be capped and some of it will not be visible"
        if {$w > $sw} { set w $sw }
        if {$h > $sh} { set h $sh }
    }
    return [list $w $h]
}

proc ::sotalog::Show.Modal {win onclose} {
    set ::sotalog::modalResult {}
    array set options [list -onclose {} -destroy 0 -onclose $onclose ]
    wm transient $win .
    wm protocol $win WM_DELETE_WINDOW [list catch $options(-onclose) ::sotalog::modalResult]
    set x [expr {([winfo width  .] - [winfo reqwidth  $win]) / 2 + [winfo rootx .]} - 150]
    set y [expr {([winfo height .] - [winfo reqheight $win]) / 2 + [winfo rooty .]} - 20]
    wm geometry $win +$x+$y
    raise $win
    focus $win
    grab $win
    tkwait variable ::sotalog::modalResult
    grab release $win
    if {$options(-destroy)} {destroy $win}
    return ${::sotalog::modalResult}
}

# names.txt and sotacalls.txt are hand-maintained ASCII, but say so rather
# than inheriting whatever the system encoding happens to be - that is exactly
# how summits.thm came to be misread.  UTF-8 matches the log files and leaves
# the current contents byte for byte identical.
proc ::sotalog::loadNames {} {

    variable names
    variable cwd

    set fh [open [file join $cwd names.txt] r]
    fconfigure $fh -encoding utf-8
    while {![eof $fh]} {
        gets $fh line
        set names([lindex $line 0]) [lrange $line 1 end]
    }
    close $fh
}

proc ::sotalog::loadSotaCalls {} {

    variable sotacalls
    variable cwd

    set fh [open [file join $cwd sotacalls.txt] r]
    fconfigure $fh -encoding utf-8
    set sotacalls [read $fh]
    close $fh
}
