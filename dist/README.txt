SOTALog @VERSION@
Logging software for Summits On The Air
Peter Kohler HB9TVK - http://sota.hb9tvk.org/sotalog

Installing
  Keep every file in this folder together and run SOTALog.exe.  The
  application looks for its data beside itself, so moving the executable on
  its own will leave it without the summit list.

  Nothing is installed and nothing is written outside this folder.  Your
  configuration (sotalog.conf) and your logs are created here as you use it.

First run
  You will be asked for your callsign and how you want the window set up.
  Then enter the summit reference for the activation, and the log window
  opens.

  No band is selected to begin with.  Choose one with Page Up and Page Down,
  or with the buttons on the right, before logging the first QSO - the
  application will not log without one.

Keys
  Return      log the QSO
  Escape      clear the entry fields
  comma       clear the entry fields
  Page Up     previous band
  Page Down   next band
  F8          change mode (CW, SSB, FM)
  F9 or Up    summit-to-summit entry
  F10         configuration
  Home / End  move between the entry fields

Files this folder holds
  SOTALog.exe     the application
  summits.thm     the summit database
  sotacalls.txt   callsigns, for the suggestion list
  names.txt       operator names, shown when a call is recognised
  kx3.ini.example a sample of the optional KX3 settings file.  See below.

  Use Update in the configuration dialog to refresh the three data files.

Following an Elecraft KX3
  SOTALog can read the band from a KX3 over its serial port, so that changing
  band on the radio changes it in the log.

  To switch this on, rename kx3.ini.example to kx3.ini and put your own serial
  port in it.  The file holds one line and nothing else:

    //./com13

  Use the port your radio is on - //./com4, //./com7 and so on.  Without the
  file, or with a port that is not there, SOTALog simply ignores the radio and
  you choose the band yourself.

  Only the bands the radio reports are followed, 160m to 6m, and only those you
  have chosen to show in the configuration dialog.

Logs
  Each activation writes two files here, named for the date and the summit:
    2026-09-06_HB_BE-003.csv   for uploading to the SOTA database
    2026-09-06_HB_BE-003.adi   ADIF, for the database or your own log
  The SOTA database takes either one.  New in 3.1.0: the ADIF carries the
  header and the summit references the database asks for, so it uploads as
  it stands - earlier versions wrote it for your own logging software only.

Source
  https://github.com/hb9tvk/SOTALog
