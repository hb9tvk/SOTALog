#!/usr/bin/env tclsh
#
# Builds the Windows executable: concatenates the sources, copies the result
# and the icon into the VFS, and wraps it into a starpack with sdx.
#
#   tclsh wrap.tcl
#
# sdx is itself a starkit, so it needs a tclkit to host it - a plain tclsh
# cannot mount one without the vfs package.  The kit that hosts sdx and the
# runtime that gets prepended to the executable must be different files, since
# sdx refuses to use the interpreter it is running under as the prefix.
#
# The runtime is what ships.  It was Tcl 8.4.13 until 2026, which is why the
# 2016 sources avoided dict, lassign and min(); the current runtime is 8.6.3.

set root [file dirname [file normalize [info script]]]
set kitdir [file join $root tools tclkit]

set sdxHost [file join $kitdir tclkit-win32.upx.exe]
set sdx     [file join $kitdir sdx.kit]
set runtime [file join $kitdir tclkit-8.6.3-win32-ix86.exe]
set vfs     [file join $root SOTALog.vfs]
set icon    [file join $root sotalog.ico]
set exe     [file join $root SOTALog.exe]

foreach {what path} [list "sdx host" $sdxHost "sdx" $sdx "runtime" $runtime \
                          "VFS" $vfs "icon" $icon] {
    if {![file exists $path]} {
        puts stderr "wrap.tcl: missing $what: $path"
        exit 1
    }
}

# Reports which images of an .ico file are present verbatim in a file, so that
# the build can say whether the icon actually reached the executable.
proc iconImagesIn {icoPath filePath} {
    set fh [open $icoPath rb]; set ico [read $fh]; close $fh
    set fh [open $filePath rb]; set target [read $fh]; close $fh

    binary scan $ico sss reserved type count
    set present {}
    set missing {}
    for {set i 0} {$i < $count} {incr i} {
        set entry [string range $ico [expr {6 + $i * 16}] [expr {6 + $i * 16 + 15}]]
        binary scan $entry ccccssii w h colours res planes bits size offset
        set w [expr {($w & 0xff) == 0 ? 256 : ($w & 0xff)}]
        set label "${w}x${w}/[expr {$bits & 0xffff}]-bit"
        set image [string range $ico $offset [expr {$offset + $size - 1}]]
        if {[string first $image $target] >= 0} {
            lappend present $label
        } else {
            lappend missing $label
        }
    }
    return [list $present $missing]
}

# 1. Build the single file the VFS expects.
puts "building sotalog.tcl..."
if {[catch {exec [info nameofexecutable] [file join $root build.tcl]} out]} {
    puts stderr "wrap.tcl: build failed: $out"
    exit 1
}
puts "  $out"

# 2. Copy in the parts of the VFS that are generated rather than kept.
file copy -force [file join $root sotalog.tcl] \
    [file join $vfs lib SOTALog sotalog.tcl]

# sdx replaces the runtime's icons from a file called tclkit.ico, matching
# each image to a resource of the same byte size.  sotalog.ico is the only
# icon kept in the repository; this is where it gets that name.
file copy -force $icon [file join $vfs tclkit.ico]

# 3. Wrap.  sdx writes a file named after the target with no extension.
file delete -force [file join $root SOTALog] $exe
puts "wrapping with [file tail $runtime]..."
cd $root
if {[catch {exec $sdxHost $sdx wrap SOTALog -writable -runtime $runtime << ""} out]} {
    # sdx reports its progress on stderr, so a non-zero result is not always a
    # failure; the check below is what actually decides.
    puts $out
}
if {![file exists [file join $root SOTALog]]} {
    puts stderr "wrap.tcl: sdx produced no output"
    exit 1
}
file rename -force [file join $root SOTALog] $exe

# 4. Say whether the icon took.  sdx can only overwrite a resource with an
# image of exactly the same byte size, so some are always refused - it prints
# "NOT SAME SIZE" for those.  What matters is the 32-bit images, which are the
# ones Windows shows; if those are missing the executable wears the tclkit
# feather.
lassign [iconImagesIn $icon $exe] present missing
set trueColour {}
foreach image $present { if {[string match *32-bit $image]} { lappend trueColour $image } }
if {[llength $trueColour]} {
    puts "icon: [llength $present] of [expr {[llength $present] + [llength $missing]}] images embedded, including [join $trueColour {, }]"
} else {
    puts stderr "wrap.tcl: WARNING - no 32-bit icon image reached the executable,"
    puts stderr "  so it will show the runtime's own icon.  Missing: [join $missing {, }]"
}

puts "built $exe ([file size $exe] bytes)"
