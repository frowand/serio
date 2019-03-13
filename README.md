# serio
upload/download files to an embedded Linux system via a serial port shell

The goal is to provide some of the same functionality as 'scp' and 'ssh'
over a serial link instead of a network link, with a minimal dependency
of programs on the remote system.  Full feature replication of 'scp' and
'ssh' is _not_ a goal.  See Documentation/design_goals for more details.

For more information, see:
  ./serio --help
  ./sercp --help
  ./sersh --help


Most of the modules imported by serio are likely to be present.
You may need to install pySerial for the 'import serial'.  See
https://pythonhosted.org/pyserial/pyserial.html#installation
if further details are needed or for install from source.

   Debian / Ubuntu: sudo apt-get install python-serial

   other: pip install pyserial


contact info: frowand.list@gmail.com

If you submit an issue or pull request, please send an email to frowand.list@gmail.com

Start the email's subject line with: [github serio]
