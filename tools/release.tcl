#!/usr/bin/env tclsh
#
# Assembles the Windows release bundle: tclsh tools/release.tcl
#
# The bundle is what an operator unpacks on the summit laptop, so it is flat -
# no directories to get separated - and holds the data files as well as the
# executable, because main.tcl resolves those relative to SOTALog.exe and the
# application is useless without the summit list.
#
# It does not build SOTALog.exe; run wrap.tcl first.  It does not fetch fresh
# data either: whatever summits.thm, sotacalls.txt and names.txt are in the
# working directory go in, so refresh them with Update before releasing.

set root [file dirname [file dirname [file normalize [info script]]]]

# The one place the version is written down.
set init [file join $root src init.tcl]
set fh [open $init r]
set source [read $fh]
close $fh
if {![regexp {variable SOTALOG_VERSION ([0-9.]+)} $source -> version]} {
    puts stderr "release.tcl: no SOTALOG_VERSION in $init"
    exit 1
}

set exe [file join $root SOTALog.exe]
if {![file exists $exe]} {
    puts stderr "release.tcl: no SOTALog.exe - run wrap.tcl first"
    exit 1
}

# name in the bundle -> file it comes from
set contents [list \
    SOTALog.exe     $exe \
    summits.thm     [file join $root summits.thm] \
    sotacalls.txt   [file join $root sotacalls.txt] \
    names.txt       [file join $root names.txt] \
    kx3.ini.example [file join $root kx3.ini.example] \
    LICENSE         [file join $root LICENSE]]

set staging [file join $root .release]
file delete -force $staging
file mkdir $staging

foreach {name origin} $contents {
    if {![file exists $origin]} {
        puts stderr "release.tcl: missing $origin"
        exit 1
    }
    file copy $origin [file join $staging $name]
    puts "  [format %-16s $name] [file size $origin] bytes"
}

# README.txt names its version, so it is the one file that is generated
# rather than copied.
set fh [open [file join $root dist README.txt] r]
fconfigure $fh -encoding utf-8
set readme [read $fh]
close $fh
set fh [open [file join $staging README.txt] w]
fconfigure $fh -encoding utf-8 -translation crlf
puts -nonewline $fh [string map [list @VERSION@ $version] $readme]
close $fh
puts "  [format %-16s README.txt] generated for $version"

set zip [file join $root "SOTALog-$version-win32.zip"]
file delete -force $zip

# Tcl 8.6 has no zip writer, so this is .NET's, through PowerShell.
# CreateFromDirectory names its entries relative to the directory it is given,
# which is what keeps the bundle flat.  Compress-Archive -Path dir\* does not:
# written that way it put a .release\ in front of every name in the archive.
set ps "Add-Type -AssemblyName System.IO.Compression.FileSystem;\
    \[System.IO.Compression.ZipFile\]::CreateFromDirectory(\
    '[file nativename $staging]', '[file nativename $zip]')"
if {[catch {exec powershell -NoProfile -Command $ps} err]} {
    puts stderr "release.tcl: zip failed: $err"
    exit 1
}
file delete -force $staging

puts "built [file tail $zip] ([file size $zip] bytes)"
