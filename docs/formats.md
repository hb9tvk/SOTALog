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
| 6 | mode | `CW` | `CW`, `SSB` or `FM` |
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

Written by `formatQsoAdif` and `formatAdifHeader` in
[`src/io.tcl`](../src/io.tcl), appended alongside the CSV, never read back.
UTF-8.

Either this or the CSV can be uploaded to the SOTA database; the ADIF is also
what you would import into your own logging software. It was not always
uploadable — until 3.1.0 it had no header and kept the summit references in a
free-text comment, which the database rejects.

The file opens with a header, written once when the file is created:

    ADIF export from SOTALog: HB9TVK/P at HB/OW-020 on 2026-08-19
    <ADIF_VER:5>3.1.5
    <PROGRAMID:7>SOTALog
    <PROGRAMVERSION:5>3.1.0
    <EOH>

Then one record per line:

    <CALL:8>HB9DQM/P <MODE:2>CW <BAND:3>40m <QSO_DATE:8>20260819
    <TIME_ON:6>104500 <RST_RCVD:3>559 <RST_SENT:3>599
    <STATION_CALLSIGN:8>HB9TVK/P <OPERATOR:8>HB9TVK/P
    <MY_SOTA_REF:9>HB/OW-020 <SOTA_REF:9>HB/VS-266 <EOR>

(wrapped here for readability; each record is one line).

**`MY_SOTA_REF` is the summit being activated and `SOTA_REF` the one worked in
a summit-to-summit.** Those two are what make the file uploadable. `SOTA_REF`
is written only when there was an S2S.

Every field declares its own length, and each is computed rather than assumed.
A field with no value is left out entirely — writing `<RST_SENT:3>` with
nothing after it contradicts itself and throws off every field that follows.

The time carries seconds as `00`. SOTALog records the minute, and ADIF permits
a bare `HHMM`, but every SOTA log seen in the wild uses `HHMMSS`. A partly
typed time — fewer than four digits — is written as it stands rather than
padded into a different time.

Some fields other loggers write are deliberately absent, because SOTALog does
not have the data and will not invent it: `FREQ` (it knows the band, not the
frequency within it), and `GRIDSQUARE`, `MY_GRIDSQUARE`, `DXCC`, `CQZ` and
`ITUZ` (it knows nothing about the other station's location). The operator's
own remark goes in `COMMENT`.

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

Read by `loadNames` in [`src/init.tcl`](../src/init.tcl), downloaded by
`updateDataFile` in [`src/update.tcl`](../src/update.tcl). UTF-8, ASCII in
practice. One line per operator: the callsign, then the name, which may be
several words.

Three shapes of this file are in circulation and all of them load:

    2E0ATS Jim                                  bundled with the application
    # Call Name (created at ...)                the maintained one at qsl.net
    2D0EDQ Dawn
    Call,Name (created at ...)                  the sota.hb9tvk.org mirror
    2D0EDQ,Dawn

The call is taken up to the first comma or space, so the separator does not
matter, and the rest of the line is the name. Two kinds of line are skipped:
blanks and anything starting with `#`, and anything whose callsign contains no
digit — every real callsign has one, which is what tells a heading from an
entry. That also drops the handful of bad rows upstream carries, such as
`EMAIL,Alessandro` and calls written with a letter O where a zero belongs;
none of them could ever match a call the operator types. A callsign with no
name at all is skipped too, since there is nothing to display.

The maintained file holds about 74,000 names against the 545 bundled here.
When a call being typed matches, the name replaces the summit information above
the entry fields, in blue.

## The configuration — `sotalog.conf`

Written by `saveConfig`, read by `parseConfig` in
[`src/config.tcl`](../src/config.tcl). Written next to the application through
a temporary file and renamed, so an interrupted write cannot leave a
configuration that will not load.

    set myCall HB9TVK/P
    set oneKeyReport 1
    set entryMode 0
    set utcDate 05/09/2026
    set bands 60m 40m 30m 20m 17m 15m 12m 10m
    set uiScale 100

It looks like Tcl because it used to be `eval`ed, which meant a space or a
bracket in a value could stop the application starting or be executed. It is
now **parsed**: `set <name> <value>` lines and nothing else, values taken
verbatim to the end of the line, unknown names logged and skipped. The format
is unchanged, so existing files still load.

`uiScale` is how large the log window is drawn, as a percentage of the size the
application has always used, set with the slider in the configuration dialog.
Everything the application draws is laid out from point-sized fonts, so one
number scales the lot, the reference dialog included: main.tcl reads the
configuration and scales the fonts before building anything. It ranges from 100 to 300 and only goes upwards: `fitToScreen`
already shrinks the layout when it will not fit the display, and this is for an
operator who needs it larger. A size outside that range, or one that is not a
number, is pulled back. Changing it needs a restart.

The request is not a promise. `fitToScreen` still caps the result at the size
of the screen, so asking for 300% on a small display gives whatever actually
fits.

`bands` lists the wavelengths shown in the log window, chosen from the master
table in `src/init.tcl` through the checkboxes in the configuration dialog.
Names the application does not know are dropped with a warning, and a
selection that ends up empty falls back to the eight bands offered before they
became selectable. Changing it needs a restart, because the band panel is
built once when the window opens.

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
| `BN00;` | 160m | `BN06;` | 17m |
| `BN01;` | 80m | `BN07;` | 15m |
| `BN02;` | 60m | `BN08;` | 12m |
| `BN03;` | 40m | `BN09;` | 10m |
| `BN04;` | 30m | `BN10;` | 6m |
| `BN05;` | 20m | | |

The KX3 covers 160m through 6m. The bands above that in the master table — 4m,
2m, 70cm and 23cm — are reached with a transverter and the radio does not
report them, so they have no entry and are chosen by hand.

`kx3band` ignores a reply twice over: one it does not recognise at all, and one
naming a band the operator has not chosen to display — following that would
select a band with no button beside it and no counter. Either way the band
stays where it was put. `tests/bands.test` covers both, and checks that every
command names a band the master table knows.
