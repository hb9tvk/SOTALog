
# Downloading refreshed summit and callsign data.
#
# The server has been observed serving a truncated sotacalls.txt (a single
# newline, regenerated nightly by a broken job).  The old code wrote whatever
# came back straight over the local copy, so one click on Update destroyed the
# callsign database.  Every download is now checked before it is allowed to
# replace anything, and the write goes through a temporary file so an
# interrupted transfer cannot leave a half-written file behind.

set updateBaseUrl http://sota.hb9tvk.org/sotalog

# Smallest payload we are willing to believe for each file, in bytes.
array set updateMinBytes {
    summits.thm   1000000
    sotacalls.txt 10000
}

# Encoding each file is written in.  Empty means the system default, which is
# what the callsign list has always used.
array set updateEncoding {
    summits.thm   iso8859-15
    sotacalls.txt {}
}

proc updateProgress {token total current} {
    # A server that sends no Content-Length reports a total of 0.
    if {$total <= 0} { return }
    .cfg.progress configure -value [expr {$current * 100 / $total}]
}

# Fetches one data file and installs it, but only once the payload looks
# plausible: the request succeeded, the status was 200, and the result is no
# smaller than both a fixed floor and half of whatever we already hold.
# Returns an error message, or the empty string on success.
proc updateDataFile {name} {
    global cwd updateBaseUrl updateMinBytes updateEncoding

    set target [file join $cwd $name]

    if {[catch {
        ::http::geturl $updateBaseUrl/$name -timeout 600000 -progress updateProgress
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

    set tmp $target.new
    if {[catch {
        set fh [open $tmp w]
        if {[string length $updateEncoding($name)]} {
            fconfigure $fh -encoding $updateEncoding($name)
        }
        puts $fh $data
        close $fh
        file rename -force $tmp $target
    } msg]} {
        catch {file delete $tmp}
        return "could not write $name: $msg"
    }

    logMsg info "updated $name ($size bytes)"
    return ""
}

proc updateCallsAndSummits {} {

    global updated

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
        tk_messageBox -icon error -type ok \
            -message "Update failed. Your existing data has been kept.\n\n[join $failed \n\n]"
    } else {
        tk_messageBox -icon info -type ok \
            -message "Summits and calls updated successfully"
    }

    foreach c $controls { $c configure -state normal }
}
