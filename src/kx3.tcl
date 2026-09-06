namespace eval ::sotalog {
    # What the radio reports for its BN; query, mapped to the wavelength the
    # log uses.  The reply is five characters, so the keys carry the
    # terminating semicolon.
    #
    # The KX3 covers 160m through 6m.  The bands above that in the band table -
    # 4m, 2m, 70cm and 23cm - are reached with a transverter and the radio does
    # not report them, so they have no entry here and can only be chosen by
    # hand.
    variable kx3bands [list \
        BN00\; 160m \
        BN01\; 80m \
        BN02\; 60m \
        BN03\; 40m \
        BN04\; 30m \
        BN05\; 20m \
        BN06\; 17m \
        BN07\; 15m \
        BN08\; 12m \
        BN09\; 10m \
        BN10\; 6m]
    variable kx32b
    array set kx32b $kx3bands
}

proc ::sotalog::kx3band {} {
    variable serial
    variable kx32b
    variable band
    variable bands

    set response [read $serial 5]
    if {![info exists kx32b($response)]} { return }

    # The radio can be on a band the operator has chosen not to display.
    # Following it would select a band with no button beside it and no counter,
    # so leave the band where it is.
    set reported $kx32b($response)
    if {[lsearch -exact $bands $reported] < 0} {
        logMsg debug "radio is on $reported, which is not among the selected bands"
        return
    }

    set band $reported
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
