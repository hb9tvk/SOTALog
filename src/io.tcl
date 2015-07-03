proc readLog {} {
    global logfile bandlist band cwd mode

    set fh [open [file join $cwd $logfile] r]
    while {![eof $fh]} {
        gets $fh csvline
        if {![string length $csvline]} { continue }
        set csvline [split $csvline ,]
        set call [lindex $csvline 7]
        set utc [lindex $csvline 4]
        set fq [lindex $csvline 5]
        set mode [lindex $csvline 6]
        set pos [lsearch -exact $bandlist $fq]
        incr pos -1
        set band [lindex $bandlist $pos]
        set allrem [string trim [lindex [lrange $csvline 9 end] 0] \"]
        set rsts ""
        set rstr ""
        set rem ""
        regexp {RSTS:([0-9]{3})} $allrem - rsts
        regexp {RSTR:([0-9]{3}) (.*)$} $allrem - rstr rem
        insertLog $utc $call $rsts $rstr $rem
    }
}

proc openLog {ref} {

    global logfile adif

    regsub / $ref _ ref
    set logfile "[clock format [clock seconds] -format %Y-%m-%d]_${ref}.csv"
    set adif  "[clock format [clock seconds] -format %Y-%m-%d]_${ref}.adi"
    if {[file exists $logfile]} {
	readLog
    }		
}

proc saveLog {} {

    global box band ref logfile w2f adif myCall s2s cwd mode

    if {[string length [.sotalog.call get]] == 0} {
        clear
        return
    }
    set utc [clock format [clock seconds] -gmt true -format %H%M]

    insertLog $utc [.sotalog.call get] [.sotalog.rsts get] [.sotalog.rstr get] [.sotalog.rem get] 

    set csvdate [clock format [clock seconds] -format %d/%m/%Y]
    set call [string trim [.sotalog.call get]]
    if {![string length $s2s]} {
        set rem "RSTS:[.sotalog.rsts get] RSTR:[.sotalog.rstr get] [.sotalog.rem get]"
    } else {
        set rem "RSTS:[.sotalog.rsts get] RSTR:[.sotalog.rstr get] S2S:$s2s [.sotalog.rem get]"
    }
    #set csv "$myCall,$csvdate,$utc,$ref,$w2f($band),CW,$call,RSTS:[.sotalog.rsts get] RSTR:[.sotalog.rstr get] [.sotalog.rem get]" 
    set csv "V2,$myCall,$ref,$csvdate,$utc,$w2f($band),$mode,$call,$s2s,\"${rem}\"" 
    set fh [open [file join $cwd $logfile] a]
    puts $fh $csv
    close $fh
    # <qso_date:8:d>20120728 <time_on:4>1208 <call:6>OM3CHR <band:3>30M 
    # <mode:2>CW <rst_sent:3>599 <rst_rcvd:3>599 <station_callsign:8>HB9TVK/P <APP_DXKeeper_TEMP:14>SOTA HB/LU-021 <eor>

    set ad "<qso_date:8:d>[clock format [clock seconds] -format %Y%m%d] "
    append ad "<time_on:4>$utc "
    append ad "<call:[string length $call]>$call "
    append ad "<band:[string length $band]>[string toupper $band] "
    append ad "<mode:[string length $mode]>$mode "
    append ad "<rst_sent:3>[.sotalog.rsts get] "
    append ad "<rst_rcvd:3>[.sotalog.rstr get] "
    append ad "<station_callsign:[string length $myCall]>$myCall "
    #append ad "<APP_DXKeeper_TEMP:[expr [string length $ref] + 5]>SOTA $ref <eor>"
    set comment "SOTA $ref"
    if {[string length $s2s]} {
        append comment " S2S with $s2s"
    }
    if {[string length [.sotalog.rem get]]} {
        append comment " Remark: [.sotalog.rem get]"
    }
    append ad "<comment:[string length $comment]>$comment <eor>"
    
    set fh [open [file join $cwd $adif] a]
    puts $fh $ad
    close $fh
    clear
}