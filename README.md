# SOTALog

Logging software for Summits On The Air (ham radio).

See http://sota.hb9tvk.org/sotalog for details.

## Documentation

- [CLAUDE.md](CLAUDE.md) - orientation for working on the code: the commands,
  the traps, and what has been left alone on purpose.
- [docs/formats.md](docs/formats.md) - every file the application reads or
  writes, field by field.

## Layout

Everything the application defines - all 54 procedures and every variable -
lives in the `::sotalog` namespace, so nothing of ours sits in the global one
beside Tcl's and Tk's own commands. Modules call each other by bare name;
only Tk callbacks name things in full, because bindings, `-validatecommand`,
`-command`, `fileevent`, `after`, `-progress`, `-variable` and `-listvariable`
are all evaluated at the global level. `tests/callbacks.test` checks that none
of them is left unqualified - the running tests cannot, because the test
harness imports the namespace and an unqualified callback then resolves
perfectly well under test while failing in the application.

The application is written in Tcl/Tk and lives in [`src/`](src/), split into
one module per concern. [`src/modules.tcl`](src/modules.tcl) lists them in load
order and is the single source of truth for that list — both the development
launcher and the build read it, so the two cannot drift apart.

| File | Contents |
| --- | --- |
| `init.tcl` | version, fonts, modal helper, loading of `names.txt` / `sotacalls.txt` |
| `log.tcl` | `logMsg` diagnostics |
| `io.tcl` | the QSO record, the CSV and ADIF formats, and the log files |
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

```
tclsh wrap.tcl
```

One command, no hardcoded paths: it builds `sotalog.tcl`, copies it into
`SOTALog.vfs/lib/SOTALog/`, and wraps the tree into a starpack with sdx. In VS
Code this is the **Build SOTALog.exe** task. Everything it needs is committed —
the VFS and the tools in [`tools/tclkit/`](tools/tclkit/), whose README says
what each binary is for and where the runtime came from.

The VFS holds the starkit bootstrap, the package index, and a vestigial
`http1.0` that the runtime shadows with its own newer `http`. `wrap.tcl` also
copies `sotalog.ico` into it as `tclkit.ico`, which is the name sdx looks for
when replacing the executable's icons. The data files are not inside it: `main.tcl` resolves them
relative to the executable, so `names.txt`, `sotacalls.txt`, `summits.thm` and
the optional `kx3.ini` sit beside `SOTALog.exe`.

The shipped runtime is Tcl/Tk **8.6.3**. It was 8.4.13 until 2026 — see
[`tools/tclkit/README.md`](tools/tclkit/README.md) for why it moved, and note
that the 8.4 kit is still needed at build time to host sdx.

#### The icon

sdx replaces the runtime's icon resources with the images from `tclkit.ico`,
matching each to a resource of the same byte size, and refuses any that do not
match - it prints `NOT SAME SIZE` for those. That is normal and not all nine
ever match. What matters is the three 32-bit images: those are the ones Windows
Vista and later display, and if they are missing the executable wears the
tclkit feather. `wrap.tcl` checks for them after wrapping and warns if none
arrived.

This is why the icon broke when the runtime moved to 8.6.3. The old
`tclkit.ico` held only 4-bit and 8-bit images, which was enough for the 8.4
runtime; the 8.6.3 one carries 32-bit resources as well, and those kept the
feather. `sotalog.ico` has all nine, so it is used directly.

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

## Character encodings

Each data file is read and written in a named encoding rather than inheriting
whatever the system encoding happens to be - which is cp1252 on Windows, UTF-8
on Linux and macOS, and UTF-8 under Tcl 9.

| file | encoding | why |
| --- | --- | --- |
| `summits.thm` | ISO-8859-1 | what the server sends. Its 256 values map one-to-one onto bytes, so the file round trips exactly |
| `sotacalls.txt`, `names.txt` | UTF-8 | ASCII today, so this costs nothing and matches the log files |
| `.csv`, `.adi` logs | UTF-8 | remarks may contain anything the operator types |

This was worth being careful about: `summits.thm` used to be written as
ISO-8859-15, which differs from ISO-8859-1 in eight byte positions. 0xB4 is an
acute accent in one and a Z-caron in the other, and ISO-8859-15 has no acute
accent at all, so Tcl substituted a question mark - quietly corrupting the 22
Brazilian, Portuguese and Spanish summit names that use one on every update.
It was then read back in the system encoding, so on any non-Windows machine
every accented name became replacement characters.

## Versioning

`SOTALOG_VERSION` at the top of [`src/init.tcl`](src/init.tcl) is the single
source of truth. It feeds the window title and the macOS bundle; `package
provide` derives major.minor from it so it keeps matching the `pkgIndex.tcl`
inside the VFS.

## License

Public domain — see [LICENSE](LICENSE).
