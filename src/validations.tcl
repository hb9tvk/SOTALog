
proc getBasecall {call} {
    set numSlash [regexp -all / $call]
    if {$numSlash == 0} {
        return $call
    }
    if {$numSlash == 1} {
        regexp "^(.*)/(.*)" $call - first last
        if {[string length $first] > [string length $last]} {
            return $first
        } else {
            return $last
        }
    }
    if {$numSlash == 2} {
        regexp "^.+/(.+)/" $call - basecall
        return $basecall
    }
    return $call
}

proc processUTC {validation action new vaction newval} {
    if {$vaction == "key" && $action == 1} {
    	if {$new == " "} {
            focus .sotalog.call
            return 0
        }
	if {![regexp {[0-9]} $new]} { return 0 }
	.sotalog.utc insert insert $new
	after idle [list .sotalog.utc configure -validate $validation]

	if {[string length [.sotalog.utc get]] == 4} {
	    focus .sotalog.call
	    return 1
	}
    }
    return 1
}

proc processCall {validation action new vaction newval} {

    global names sinfo sotacalls mode

    if {$vaction == "key" && $action == 1} {
        if {$new == "."} { set new "/" }
    	if {$new == " "} {
            focus .sotalog.rsts
            return 0
        }
        
        if {![regexp {[A-Za-z0-9/]} $new]} { return 0 }
        .sotalog.call insert insert [string toupper $new]
    	after idle [list .sotalog.call configure -validate $validation]
        set basecall [getBasecall [.sotalog.call get]]
        if {[info exists names($basecall)]} {
            .sotalog.info configure -text $names($basecall) -fg blue
        } else {
            .sotalog.info configure -text "$sinfo Mode: $mode" -fg black
        }
        if {[string length [.sotalog.call get]] > 1} {
            updateSuggestions [.sotalog.call get]
        }
    }
    if {$vaction == "key" && $action ==0} {
        if {[string length $newval] > 1} {
            updateSuggestions $newval
        } else {
            .suggest.txt configure -state normal
            .suggest.txt delete 1.0 end
            .suggest.txt configure -state disabled
        }
    }
    return 1
}

proc processRSTs {validation action new vaction} {
    global oneKeyReport mode
    if {$vaction == "key" && $action == 1} {
        after idle [list .sotalog.rsts configure -validate $validation]
        if {$new == " "} {
    	    focus .sotalog.rstr
    	    return 0
    	}
    	if {![regexp {[1-9]} $new]} {
    	    return 0
    	}
        
        if {$oneKeyReport && $mode == "CW"} {
            if {$new < 5} {
                set rst ${new}${new}9
            } else {
                set rst 5${new}9
            }
            .sotalog.rsts delete 0 end
            .sotalog.rsts insert end $rst
            focus .sotalog.rstr
            return 1
        } else {
            .sotalog.rsts insert insert $new
            if {[string length [.sotalog.rsts get]] == 3} {
                focus .sotalog.rstr
            }
            return 1
        }
    }
    return 1
}

proc processRSTr {validation action new vaction} {
    global oneKeyReport mode
    if {$vaction == "key" && $action == 1} {
        after idle [list .sotalog.rstr configure -validate $validation]
        if {$new == " "} {
            focus .sotalog.rem
            return 0
        }
        if {![regexp {[1-9]} $new]} {
            return 0
        }
        if {$oneKeyReport && $mode == "CW"} {
            if {$new < 5} {
                set rst ${new}${new}9
            } else {
                set rst 5${new}9
            }
            .sotalog.rstr delete 0 end
            .sotalog.rstr insert end $rst
            focus .sotalog.rem
            return 1
        } else {
            .sotalog.rstr insert insert $new
            if {[string length [.sotalog.rstr get]] == 3} {
                focus .sotalog.rem
            }
            return 1
        }
        return 1
    }
    return 1
}

proc filterRemark {action key} {
    if {$action == 1} {
	if {[regexp {[\ -~]} $key]} { return 1}
        if {[regexp {[^[:print:]|} $key]} {
            return 0
        }
    }
    return 1
}

proc validateCall {validation action new vaction} {
    if {$vaction == "key" && $action == 1} {
        after idle [list .cfg.call configure -validate $validation]
        if {![regexp {[A-Za-z0-9/]} $new]} {
            return 0
        }
        .cfg.call insert insert [string toupper $new]
        return 1
        }
    return 1
}

