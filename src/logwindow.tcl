
proc ::sotalog::clear {} {
    global sinfo s2s mode entryMode
    .sotalog.call delete 0 end
    .sotalog.rsts delete 0 end
    .sotalog.rstr delete 0 end
    .sotalog.rem delete 0 end
    .loghist.box selection clear 0 end
    .sotalog.info configure -text "$sinfo Mode: $mode" -fg black
    .sotalog.s2s configure -text ""
    set s2s ""
    if {$entryMode} {
	.sotalog.utc delete 0 end
	focus .sotalog.utc
    } else {
	focus .sotalog.call
    }
}

proc ::sotalog::initCounter {} {
    global qsocount bandlist

    foreach {wl fq} $bandlist {
        set qsocount($wl) 0
    }
}

proc ::sotalog::modeToggle {} {
    global mode modes sinfo
    set pos [lsearch -exact $modes $mode]
    incr pos
    if {$pos == [llength $modes]} { set pos 0}
    set mode [lindex $modes $pos]
    .sotalog.info configure -text "$sinfo Mode: $mode"
}

proc ::sotalog::bandSwitch {up} {
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

proc ::sotalog::updateSuggestions {part} {

    global sotacalls

    set suggest [lsearch -all -glob -inline $sotacalls "*${part}*"]
    .suggest.txt configure -state normal
    .suggest.txt delete 1.0 end
    .suggest.txt insert end $suggest
    .suggest.txt configure -state disabled
}

proc ::sotalog::pickSuggestion {x y} {

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

proc ::sotalog::insertLog {utc call rsts rstr rem} {

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

proc ::sotalog::logwindow {ref info} {

    global band box qsocount bandlist tcl_platform mode entryMode

    wm title . "SOTALog v$::SOTALOG_VERSION by HB9TVK"
    # Position only - the size is worked out from the finished layout at the
    # end of this procedure.
    wm geometry . +0+0
    update idletasks

    set band 40m

    bind . <Return> { ::sotalog::saveLog }
    bind . <Escape> { ::sotalog::clear }
    bind . <comma> { ::sotalog::clear }
    bind . <Prior> { ::sotalog::bandSwitch 0 }
    bind . <Next> { ::sotalog::bandSwitch 1 }
    bind . <F10> { ::sotalog::configDialog }
    bind . <F9> { ::sotalog::s2sDialog }
    bind . <Up> { ::sotalog::s2sDialog }
    bind . <F8> { ::sotalog::modeToggle }
    bind . <Home> { focus [tk_focusPrev [focus]]}
    bind . <End> { focus [tk_focusNext [focus]]}

    frame .top

    frame .sotalog
    label .sotalog.ref -text [string range $ref 0 31] -font sotabig
    label .sotalog.info -text $info -font sotabig 

    label .sotalog.lcall -text Call
    label .sotalog.lrsts -text RSTs
    label .sotalog.lrstr -text RSTr
    label .sotalog.lrem -text Remarks
    label .sotalog.s2s -text "" -font sotamini

    set remwidth 6
    if {$entryMode} {
	entry .sotalog.utc -font sotahuge -width 4 -highlightthickness 4 -highlightcolor red -validatecommand {::sotalog::processUTC %v %d %S %V %P} -validate all
	label .sotalog.lutc -text UTC
	set remwidth 3
    }
    
    entry .sotalog.call -font sotahuge -width 12 -highlightthickness 4 -highlightcolor red -validatecommand {::sotalog::processCall %v %d %S %V %P} -validate all
    entry .sotalog.rsts -width 3 -font sotahuge -highlightthickness 4 -highlightcolor red -validatecommand {::sotalog::processRSTs %v %d %S %V} -validate all
    entry .sotalog.rstr -width 3 -font sotahuge -highlightthickness 4 -highlightcolor red -validatecommand {::sotalog::processRSTr %v %d %S %V} -validate all
    entry .sotalog.rem  -width $remwidth -font sotahuge -highlightthickness 4 -highlightcolor red -validate key -validatecommand {::sotalog::filterRemark %d %S}

    grid .sotalog.ref -row 0 -column 0 -columnspan 5 -sticky n
    grid .sotalog.info -row 1 -column 0 -columnspan 5 -sticky n
    grid .sotalog.s2s -row 2 -column 0 -columnspan 5 -sticky n
    if {$entryMode} {
	grid .sotalog.utc .sotalog.call .sotalog.rsts .sotalog.rstr .sotalog.rem  -row 3 -sticky w
    } else {
	grid .sotalog.call .sotalog.rsts .sotalog.rstr .sotalog.rem  -row 3 -sticky w
    }
 
    if {$entryMode} {
	grid .sotalog.lutc .sotalog.lcall .sotalog.lrsts .sotalog.lrstr .sotalog.lrem -row 4  -sticky w
    } else {
	grid .sotalog.lcall .sotalog.lrsts .sotalog.lrstr .sotalog.lrem -row 4 -sticky w
    }

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

    bind .suggest.txt <ButtonPress> {::sotalog::pickSuggestion %x %y}
    bind .suggest.txt <ButtonRelease> { focus .sotalog.rsts }
    
    label .footer -text "F8: Toggle Mode   F9: S2S entry   F10: Configuration" -font sotamicro
    
    grid .sotalog -in .top -row 0 -column 0 -sticky s
    grid .bandmap -in .top -row 0 -column 1 -sticky e
    grid .loghist -in .top -row 1 -column 0 -columnspan 2 -sticky wens
    grid .suggest -in .top -row 2 -column 0 -columnspan 2 -sticky wens
    grid .footer -in .top -row 3 -column 0 -columnspan 2 -sticky s

    pack .top

    # Size the window from what the layout actually needs.  This used to be a
    # hardcoded 800x480, right for the 96 dpi screens of 2015 - the layout
    # asks for 810x477 there.  It scales with the display, though, wanting
    # 1170x701 at 200%, and the surplus was simply clipped, which is why the
    # window had to be dragged open by hand.  fitToScreen shrinks the fonts
    # instead on a display too small for the layout, so nothing is lost.
    lassign [fitToScreen [winfo screenwidth .] [winfo screenheight .]] winw winh
    wm geometry . [set winw]x[set winh]+0+0
    wm minsize . $winw $winh

    if {$entryMode} {
	focus .sotalog.utc
    } else {
	focus .sotalog.call
    }
}
