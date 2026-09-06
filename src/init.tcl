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

    # How large the log window is drawn, as a percentage of the size the
    # application has always used.  Everything in that window is laid out from
    # point-sized fonts, so scaling the fonts scales the window with them.
    #
    # Only upwards: fitToScreen already shrinks the layout when it will not fit
    # the display, and this is for an operator who needs it larger.
    variable defaultUiScale 100
    variable minUiScale 100
    variable maxUiScale 300
    variable uiScale $defaultUiScale
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
# Keeps the display size within the range the slider offers, so that a
# hand-edited configuration cannot produce a window nothing can read or a font
# too large to lay out.
proc ::sotalog::normaliseUiScale {requested} {
    variable defaultUiScale
    variable minUiScale
    variable maxUiScale

    if {![string is integer -strict $requested]} {
        logMsg error "sotalog.conf has a display size that is not a number, ignored: $requested"
        return $defaultUiScale
    }
    if {$requested < $minUiScale} { return $minUiScale }
    if {$requested > $maxUiScale} { return $maxUiScale }
    return $requested
}

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
# Places a window centred on the main window and keeps it on the screen.
#
# wm geometry sets the position of the window frame, while winfo rootx reports
# the client area inside it.  Mixing the two puts the window out by the size of
# the title bar and border, so the main window position is taken from wm
# geometry, matching what is about to be set, and its size from winfo, which is
# the area the operator sees.
# Places a window centred on the main window and keeps it on the screen.
#
# What gets centred is the client areas - the part the operator sees - not the
# window frames.  The two differ: wm geometry positions the frame, winfo rootx
# reports the client area inside it, and the border is not the same for every
# window.  The main window's is 11 across and 45 down here, a dialog that
# cannot be resized gets 3 and 37, so centring frame on frame leaves it eight
# pixels out.
#
# There is no way to ask how thick a window's border is before it has one, so
# the window is placed, measured, and corrected by however far the client area
# landed from where it was wanted.
proc ::sotalog::centreOnMain {win} {
    # Until the geometry manager has run, the requested size is whatever it
    # happened to be part way through building the window.
    update idletasks

    set width [winfo reqwidth $win]
    set height [winfo reqheight $win]

    set wantX [expr {[winfo rootx .] + ([winfo width .] - $width) / 2}]
    set wantY [expr {[winfo rooty .] + ([winfo height .] - $height) / 2}]

    wm geometry $win +$wantX+$wantY
    update idletasks
    set x [expr {2 * $wantX - [winfo rootx $win]}]
    set y [expr {2 * $wantY - [winfo rooty $win]}]

    # Centring on the main window is not enough when the main window is itself
    # near an edge of the screen.
    set x [clampToScreen $x $width [winfo screenwidth $win]]
    set y [clampToScreen $y $height [winfo screenheight $win]]
    wm geometry $win +$x+$y
}

# Runs a dialog modally, centred on the main window, and returns 1 if it was
# accepted.
proc ::sotalog::Show.Modal {win onclose} {
    variable modalResult

    set modalResult {}
    wm transient $win .
    wm protocol $win WM_DELETE_WINDOW [list catch $onclose ::sotalog::modalResult]

    centreOnMain $win

    raise $win
    focus $win
    grab $win
    tkwait variable ::sotalog::modalResult
    grab release $win

    return $modalResult
}

# A message the operator has to acknowledge.
#
# This replaces tk_messageBox, which on Windows is the native system box: it
# centres on the screen rather than on the application, ignores the fonts the
# rest of the application uses, and cannot be inspected by the tests.  Icon is
# one of the Tk bitmaps info, warning or error.
proc ::sotalog::showMessage {icon title message} {
    variable messageResult

    set win .message
    destroy $win
    toplevel $win
    wm title $win $title
    wm resizable $win 0 0

    label $win.icon -bitmap $icon
    label $win.text -text $message -font sotasmall -justify left
    button $win.ok -text OK -font sotasmall -width 8 \
        -command {set ::sotalog::messageResult 1}

    grid $win.icon -row 0 -column 0 -padx 12 -pady 12
    grid $win.text -row 0 -column 1 -padx 12 -pady 12 -sticky w
    grid $win.ok -row 1 -column 0 -columnspan 2 -pady 8

    bind $win <Return> {set ::sotalog::messageResult 1}
    bind $win <Escape> {set ::sotalog::messageResult 1}
    wm transient $win .
    wm protocol $win WM_DELETE_WINDOW {set ::sotalog::messageResult 1}

    centreOnMain $win

    # A message can be raised from inside another modal dialog - the update
    # progress runs inside the configuration dialog - so the grab that was in
    # force has to be put back rather than simply released.
    set previousGrab [grab current $win]

    set messageResult {}
    raise $win
    focus $win.ok
    grab $win
    tkwait variable ::sotalog::messageResult
    grab release $win
    destroy $win
    if {$previousGrab ne ""} { catch {grab $previousGrab} }
}

# names.txt and sotacalls.txt are hand-maintained ASCII, but say so rather
# than inheriting whatever the system encoding happens to be - that is exactly
# how summits.thm came to be misread.  UTF-8 matches the log files and leaves
# the current contents byte for byte identical.
# The operator names, keyed by callsign.
#
# Separator tolerance is deliberate.  The file bundled with the application
# separates the call from the name with a space, the maintained one at qsl.net
# does the same but starts with a "# Call Name" comment, and the mirror on
# sota.hb9tvk.org serves it comma-separated with a "Call,Name" heading.  All
# three load.
#
# A callsign always contains a digit, which is what distinguishes a real entry
# from a heading or anything else that finds its way in.  Parsing with a
# regular expression rather than list commands also means a stray brace in the
# file cannot throw.
proc ::sotalog::loadNames {} {
    variable names
    variable cwd

    array unset names
    set fh [open [file join $cwd names.txt] r]
    fconfigure $fh -encoding utf-8

    set skipped 0
    while {![eof $fh]} {
        gets $fh line
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} { continue }

        if {![regexp {^(\S+?)[,[:space:]][[:space:]]*(.*)$} $line -> call name]
            || ![regexp {[0-9]} $call]} {
            incr skipped
            continue
        }
        set names($call) $name
    }
    close $fh

    logMsg info "loaded [array size names] operator names, ignored $skipped line(s)"
}

proc ::sotalog::loadSotaCalls {} {

    variable sotacalls
    variable cwd

    set fh [open [file join $cwd sotacalls.txt] r]
    fconfigure $fh -encoding utf-8
    set sotacalls [read $fh]
    close $fh
}
