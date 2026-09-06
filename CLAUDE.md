# Working on SOTALog

A Tcl/Tk logging application for Summits On The Air, written in 2015-2016 and
resurrected in 2026 after nine years untouched. Small — about 1,300 lines of
application code — but it is field software: it runs on a summit, in the cold,
often on battery, and a crash there costs an activation. Prefer degrading to
failing.

## Getting oriented

- [README.md](README.md) — how to run, test, build, and why the encodings and
  the runtime version are what they are.
- [docs/formats.md](docs/formats.md) — every file the application reads or
  writes, field by field, including the parts that are lossy.
- `git log` — the commit messages carry the reasoning. Several explain why
  something is *not* being changed.

## Commands

```
tclsh run.tcl              # run it (tclsh, never wish - see below)
tclsh tools/test.tcl       # the whole suite; add a name to filter
tclsh tools/check.tcl      # parse every module without starting the GUI
tclsh build.tcl            # concatenate src/ into sotalog.tcl
tclsh wrap.tcl             # build SOTALog.exe
```

All five are VS Code tasks. `tclsh` on Windows is at
`C:/Program Files/Git/mingw64/bin/tclsh.exe`, shipped with Git for Windows.

**Run it with `tclsh`, not `wish`.** `tclsh` is a console binary, so the Tk
window appears *and* `puts` and `logMsg` output reaches the terminal; on
Windows `wish` silently discards everything written to stdout. `SOTALOG_DEBUG=1`
or `2` raises the log level, `SOTALOG_HOME` points the app at a different data
directory — useful for trying things without touching a real log.

## Things that will bite

**Namespaces.** Everything lives in `::sotalog`. Modules call each other by
bare name, but Tk callbacks are evaluated at the *global* level — bindings,
`-validatecommand`, `-command`, `fileevent`, `after`, `-progress`, `-variable`,
`-listvariable` — so those must be written out in full. `tests/callbacks.test`
checks this statically, because the running tests cannot: the harness imports
`::sotalog::*`, which makes an unqualified callback resolve perfectly well
under test while failing in the application.

**`variable a b c` is not `global a b c`.** `variable` takes name/value pairs,
so that line declares `a` with the value `b`. One name per `variable`.

**`upvar #0 $name` reaches the global namespace**, not `::sotalog`. Qualify it.

**Use `showMessage`, not `tk_messageBox`.** On Windows Tk maps `tk_messageBox`
to the native system box: it centres on the screen rather than on the
application, ignores the fonts, and `winfo` cannot see it, so the tests can
only stub it out. `showMessage` is a Tk window, centred on the main window by
`centreOnMain`, and the tests can drive and measure it.

**A backslash continuation inside a quoted Tcl string collapses to a space.**
That put spaces into the middle of every CSV record once. Build records with
`join`, not interpolation.

**The packaged runtime is Tcl/Tk 8.6.3**, not the 8.6.16 you get from
`tclsh`. It was 8.4.13 until 2026, which is why the original sources avoided
`dict`, `lassign` and `min()`. If the wrap ever changes runtime again, check
the language level before using anything newer.

**`package provide SOTALog` must match `pkgIndex.tcl`**, major.minor only.
`SOTALog.vfs/lib/SOTALog/pkgIndex.tcl` says `package ifneeded SOTALog 3.0`, so
bumping the minor version means changing that file in the same commit or the
starkit will not load.
The full version lives in `SOTALOG_VERSION` in `src/init.tcl`, which
`make-macosx.sh` also reads.

**Encodings are named explicitly, never inherited.** `summits.thm` is
ISO-8859-1 and must stay so; the logs and the other data files are UTF-8.
Getting this wrong corrupted 22 summit names on every update for years.
Source files are pure ASCII — a stray high byte in a `.tcl` file recreates the
same class of problem.

## How to change things here

There is a test suite because there was not one, and the code had accumulated
bugs nobody could see. Keep it that way:

1. **Pin the current behaviour first.** Most tests are characterisation tests:
   they record what the code does today so a refactor can be shown not to
   change it. Where today's behaviour is wrong, the test says so in its name
   and comment rather than quietly blessing it.
2. **Break a new test deliberately before trusting it.** Two checks written
   during this work passed for the wrong reason — one because a regular
   expression was mis-escaped and matched nothing, one because the harness
   made the thing it was testing unreachable. A test that cannot fail is worse
   than no test.
3. **Fix bugs as their own commits**, with the pinning test updated in the same
   change, so the diff shows the behaviour moving.
4. **Verify the packaged executable**, not just the sources, for anything
   touching startup, paths, callbacks or the runtime. It can be driven from
   PowerShell with `WScript.Shell` `SendKeys`; `SOTALOG_HOME` keeps it out of
   the real data directory.

Ad-hoc probe scripts must end with `exit 0` — with Tk loaded, `tclsh` waits on
stdin and hangs otherwise.

## Known and deliberately unfixed

Recorded in [docs/formats.md](docs/formats.md), and worth knowing before
"fixing" something that was left alone on purpose:

- The CSV date is **local** while the time is **UTC**.
- The CSV has no escaping; a comma keystroke clears the entry fields, which is
  what keeps commas out of it.
- Reloading a log leaves `S2S:` at the front of the remark.
- `sotacalls.txt` upstream is serving an empty file; the download guard keeps
  the local copy.
- SOTA's API terms forbid AI-generated software connecting to their API
  without prior approval, and require joining the API-consumers group on their
  reflector. Do not write code against that API here.
