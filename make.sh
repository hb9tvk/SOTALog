#!/bin/bash

rm -f sotalog.tcl
cd src
cat init.tcl io.tcl config.tcl kx3.tcl refentry.tcl s2s.tcl config.tcl update.tcl validations.tcl logwindow.tcl main.tcl > ../sotalog.tcl
cd ..
chmod +x sotalog.tcl
