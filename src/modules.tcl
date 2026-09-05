# Load order of the application sources.
#
# Shared by run.tcl (which sources each file individually for development) and
# build.tcl (which concatenates them into the single file the starkit wraps),
# so the two can never drift apart.  init.tcl must come first because it holds
# the package declaration, and main.tcl last because it starts the app.

set sotalogModules {
    init.tcl
    log.tcl
    io.tcl
    config.tcl
    kx3.tcl
    refentry.tcl
    s2s.tcl
    update.tcl
    validations.tcl
    logwindow.tcl
    main.tcl
}
