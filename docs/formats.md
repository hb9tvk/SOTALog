# File formats

Every file SOTALog reads or writes, and the parts of the code that own each
one. Encodings are given because they are named explicitly in the code rather
than inherited from the system — see [the README](../README.md#character-encodings)
for why that matters.

## The activation log — `YYYY-MM-DD_ASSOC_REGION-NNN.csv`

Written by `formatQsoCsv`, read by `parseQsoCsv`, both in
[`src/io.tcl`](../src/io.tcl). UTF-8. One line per QSO, appended as it is
logged. The reference in the file name has its `/` replaced by `_`, so
`HB/BE-003` gives `2026-09-05_HB_BE-003.csv`.

Ten comma-separated fields:

| # | field | example | notes |
| --- | --- | --- | --- |
| 0 | format marker | `V2` | constant |
| 1 | operator's call | `HB9TVK/P` | from the configuration |
| 2 | summit activated | `HB/BE-003` | |
| 3 | date | `05/09/2026` | `dd/mm/yyyy`, **local** date |
| 4 | time | `1205` | `HHMM`, **UTC** |
| 5 | frequency | `7.0MHz` | the band edge, not the actual frequency |
| 6 | mode | `CW` | `CW` or `SSB` |
| 7 | station worked | `DL1ABC` | |
| 8 | summit-to-summit | `HB/VS-001` | empty when not an S2S |
| 9 | remark | `"RSTS:599 RSTR:579 windy"` | double-quoted, see below |

The remark field packs several things into one column, in this order, each
part present only when it has a value:

    RSTS:<sent> RSTR:<received> S2S:<reference> <what the operator typed>

**The date is local while the time is UTC.** Between midnight UTC and midnight
local they disagree, so a QSO logged late in the evening in central Europe
carries tomorrow's UTC time against today's date. Long-standing; changing it
would make old logs inconsistent with new ones.

**There is no CSV escaping.** A comma in the remark would truncate it when the
log is read back — `parseQsoCsv` splits on commas and takes field 9. In
practice one cannot get there, because a comma keystroke is bound to clearing
the entry fields (`comma-clears-the-form` in `tests/bindings.test` pins this),
but a hand-edited file can still break it.

Reading a log back is lossy in one more way: the S2S reference is written into
both column 8 and the remark, and only the reports are stripped on the way in,
so a reloaded QSO shows `S2S:HB/VS-001` at the front of its remark. Every log
already written looks like that.

## The ADIF export — `YYYY-MM-DD_ASSOC_REGION-NNN.adi`

Written by `formatQsoAdif` in [`src/io.tcl`](../src/io.tcl), appended
alongside the CSV, never read back. UTF-8. One record per line - wrapped over
three lines here for readability, but written as one:

    <qso_date:8:d>20260905 <time_on:4>1205 <call:6>DL1ABC <band:3>40M
    <mode:2>CW <rst_sent:3>599 <rst_rcvd:3>579 <station_callsign:8>HB9TVK/P
    <comment_intl:33>SOTA HB/BE-003 S2S with HB/VS-001 <eor>

Every ADIF field declares its own length, and each one here is computed rather
than assumed. `rst_sent` and `rst_rcvd` are **omitted entirely** when there is
no report, which is how ADIF represents an absent value — writing
`<rst_sent:3>` with nothing after it corrupts every field that follows.

ADIF has no field for a summit reference, so the summit, the S2S and the
operator's remark are all folded into `comment_intl`:

    SOTA <ref>[ S2S with <ref>][ Remark: <text>]

## The summit database — `summits.thm`

Read by `loadSummits` in [`src/refentry.tcl`](../src/refentry.tcl), written by
`writeDataFile` in [`src/update.tcl`](../src/update.tcl). **ISO-8859-1**, about
13 MB, downloaded from `http://sota.hb9tvk.org/sotalog/summits.thm`.

Four lines, each a Tcl array dump — a flat list of alternating key and value,
loaded with `array set`. They are read in this order:

| line | array | keys | example |
| --- | --- | --- | --- |
| 1 | `summits` | `<ref>,name`, `<ref>,alt`, `<ref>,pts` | `HB/BE-003,name Eiger` |
| 2 | `refs` | every summit reference | `HB/BE-003 1` |
| 3 | `assocs` | every association | `HB 1` |
| 4 | `regions` | every association/region | `HB/BE 1` |

The last three are sets: the value is always `1` and only the key matters.
They drive the summit-to-summit dialog, which narrows a suggestion list as the
operator types. Line 1 is a single line of about 11 MB.

The encoding is not negotiable. ISO-8859-1 is the only encoding whose 256
values map one-to-one onto bytes, so the file round-trips exactly; the names
carry accented characters, and 22 of them use an acute accent as an
apostrophe, which is the byte an earlier ISO-8859-15 write turned into `?`.

## The callsign list — `sotacalls.txt`

Read by `loadSotaCalls` in [`src/init.tcl`](../src/init.tcl). UTF-8, ASCII in
practice. Whitespace-separated callsigns, read as one list and searched with a
glob to suggest completions as a call is typed.

Downloaded from `http://sota.hb9tvk.org/sotalog/sotacalls.txt`, **which is
currently serving a single newline** — the generator on that server is broken.
`updateDataFile` refuses anything implausibly small, so the local copy
survives, but the feed needs fixing at the source. See
[`../README.md`](../README.md) and the SOTA API notes in the project history.

## The operator names — `names.txt`

Read by `loadNames` in [`src/init.tcl`](../src/init.tcl). UTF-8, ASCII in
practice. One line per operator: the callsign, then the name, which may be
several words.

    2E0ATS Jim
    G4XYZ John Smith

Hand-maintained; there is no feed for it. When a call being typed matches, the
name replaces the summit information above the entry fields, in blue.

## The configuration — `sotalog.conf`

Written by `saveConfig`, read by `parseConfig` in
[`src/config.tcl`](../src/config.tcl). Written next to the application through
a temporary file and renamed, so an interrupted write cannot leave a
configuration that will not load.

    set myCall HB9TVK/P
    set oneKeyReport 1
    set entryMode 0
    set utcDate 05/09/2026

It looks like Tcl because it used to be `eval`ed, which meant a space or a
bracket in a value could stop the application starting or be executed. It is
now **parsed**: `set <name> <value>` lines and nothing else, values taken
verbatim to the end of the line, unknown names logged and skipped. The format
is unchanged, so existing files still load.

`oneKeyReport` turns the single-digit RST expansion on. `entryMode` turns on
UTC entry, where the operator types the time and the date comes from
`utcDate` rather than the clock.

## The radio link — `kx3.ini`

Read by `initSerial` in [`src/kx3.tcl`](../src/kx3.tcl). A single line naming
the serial port, in the form Tcl's `open` wants:

    //./com13

Optional: without the file, the band is chosen by hand. With it, SOTALog opens
the port at 38400,n,8,1 and polls the radio once a second with the Elecraft
`BN;` command, mapping the reply to a band:

| reply | band | reply | band |
| --- | --- | --- | --- |
| `BN03;` | 40m | `BN07;` | 15m |
| `BN04;` | 30m | `BN08;` | 12m |
| `BN05;` | 20m | `BN09;` | 10m |
| `BN06;` | 17m | `BN10;` | 6m |

**`BN10;` is a trap.** It maps to `" 6m"` — with a leading space — and 6m is
not in the band list, which has 60m instead. Commit 4930184, "replaced 6m by
60m", changed the band list and left this map alone. If the radio is switched
to 6m the band becomes a value nothing else knows, and logging the next QSO
fails with `invalid command name ".bandmap.l 6m"`. Reachable only with a KX3
attached and 6m selected, which is presumably why it has gone unnoticed.

Conversely 60m, which *is* in the band list, has no KX3 mapping, so it can
only be selected by hand.
