# Reading and writing the activation log.
#
# A QSO travels between the entry fields, the two log files and the on-screen
# list as a dictionary, so that the formats can be produced and parsed without
# a widget in sight:
#
#   utc       time as four digits, "1205"
#   date      the date as the CSV spells it, "05/09/2025"
#   adifdate  the same date as ADIF spells it, "20250905"
#   call      the station worked
#   rsts      report sent, may be empty
#   rstr      report received, may be empty
#   rem       the operator's remark, without the report prefixes
#   s2s       the other summit for a summit-to-summit contact, else empty
#   band      wavelength, "40m"
#   freq      band edge as the CSV records it, "7.0MHz"
#   mode      "CW" or "SSB"
#   mycall    the operator's own call
#   ref       the summit being activated
#
# The date appears twice because the two files disagree about how to write it
# and, in UTC entry mode, it comes from the configured activation date rather
# than from the clock.  Working that out is the entry fields' business, so
# qsoFromEntry does it once and the formatters stay total.

# The CSV keeps both reports and the summit-to-summit reference inside the
# remark column, ahead of whatever the operator typed.
proc ::sotalog::formatQsoCsv {qso} {
    set rem ""
    foreach {prefix key} {RSTS rsts RSTR rstr S2S s2s} {
        set value [dict get $qso $key]
        if {[string length $value]} { append rem "$prefix:$value " }
    }
    append rem [dict get $qso rem]
    set rem [string trim $rem]

    # Built as a list join rather than one interpolated string: a backslash
    # continuation inside a quoted string collapses to a space, which would
    # quietly insert spaces into the middle of the record.
    return [join [list \
        V2 \
        [dict get $qso mycall] \
        [dict get $qso ref] \
        [dict get $qso date] \
        [dict get $qso utc] \
        [dict get $qso freq] \
        [dict get $qso mode] \
        [dict get $qso call] \
        [dict get $qso s2s] \
        "\"$rem\""] ,]
}

# The inverse: pull a QSO back out of one CSV line.  The band is not recovered
# here because only the frequency is recorded and mapping it back needs the
# band table; readLog does that.
proc ::sotalog::parseQsoCsv {line} {
    set field [split $line ,]
    set allrem [string trim [lindex [lrange $field 9 end] 0] \"]

    set rsts ""
    set rstr ""
    set rem ""
    # Either report and the remark may be absent.  The trailing remark has to
    # be optional - requiring a space after the received report meant every
    # QSO logged without a remark came back with an empty RSTr - and a report
    # is not always three characters, since SSB reports are entered as two.
    regexp {RSTS:([0-9]+)} $allrem - rsts
    regexp {RSTR:([0-9]+)\s*(.*)$} $allrem - rstr rem

    return [dict create \
        mycall [lindex $field 1] \
        ref    [lindex $field 2] \
        date   [lindex $field 3] \
        utc    [lindex $field 4] \
        freq   [lindex $field 5] \
        mode   [lindex $field 6] \
        call   [lindex $field 7] \
        s2s    [lindex $field 8] \
        rsts   $rsts \
        rstr   $rstr \
        rem    $rem]
}

# One ADIF record.  Every field declares its own length, so a report that is
# absent is left out altogether rather than written with a length it does not
# have.
proc ::sotalog::formatQsoAdif {qso} {
    set call     [dict get $qso call]
    set mode     [dict get $qso mode]
    set mycall   [dict get $qso mycall]
    set adifdate [dict get $qso adifdate]
    set band     [string toupper [string trim [dict get $qso band]]]

    set ad "<qso_date:[string length $adifdate]:d>$adifdate "
    append ad "<time_on:4>[dict get $qso utc] "
    append ad "<call:[string length $call]>$call "
    append ad "<band:[string length $band]>$band "
    append ad "<mode:[string length $mode]>$mode "

    foreach {field key} {rst_sent rsts rst_rcvd rstr} {
        set value [string trim [dict get $qso $key]]
        if {[string length $value]} { append ad "<$field:[string length $value]>$value " }
    }

    append ad "<station_callsign:[string length $mycall]>$mycall "

    # ADIF has no field for a summit reference, so the summit, the S2S and the
    # remark all go into the comment.
    set comment "SOTA [dict get $qso ref]"
    if {[string length [dict get $qso s2s]]} {
        append comment " S2S with [dict get $qso s2s]"
    }
    if {[string length [dict get $qso rem]]} {
        append comment " Remark: [dict get $qso rem]"
    }
    append ad "<comment_intl:[string length $comment]>$comment <eor>"

    return $ad
}

# Gathers what is currently in the entry fields into a QSO.
proc ::sotalog::qsoFromEntry {} {
    global band w2f myCall s2s mode ref entryMode utcDate

    set utc [clock format [clock seconds] -gmt true -format %H%M]
    set date [clock format [clock seconds] -format %d/%m/%Y]
    set adifdate [clock format [clock seconds] -format %Y%m%d]

    if {$entryMode} {
        set utc [.sotalog.utc get]
        set date $utcDate
        if {[regexp {([0-9]+)/([0-9]+)/([0-9]+)} $date - dd mm yy]} {
            set adifdate ${yy}${mm}${dd}
        }
    }

    return [dict create \
        utc      $utc \
        date     $date \
        adifdate $adifdate \
        call     [string trim [.sotalog.call get]] \
        rsts     [.sotalog.rsts get] \
        rstr     [.sotalog.rstr get] \
        rem      [.sotalog.rem get] \
        s2s      $s2s \
        band     $band \
        freq     $w2f($band) \
        mode     $mode \
        mycall   $myCall \
        ref      $ref]
}

proc ::sotalog::appendLine {path line} {
    set fh [open $path a]
    fconfigure $fh -encoding utf-8
    puts $fh $line
    close $fh
}

proc ::sotalog::readLog {} {
    # Reloads an activation already in progress.  Band is left where the last
    # logged QSO was, so a resumed session carries on where it stopped.  Mode
    # deliberately is not restored: it stays at the session default instead of
    # following whatever the final QSO happened to use.
    global logfile bandlist band cwd

    set fh [open [file join $cwd $logfile] r]
    fconfigure $fh -encoding utf-8
    while {![eof $fh]} {
        gets $fh csvline
        if {![string length $csvline]} { continue }

        set qso [parseQsoCsv $csvline]

        # Only the frequency is recorded, and the band table interleaves
        # wavelength and frequency, so the wavelength is the entry before it.
        set pos [lsearch -exact $bandlist [dict get $qso freq]]
        incr pos -1
        set band [lindex $bandlist $pos]

        insertLog [dict get $qso utc] [dict get $qso call] \
            [dict get $qso rsts] [dict get $qso rstr] [dict get $qso rem]
    }
    close $fh
}

proc ::sotalog::openLog {ref} {

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

proc ::sotalog::saveLog {} {

    global logfile adif cwd

    if {[string length [.sotalog.call get]] == 0} {
        clear
        return
    }

    set qso [qsoFromEntry]

    insertLog [dict get $qso utc] [dict get $qso call] \
        [dict get $qso rsts] [dict get $qso rstr] [dict get $qso rem]

    appendLine [file join $cwd $logfile] [formatQsoCsv $qso]
    appendLine [file join $cwd $adif] [formatQsoAdif $qso]

    clear
}
