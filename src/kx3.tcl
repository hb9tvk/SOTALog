set kx3bands [list BN03\; 40m BN04\; 30m BN05\; 20m BN06\; 17m BN07\; 15m \
    BN08\; 12m BN09\; 10m BN10\; " 6m"]
array set kx32b $kx3bands

proc kx3band {} {
    global serial kx32b band

    set response [read $serial 5]
    if {[info exists kx32b($response)]} {
	set band $kx32b($response)
    }
}

proc kx3poll {} {
    global serial

    #puts "poll..."
    catch {
        if {[string length $serial]} {
            puts -nonewline $serial "BN;"
            flush $serial
        }
    }
    after 1000 kx3poll
}

proc initSerial {} {
    global serial cwd

    if {![file exists kx3.ini]} {
        return
    }
    set fh [open [file join $cwd kx3.ini] r]
    set sp [read $fh]
    close $fh

    if {[catch {
		set serial [open $sp r+]
		fconfigure $serial -mode 38400,n,8,1 -blocking 1 -translation auto -buffering none
		fileevent $serial readable kx3band
	    } msg]} {
        #puts "boing: $msg"
        set serial ""
        return
    }
    kx3poll
}
