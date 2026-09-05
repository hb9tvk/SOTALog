#!/bin/bash
#
# Kept for muscle memory: the build itself lives in build.tcl so that it also
# runs on Windows without a shell.
set -e
exec tclsh "$(dirname "$0")/build.tcl"
