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
    variable SOTALOG_VERSION 2.3.0

    # The modes F8 cycles through.  Only CW gets the one-key report expansion;
    # SSB and FM reports are typed in full.
    #
    # Declared here rather than in main.tcl so that the tests see the same list
    # the application does - main.tcl is the startup script and is not loaded
    # under test, so anything it declares has to be duplicated in the harness,
    # and duplicated lists drift.
    variable modes [list CW SSB FM]

    # Every band SOTA accepts, with the frequency string the CSV records for
    # it, lowest frequency first.
    #
    # The eight bands the application has always offered keep the strings it
    # has always written.  Those differ from the values SOTA documents - 7.0MHz
    # where the specification says 7MHz, 10.1MHz where it says 10MHz - but they
    # have been accepted for a decade, and changing them now would leave new
    # logs inconsistent with old ones.  The bands added in 2026 use the
    # documented values.
    variable allBands [list \
        160m 1.8MHz \
        80m  3.5MHz \
        60m  5.0MHz \
        40m  7.0MHz \
        30m  10.1MHz \
        20m  14.0MHz \
        17m  18.0MHz \
        15m  21.0MHz \
        12m  24.8MHz \
        10m  28MHz \
        6m   50MHz \
        4m   70MHz \
        2m   144MHz \
        70cm 432MHz \
        23cm 1240MHz]

    # Shown when nothing has been configured: the eight bands the application
    # offered before they became selectable.
    variable defaultBands [list 60m 40m 30m 20m 17m 15m 12m 10m]

    # The bands actually offered this session.  loadConfig replaces this with
    # whatever has been chosen; it is declared here so that it always exists,
    # including under test, where main.tcl never runs.
    variable bands $defaultBands

    # The bands actually offered this session.  loadConfig replaces this with
    # whatever has been chosen; it is declared here so that it always exists,
    # including under test where main.tcl never runs.
    variable bands 

    # Wavelength to frequency and back, over every band rather than only the
    # selected ones.  A log may hold QSOs on a band that is no longer shown,
    # and it still has to be read back and written out correctly.
    variable w2f
    variable f2w
    array set w2f $allBands
    foreach {sotalogWavelength sotalogFrequency} $allBands {
        set f2w($sotalogFrequency) $sotalogWavelength
    }
    unset sotalogWavelength sotalogFrequency
}

# The package version keeps only major.minor, so that it goes on matching the
# "package ifneeded SOTALog 2.3" line in SOTALog.vfs/lib/SOTALog/pkgIndex.tcl.
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

# Keeps a window of the given size on a screen of the given size: shifts it
# back inside if it would hang off the far edge, and never past the near one.
proc ::sotalog::clampToScreen {position size screen} {
    if {$position + $size > $screen} { set position [expr {$screen - $size}] }
    if {$position < 0} { set position 0 }
    return $position
}

# Runs a dialog modally, centred on the main window, and returns 1 if it was
# accepted.
proc ::sotalog::Show.Modal {win onclose} {
    variable modalResult

    set modalResult {}
    wm transient $win .
    wm protocol $win WM_DELETE_WINDOW [list catch $onclose ::sotalog::modalResult]

    # Let the geometry manager finish before measuring.  Without this the
    # requested size is whatever it happened to be part way through building
    # the dialog - about 200x200 for the configuration dialog - and centring
    # on that puts the window somewhere arbitrary.  It used to land partly
    # below the main window, which matters on a small screen.
    update idletasks

    set width [winfo reqwidth $win]
    set height [winfo reqheight $win]

    # wm geometry sets the position of the window frame, while winfo rootx
    # reports the client area inside it.  Mixing the two puts the dialog out by
    # the size of the title bar and border - 11 across and 45 down on Windows.
    # Take the main window position from wm geometry, to match what is about to
    # be set, and its size from winfo, which is the area the operator sees.
    if {![regexp {\+(-?[0-9]+)\+(-?[0-9]+)$} [wm geometry .] -> mainX mainY]} {
        set mainX [winfo rootx .]
        set mainY [winfo rooty .]
    }
    set x [expr {$mainX + ([winfo width .] - $width) / 2}]
    set y [expr {$mainY + ([winfo height .] - $height) / 2}]

    # A dialog centred on the main window can still hang off the screen when
    # the main window is itself near an edge.
    set x [clampToScreen $x $width [winfo screenwidth $win]]
    set y [clampToScreen $y $height [winfo screenheight $win]]
    wm geometry $win +$x+$y

    raise $win
    focus $win
    grab $win
    tkwait variable ::sotalog::modalResult
    grab release $win

    return $modalResult
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
