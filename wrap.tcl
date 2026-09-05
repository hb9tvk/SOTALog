#!/usr/bin/env tclsh
#
# Builds the Windows executable: concatenates the sources, copies the result
# into the VFS, and wraps it into a starpack with sdx.
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
set exe     [file join $root SOTALog.exe]

foreach {what path} [list "sdx host" $sdxHost "sdx" $sdx "runtime" $runtime "VFS" $vfs] {
    if {![file exists $path]} {
        puts stderr "wrap.tcl: missing $what: $path"
        exit 1
    }
}

# 1. Build the single file the VFS expects.
puts "building sotalog.tcl..."
if {[catch {exec [info nameofexecutable] [file join $root build.tcl]} out]} {
    puts stderr "wrap.tcl: build failed: $out"
    exit 1
}
puts "  $out"

# 2. Copy it in.  This is the only part of the VFS that is generated.
file copy -force [file join $root sotalog.tcl] \
    [file join $vfs lib SOTALog sotalog.tcl]

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

puts "built $exe ([file size $exe] bytes)"
