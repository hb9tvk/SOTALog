namespace eval ::sotalog {
    # The band the radio reports, from its BN; query, mapped to the wavelength
    # the log uses.  The reply is five characters, so the keys include the
    # terminating semicolon.
    #
    # BN10, which the radio sends for 6m, is deliberately absent: 6m is not in
    # the band list, and adding it would mean a ninth row in the band panel
    # and a taller window.  kx3band ignores a reply it does not recognise, so
    # switching the radio to 6m simply leaves the band where it was.
    variable kx3bands [list \
        BN02\; 60m \
        BN03\; 40m \
        BN04\; 30m \
        BN05\; 20m \
        BN06\; 17m \
        BN07\; 15m \
        BN08\; 12m \
        BN09\; 10m]
    variable kx32b
    array set kx32b $kx3bands
}

proc ::sotalog::kx3band {} {
    variable serial
    variable kx32b
    variable band

    set response [read $serial 5]
    if {[info exists kx32b($response)]} {
	set band $kx32b($response)
    }
}

proc ::sotalog::kx3poll {} {
    variable serial

    #puts "poll..."
    catch {
        if {[string length $serial]} {
            puts -nonewline $serial "BN;"
            flush $serial
        }
    }
    after 1000 ::sotalog::kx3poll
}

proc ::sotalog::initSerial {} {
    variable serial
    variable cwd

    if {![file exists [file join $cwd kx3.ini]]} {
        return
    }
    set fh [open [file join $cwd kx3.ini] r]
    set sp [read $fh]
    close $fh

    if {[catch {
		set serial [open $sp r+]
		fconfigure $serial -mode 38400,n,8,1 -blocking 1 -translation auto -buffering none
		fileevent $serial readable ::sotalog::kx3band
	    } msg]} {
        #puts "boing: $msg"
        set serial ""
        return
    }
    kx3poll
}
