proc readLog {} {
    # Reloads an activation already in progress.  Each row is
    #   0:"V2" 1:mycall 2:ref 3:date 4:utc 5:freq 6:mode 7:call 8:s2s 9:remark
    # Band is left where the last logged QSO was, so a resumed session carries
    # on where it stopped.  Mode deliberately is not restored: it stays at the
    # session default instead of following whatever the final QSO happened to
    # use.
    global logfile bandlist band cwd

    set fh [open [file join $cwd $logfile] r]
    fconfigure $fh -encoding utf-8
    while {![eof $fh]} {
        gets $fh csvline
        if {![string length $csvline]} { continue }
        set csvline [split $csvline ,]
        set call [lindex $csvline 7]
        set utc [lindex $csvline 4]
        set fq [lindex $csvline 5]
        set pos [lsearch -exact $bandlist $fq]
        incr pos -1
        set band [lindex $bandlist $pos]
        set allrem [string trim [lindex [lrange $csvline 9 end] 0] \"]
        set rsts ""
        set rstr ""
        set rem ""
        # The remark column holds "RSTS:nnn RSTR:nnn <remark>", with either
        # report or the remark possibly absent.  The received report needs the
        # trailing remark to be optional - requiring a space after it meant
        # every QSO logged without a remark came back with an empty RSTr - and
        # the report itself is not always three characters, since SSB reports
        # are entered as two.
        regexp {RSTS:([0-9]+)} $allrem - rsts
        regexp {RSTR:([0-9]+)\s*(.*)$} $allrem - rstr rem
        insertLog $utc $call $rsts $rstr $rem
    }
    close $fh
}

proc openLog {ref} {

    global logfile adif utcDate entryMode cwd

    regsub / $ref _ ref
    set logfile "[clock format [clock seconds] -format %Y-%m-%d]_${ref}.csv"
    set adif  "[clock format [clock seconds] -format %Y-%m-%d]_${ref}.adi"
    
    if {$entryMode} {
	if {[regexp {([0-9]+)/([0-9]+)/([0-9]+)} $utcDate - dd mm yy]} {
	    set logfile "${yy}-${mm}-${dd}_${ref}.csv"
	    set adif  "${yy}-${mm}-${dd}_${ref}.adi"
	}
    }
    
    if {[file exists [file join $cwd $logfile]]} {
	readLog
    }		
}

proc saveLog {} {

    global box band ref logfile w2f adif myCall s2s cwd mode entryMode utcDate

    if {[string length [.sotalog.call get]] == 0} {
        clear
        return
    }
    
    set utc [clock format [clock seconds] -gmt true -format %H%M]
    set csvdate [clock format [clock seconds] -format %d/%m/%Y]
    set adifdate [clock format [clock seconds] -format %Y%m%d]
	
    if {$entryMode} {
	set utc [.sotalog.utc get]
	set csvdate $utcDate
	if {[regexp {([0-9]+)/([0-9]+)/([0-9]+)} $csvdate - dd mm yy]} {
	    set adifdate ${yy}${mm}${dd}
	}
    }

    insertLog $utc [.sotalog.call get] [.sotalog.rsts get] [.sotalog.rstr get] [.sotalog.rem get] 
    
    set call [string trim [.sotalog.call get]]
    set rem ""
    if {[string length [.sotalog.rsts get]]} {
	append rem "RSTS:[.sotalog.rsts get] "
    }
    if {[string length [.sotalog.rstr get]]} {
	append rem "RSTR:[.sotalog.rstr get] "
    }
    if {[string length $s2s]} {
        append rem "S2S:$s2s "
    }
    append rem [.sotalog.rem get]
    set rem [string trim $rem]
    #set csv "$myCall,$csvdate,$utc,$ref,$w2f($band),CW,$call,RSTS:[.sotalog.rsts get] RSTR:[.sotalog.rstr get] [.sotalog.rem get]" 
    set csv "V2,$myCall,$ref,$csvdate,$utc,$w2f($band),$mode,$call,$s2s,\"${rem}\"" 
    set fh [open [file join $cwd $logfile] a]
    fconfigure $fh -encoding utf-8
    puts $fh $csv
    close $fh
    # <qso_date:8:d>20120728 <time_on:4>1208 <call:6>OM3CHR <band:3>30M 
    # <mode:2>CW <rst_sent:3>599 <rst_rcvd:3>599 <station_callsign:8>HB9TVK/P <APP_DXKeeper_TEMP:14>SOTA HB/LU-021 <eor>

    set ad "<qso_date:[string length $adifdate]:d>$adifdate "
    append ad "<time_on:4>$utc "
    append ad "<call:[string length $call]>$call "
    append ad "<band:[string length [string trim $band]]>[string toupper [string trim $band]] "
    append ad "<mode:[string length $mode]>$mode "
    # An ADIF field declares its own length, so it cannot be written with a
    # fixed 3: an empty report produced "<rst_sent:3>" followed by nothing,
    # which contradicts itself, and a two-character SSB report like 59 was
    # declared as three.  Omit the field entirely when there is no report.
    set adifRsts [string trim [.sotalog.rsts get]]
    set adifRstr [string trim [.sotalog.rstr get]]
    if {[string length $adifRsts]} {
        append ad "<rst_sent:[string length $adifRsts]>$adifRsts "
    }
    if {[string length $adifRstr]} {
        append ad "<rst_rcvd:[string length $adifRstr]>$adifRstr "
    }
    append ad "<station_callsign:[string length $myCall]>$myCall "
    #append ad "<APP_DXKeeper_TEMP:[expr [string length $ref] + 5]>SOTA $ref <eor>"
    set comment "SOTA $ref"
    if {[string length $s2s]} {
        append comment " S2S with $s2s"
    }
    if {[string length [.sotalog.rem get]]} {
        append comment " Remark: [.sotalog.rem get]"
    }
    append ad "<comment_intl:[string length $comment]>$comment <eor>"
    
    set fh [open [file join $cwd $adif] a]
    fconfigure $fh -encoding utf-8
    puts $fh $ad
    close $fh
    clear
}
