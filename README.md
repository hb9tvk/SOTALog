# SOTALog

Logging software for Summits On The Air (ham radio).

See http://sota.hb9tvk.org/sotalog for details.

## Layout

The application is written in Tcl/Tk and lives in [`src/`](src/), split into
one module per concern. [`src/modules.tcl`](src/modules.tcl) lists them in load
order and is the single source of truth for that list — both the development
launcher and the build read it, so the two cannot drift apart.

| File | Contents |
| --- | --- |
| `init.tcl` | version, fonts, modal helper, loading of `names.txt` / `sotacalls.txt` |
| `log.tcl` | `logMsg` diagnostics |
| `io.tcl` | reading and writing the CSV log and the ADIF export |
| `config.tcl` | configuration file and the configuration dialog |
| `kx3.tcl` | serial band polling from an Elecraft KX3 |
| `refentry.tcl` | the opening "enter SOTA ref" dialog |
| `s2s.tcl` | summit-to-summit entry dialog |
| `update.tcl` | downloading refreshed summit and callsign data |
| `validations.tcl` | Tk entry validation and the one-key report expansion |
| `logwindow.tcl` | the main logging window |
| `main.tcl` | startup sequence |

Data files sit next to the application: `names.txt`, `sotacalls.txt`,
`summits.thm` and the optional `kx3.ini`. The logs the app writes
(`YYYY-MM-DD_REF.csv` and `.adi`) and `sotalog.conf` land in the same place.

## Running from source

Requires Tcl/Tk 8.6. On Windows this ships with Git for Windows at
`C:\Program Files\Git\mingw64\bin\tclsh.exe`, so nothing needs installing.

```
tclsh run.tcl
```

Start it with **`tclsh`, not `wish`**. `tclsh` is a console binary, so the Tk
window comes up *and* `puts` / `logMsg` output appears in the terminal; on
Windows `wish` is a GUI-subsystem binary and silently discards everything
written to stdout.

Set `SOTALOG_DEBUG=1` (informational) or `2` (everything) to raise the log
level, and `SOTALOG_HOME` to point the app at a different data directory —
useful for trying things out without touching a real log.

```
SOTALOG_DEBUG=2 SOTALOG_HOME=/tmp/sotalog-test tclsh run.tcl
```

`run.tcl` sources each module separately, so an error trace names the real file
and line rather than an offset into the concatenated build output.

### From VS Code

`.vscode/tasks.json` provides **Run SOTALog** (the default build task,
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>B</kbd>), **Run SOTALog (debug logging)**,
**Check syntax** and **Build sotalog.tcl**. All four run under `tclsh`, so log
output lands in the integrated terminal.

There is no `launch.json`: Tcl has no debug adapter for VS Code, so there are no
breakpoints. Debugging is done with `logMsg`:

```tcl
logMsg debug "band switched to $band"
```

If Tcl is installed somewhere other than the Git for Windows path, change the
four `windows.command` entries in `.vscode/tasks.json`. Write the path with
**forward slashes** - a Windows backslash in a task command gets
escape-processed on its way to the terminal, turning `\t` into a tab and `\b`
into a backspace, and the corrupted path then fails to launch.

### Tests

```
tclsh tools/test.tcl          # everything
tclsh tools/test.tcl pure     # only files matching "pure"
```

The suite lives in [`tests/`](tests/) and runs against the modules in `src/`
directly, so a failure names the module that contains the fault. Each `.test`
file runs in its own interpreter, because the ones covering the log format
build the real Tk window and that can only be done once per process. In VS
Code this is the **Run tests** task.

Most of these are *characterisation* tests: they record what the code does
today so that refactoring can be shown not to change it. Several therefore pin
behaviour that is actually wrong - those tests have `-BUG` in their name and a
comment saying what the correct behaviour would be. Fixing one means changing
its test in the same commit, deliberately, rather than discovering later that
the output silently drifted.

### Checking syntax without launching

```
tclsh tools/check.tcl
```

Sources every module except `main.tcl` and reports which ones fail to load.

## Building

`build.tcl` concatenates the modules into a single `sotalog.tcl` at the repo
root — the form the starkit wrap expects. It is generated, git-ignored, and
must never be edited by hand.

```
tclsh build.tcl        # or ./make.sh, which just calls it
```

### Windows executable

The current Windows build wraps that file into a starkit with tclkit and sdx:

```
copy /Y sotalog.tcl SOTALog.vfs\lib\SOTALog\sotalog.tcl
del SOTALog.exe
C:\Tcl\bin\tclkit-win32.upx.exe c:\Tcl\bin\sdx.kit wrap SOTALog -writable -runtime c:\Tcl\bin\tclkit.exe
ren SOTALog SOTALog.exe
```

**`SOTALog.vfs/` is not yet in this repository**, and the tclkit and sdx tools
are assumed to be at a hardcoded `C:\Tcl\bin`, so a clean checkout cannot
currently produce an executable. Making this reproducible is the next piece of
work.

### macOS application

```
./make-macosx.sh
```

Requires [platypus](https://sveinbjorn.org/platypus) and a `tclsh` on the
`PATH`. The version is read from `src/init.tcl`.

## Display sizes

The layout is built from point-sized fonts and character-counted widget widths,
so its size follows the display rather than being fixed. `fitToScreen` in
[`src/init.tcl`](src/init.tcl) sizes the window from the finished layout, and
shrinks the fonts (down to a 6pt floor) if the screen is too small for it.
Measured requirements:

| screen | window | fonts | result |
| --- | --- | --- | --- |
| 3840x2160 @ 200% | 1170x701 | natural | fits |
| 1024x600 @ 96dpi | 810x477 | natural | fits |
| 800x480 (Pi 7" touchscreen) | 750x466 | 36 -> 35pt | fits |
| 480x320 | 450x306 | 36 -> 20pt | fits |
| 320x240 (3.2" panel) | capped | at the 6pt floor | needs 330x278 - does not fit |

A 320x240 panel is the one case that still does not work: even with the fonts
at their floor the layout is about 10px too wide and 38px too tall, and the
excess is capped off with a message in the log.  Most of that height is the
log history (`-height 5`) and the suggestion pane (`-height 4`) in
[`src/logwindow.tcl`](src/logwindow.tcl); reducing those to 3 and 2 rows on a
small display would save roughly 44px and bring it under the line.  Not done,
because the Raspberry Pi this targeted is not currently in service.

## Versioning

`SOTALOG_VERSION` at the top of [`src/init.tcl`](src/init.tcl) is the single
source of truth. It feeds the window title and the macOS bundle; `package
provide` derives major.minor from it so it keeps matching the `pkgIndex.tcl`
inside the VFS.

## License

Public domain — see [LICENSE](LICENSE).
