
# Downloading refreshed summit and callsign data.
#
# The server has been observed serving a truncated sotacalls.txt (a single
# newline, regenerated nightly by a broken job).  The old code wrote whatever
# came back straight over the local copy, so one click on Update destroyed the
# callsign database.  Every download is now checked before it is allowed to
# replace anything, and the write goes through a temporary file so an
# interrupted transfer cannot leave a half-written file behind.

namespace eval ::sotalog {
    set updateBaseUrl http://sota.hb9tvk.org/sotalog

    # Smallest payload we are willing to believe for each file, in bytes.
    array set updateMinBytes {
        summits.thm   1000000
        sotacalls.txt 10000
    }

    # Encoding each downloaded file is written in.
    #
    # summits.thm is ISO-8859-1 and must stay that way.  It used to be written as
    # ISO-8859-15, which differs from ISO-8859-1 in eight positions: 0xB4 is an
    # acute accent in one and a Z-caron in the other.  Tcl has no way to write an
    # acute accent in ISO-8859-15, so it substituted a question mark, and every
    # update quietly corrupted the 22 summit names that use one: "Serra do Olho
    # d?Agua", where the source data has an acute accent.  ISO-8859-1 is the only
    # encoding whose 256 values map one-to-one onto bytes, so the file now round
    # trips exactly.
    #
    # The callsign list is plain ASCII; UTF-8 matches the log files and leaves it
    # byte for byte the same.
    array set updateEncoding {
        summits.thm   iso8859-1
        sotacalls.txt utf-8
    }
}

proc ::sotalog::updateProgress {token total current} {
    # A server that sends no Content-Length reports a total of 0.
    if {$total <= 0} { return }
    .cfg.progress configure -value [expr {$current * 100 / $total}]
}

# Fetches one data file and installs it, but only once the payload looks
# plausible: the request succeeded, the status was 200, and the result is no
# smaller than both a fixed floor and half of whatever we already hold.
# Returns an error message, or the empty string on success.
proc ::sotalog::updateDataFile {name} {
    variable cwd
    variable updateBaseUrl
    variable updateMinBytes
    variable updateEncoding

    set target [file join $cwd $name]

    if {[catch {
        ::http::geturl $updateBaseUrl/$name -timeout 600000 -progress ::sotalog::updateProgress
    } token]} {
        return "download failed: $token"
    }
    set status [::http::status $token]
    set code [::http::ncode $token]
    set data [::http::data $token]
    ::http::cleanup $token

    if {$status ne "ok"} { return "transfer $status" }
    if {$code != 200} { return "server returned HTTP $code" }

    set size [string length $data]
    set floor $updateMinBytes($name)
    if {[file exists $target]} {
        set half [expr {[file size $target] / 2}]
        if {$half > $floor} { set floor $half }
    }
    if {$size < $floor} {
        return "got $size bytes, expected at least $floor - keeping the local copy"
    }
    return [writeDataFile $name $data]
}

# Installs one data file, in the encoding that file is kept in, through a
# temporary name so an interrupted write cannot leave a partial file behind.
# Returns an error message, or the empty string on success.
proc ::sotalog::writeDataFile {name data} {
    variable cwd
    variable updateEncoding

    set target [file join $cwd $name]
    set tmp $target.new

    if {[catch {
        set fh [open $tmp w]
        fconfigure $fh -encoding $updateEncoding($name) -translation lf
        puts $fh $data
        close $fh
        file rename -force $tmp $target
    } msg]} {
        catch {file delete $tmp}
        return "could not write $name: $msg"
    }

    logMsg info "updated $name ([string length $data] characters)"
    return ""
}

proc ::sotalog::updateCallsAndSummits {} {

    variable updated

    set controls {.cfg.ok .cfg.cancel .cfg.update .cfg.call .cfg.okrprt}
    foreach c $controls { $c configure -state disabled }

    ttk::progressbar .cfg.progress -mode determinate
    label .cfg.progresslabel -font sotasmall
    grid .cfg.progresslabel -row 6 -column 0
    grid .cfg.progress -row 6 -column 1 -sticky ew

    set failed {}
    foreach {name label} {
        summits.thm   "Updating summit list:"
        sotacalls.txt "Updating SOTA callsigns:"
    } {
        .cfg.progresslabel configure -text $label
        .cfg.progress configure -value 0
        update idletasks

        set err [updateDataFile $name]
        if {[string length $err]} {
            logMsg error "$name: $err"
            lappend failed "$name - $err"
        } else {
            # Only a download that actually landed should force the restart
            # prompt in configDialog.
            set updated 1
        }
    }

    grid remove .cfg.progress .cfg.progresslabel
    destroy .cfg.progress .cfg.progresslabel

    if {[llength $failed]} {
        showMessage error "Update failed" \
            "Update failed. Your existing data has been kept.\n\n[join $failed \n\n]"
    } else {
        showMessage info "Update complete" \
            "Summits and calls updated successfully"
    }

    foreach c $controls { $c configure -state normal }
}
