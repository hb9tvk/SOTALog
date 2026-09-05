# Build tools

Binaries needed to wrap the application into a Windows executable. They are
committed so that a clean checkout can produce a build without hunting for
them - which is exactly what went wrong between 2016 and 2026.

| file | role | version |
| --- | --- | --- |
| `tclkit-8.6.3-win32-ix86.exe` | **the runtime that ships** - prepended to `SOTALog.exe` | Tcl/Tk 8.6.3 |
| `tclkit-win32.upx.exe` | hosts `sdx.kit` during the wrap; never ships | Tcl/Tk 8.4.13 |
| `sdx.kit` | the wrapper itself | 2008 |
| `tclkit.exe` | the runtime used up to 2016, kept for reference | Tcl/Tk 8.4.13 |

`sdx` is itself a starkit, so it needs a tclkit to host it: a plain `tclsh`
cannot mount one without the `vfs` package. The host and the runtime must be
different files, because sdx refuses to use the interpreter it is running
under as the executable prefix.

## Provenance of the 8.6.3 runtime

Downloaded 2026-09-05 from the KitCreator build service, which is the
maintained source for prebuilt Tclkits:

    https://tclkits.rkeene.org/fossil/raw/tclkit-8.6.3-win32-ix86.exe?name=0f07a25977d97b51d10d55079088fe18724a905d

The `name=` parameter is the fossil artifact hash, and it is the SHA-1 of the
file, so the download verifies itself:

    SHA-1   0f07a25977d97b51d10d55079088fe18724a905d
    SHA-256 79ef99b5abbcc9d95edef4f1f9098790577fc463f60742fba4982eed1aa7a31c

32-bit was chosen deliberately: it matches what the project shipped before and
runs on any Windows, 32- or 64-bit.

## Why the runtime was upgraded

The 2016 build ran on Tcl 8.4.13, which has no `dict`, no `lassign` and no
`min()` in `expr`. The 2016 sources avoided all of them, presumably for that
reason. The 2026 refactor did not, so the packaged application would have died
in `loadConfig` on the first `dict` call. Rather than write the code back down
to a runtime that has been unsupported since around 2010, the runtime moved
forward.
