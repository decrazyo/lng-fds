This is the (new) development tree of LNG (LUnix next generation)
I decided to rewrite it from scratch, because i don't want to use those
old LUnix/LUnix0.8 stuff i've written years ago any more.
I'll try to make better, cleaner code.

The most important changes from LUnix 0.1/0.8:
----------------------------------------------

 o  reduce the amount of static memory that is used for per process
    data. (keep it in a dynamically allocated page together with the copy of
    the process' stack and zp).
    
 o  use much more zp in the kernel.
 
 o  try to be less C64 specific in the kernel core.


  Any help is welcome !!!!
  (even questions are welcome, because they will help me building a minimal+
  simple+fast kernel)

Porting to other systems
------------------------

 All files that include "c64.h" must be changed.
 (currently: calib.s, console.s, init.s, keyboard.s, tasksw.s)
 You can either write completely new ones for replacement, or (if there are
 not that much things to change [eg. tasksw.s]) add some #ifdef/#else/#endif
 to the original sourcecode.
 
 Example
 -------
   Original file:
   
   ...
   ldx  #40   ; number of chars per lines
   ...
   
   Ported file:
   
   ...
   #ifdef C128VDC
   ldx  #80   ; VDC displays 80 chars per line
   #else
   ldx  #40   ; number of chars per line
   #endif
   ...
      
my TODO list:
-------------
  o  memory management (external memory)
  o  signals (run/stop key...)
  o  friend-list (explain it later:)
  o  environment
  o  more file-ops (mv, chmod, format,...)
  o  80 column console
  o  web-browser ??
  ...
  o  more (usefull) applications ?
   
compiling lunix
---------------

  Case A)

  You have a UNIX system...  (with gcc, and (GNU-)make installed)

  o  Make the develompent tools

     Do a "make devel" in the top level directory. You can also
     change into the devel_utils subdirectory and type "make" there.
     You should get the binaries of luna, lupo and lld. If you want, you
     can move the binaries into a common place (eg. /usr/local/bin) and/or
     add the path of the binaries to the system's search path

     PATH=/path/to/the/binaries:$PATH

     This may not be neccassary since the PATH variable will also be changed
     in the top level makefile.


  o  Make the Commodore64/Commodore128 binaries

     If your target is different from the C64, edit the top level
     makefile - line 14, replace c64 by c128 for example.

     Go into the parent directory and type "make". 

     If you've chaned the target or edited the makefile do a "make clean"
     first !

     Optional: Before making the binaries, change/optimize the
               configuration (edit "Makefile" and/or
               "kernel/<Machine>/config.h")


  o  Make a Commodore64 disk

     type "make package", this will create some selfextracting archives in
     the pkg subdirectory.

     for example:
       core.c64       -> system core
       apps.c64       -> applications
       help.c64       -> optional help files (used by "help" application)

     Copy these files to an empty (commodore-) floppy
     disk. On the C64 type (after inserting the newly created
     disk into drive 8, connected to your C64...)
      
       load"core.c64",8,1
       run 
       (will install the archived files)

       new
       load"...
       ...

     When every thing is installed

       load"loader",8
       run

     Don't expect me to explain, how to transfer binaries to a Commodore
     floppy. (I use a null modem connection between a PC running Linux and
     the Commodore64 running Novaterm9.5)


   o Make an Atari bootable disk

     Edit the toplevel makefile and change the line
     
     MACHINE=c64
     
     to
     
     MACHINE=atari

     and remove everything from MODULES= line

     Configure the kernel to your needs by editing kernel/atari/config.h.

     Then do:

     make distclean
     make devel
     make
     make disc

     which will result in bootable floppy image: pkg/lngboot.atr
     Don't worry with errors after 'make' step because currently applications
     for Atari cannot be built now. However they are binary compatible across
     all supported architectures so you might build system for C64/128 and
     copy applications from there.


   o Make a Commodore floppy

     Do

     make disc

     to build a ready for use floppy with all tools/modules/docs/scripts
     extracted. You can use this floppy with emulator or transfer it to a
     physical media.


   o Notes to the Commodore 128 version

     Edit the toplevel makefile and change the line

     MACHINE=c64

     to

     MACHINE=c128

     Configure the kernel to your needs by editing kernel/c128/config.h.
     Do a "make clean" (maybe even a "make distclean" in the kernel
     subdirectory is required) then "make" and "make package" to get
     a selfextracting archives in pkg (named "*.c128")
     
     Note: the *.c128 files can only be extracted in c64 mode (sorry)

   Note2: The applications in the apps subdirectory are architecture 
          independent and run on the C64 and C128 version of LNG
          without recompilation.


  Case B)

  You don't have the GNU tools available on your system (gcc,make,bash).
  Sorry, you can't build the system from source. But you can still run
  lunix (precompiled binaries for the Commodore64 are included)
  and read the source code..  ;-)



What does micros-hell do ?
--------------------------

  After starting LNG you get a "." prompt, this is the microshell
  (or init) prompt.

  Two commands are available for now:
  load: l <filename> 
  exit: x

  eg.

  l sh

  Will load and execute the "sh" application (default device is a 1541 with
  device number 8)
  sh is the standard LUnix-shell.

  l /disk8/ps

  Is equivalent to "l ps".

  l /disk9/ps

  Will load from device number 9 (for example a second 1541)


Multiple consoles
-----------------
If the kernel has been compiled with support for multiple consoles,
(compile option "MULTIPLE_CONSOLES" set in <MACHINE>/config.h)
you can switch between several virtual consoles using a hotkey sequence.

Init opens a console on startup, after issuing the first command (eg. "l sh")
this command takes over control of the current console. Init now tries to
open a second console, waiting for commands there. This means, that once
you have started a first command, the ". " prompt moves to the next
console. Even after the first command has finished, the init-prompt ". "
stays on the other console. You have to switch to the next console manually
to issue a second command.

Example:
.l sh         (load the first application)
-press F3 to go to the second console-
.l sh         (load the second application)
-press F1/F3 to jump between the 2 applications-
(you can also use SHIFT+COMMODORE to switch between consoles)

Limitations:
There is only one keyboard buffer to store pressed keys!
If the application on console 1 doesn't read from the keyboard, the keyboad
buffer fills up - switching to console 2 with an application running, that
is waiting for keystrokes, will pass all the buffered keystrokes to this
application! (tiggered by the next keystroke)


sh - the LUnix standard command shell
-------------------------------------

  The shell's prompt is "# ".
  Some example commandlines:
    
  # ps
        
  load and execute the PS application
            
  # sh
                
  load and start a subshell
                    
  # ps ! wc
                        
  load and execute PS, pass its' output to WC
                            
  # exit
                                
  leave the shell (you can also press CTRL+d at the beginning of a new line)


Shell goodies:

 History:
  you can reload old commandlines, by using the cursor keys (up/down).

 Line Completion:
  you can ask the shell to complete the current line (using the history of
  old command lines) by pressing the commodore-key (tab-key)


Applications
------------

    (232echo - for debugging)
      testapplication for serial-communication-modules (SERv2-API)
      eg. "swiftlink" module

    (232term - for debugging)
      test application for serial-communication-modules
      dump terminal (exit with CTRL+d) on top of the SERv2-API

    beep
      alert console user by a audible sound. beep prints ASCII code 7
      to standard error output. (the console must support beep)

    buf 
      reads from stdin into internal memory until EOF, then
      passes input to stdout (from memory)
      (nice, if you don't want floppy accesses, while receiving
      uuencoded data from a remote host via TCP/IP)

    cat [file]
      load file (stdin if ommitted) and pass to stdout

    connd port app [args] 
      connect demon, starts to listen on the specified port (0..255)
      and spawns the specified application, when someone connects.
      (needs TCP/IP subsystem)
      eg. "connd 200 sh&"
      offers shell-accesses.

    cp source-file destination-file
      simple file copy (slow)
      for small files (smaller than 30kbyte), i suggest to use 
      "cat source ! buf ! tee destination" instead

    date [-t hh:mm:ss.tt|-d ccyy.mm.dd|-w ww|-z (+|-)hhmm]
      Get/set date and time of RTC clock. You need a supported
      RTC module (or emulate one using ciartc)

    dcf77
      Read time signal from the DCF-77 module and sets time
      and date once a minute using a RTC module (eg. ciartc)

    time [-s hh:mm[:ss](a|p)m]
      set/get time of day directly from CIA1 TOD
      e.g.
        time -s 11:25am

    ftp host 
      connect to a remote host (via TCP/IP) using the Internet
      file transfer protocol (FTP).
      Supported commands:
        cd - change directory
        pwd - view current working directory
        type a/i - set ascii (a) or binary (i) transfer mode
        dir - list files in current directory (needs 80 column screen)
        more - display remote textfile
        get - get remote file
        quit - leave ftp (CTRL+d should also work)
      new: when downloading ftp uses all available internal memory
           for buffering (because disc accesses slow tcp down to a crawl)

    getty speed
      run getty at baud rate 'speed'
      allows to connect a VT100/102/ANSI terminal to your C64
      for a second/remote user

    kill [-sig] pid 
      send a signal to a running process
      valid signals are 0..7 and 9 (default).
      signal 9 terminates the process immediately

    ls [dir]
      list files in current or specified directory
      (the 1541 has just one directory)

    lsmod
      print table of all installed modules

    loop
      loop back packet driver for running local TCP/IP client-server
      applications (off line)

    meminfo
      print summary of usage of internal memory
      owner is the value stored in lk_memown and specifies owner/usage
      of the page(s).

    microterm
      simple terminal emulation
      (depends on serial-communication-module with simple API)

    more
      display text page wise (return - print next line, space - print
      next 20 lines, q - quit)

    ps
      print table of all processes (tasks) in the system
    
    rm [files...]
      remove (delete) files

    sh
      LUnix standard shell

    sleep [sec]
      sleep sec seconds (1 second if sec is ommitted)

    (sliptst - for debugging only)
      small testapplication, receives packet from packet-delivery-module
      (eg. "slip") and makes a hexdump
    
    strminfo
      Print short summary of all allocated streams in the system (open files)
      maj/min is the major and minor number of the device, for example
        3 0 - console 0
        3 1 - console 1
        2 8 - CBM drive 8 (connected to IEC serial bus)
      wr/rd is the number of open writing/reading ends

    tcpipstat
      print status of TCP/IP stack

    tee [file]
      pass stdin to file (or stdout if ommitted)

    telnet host port
      connect to a remote host via TCP/IP
      (see README.tcpip for more details)

    (testapp - for debugging only)
      simple hello world programm
      prints a small message, installs a signal handler (waits for
      signal 2), and consumes some CPU seconds.

    uname [-srvmpa]
      print information about the system
       -s  print operating system name (LNG)
       -v  print OS version
       -r  print OS release
       -m  print machine type (c64pal, c64ntsc, c128pal, c128ntsc)
       -p  print processor type (6510, with SCPU: s6510, with REU: 6510+r)
       -a  print all (shortcut for -srvmp)

    uptime
      print the time the system is up (time since last reboot)

    uudecode
      decode file (stdin) that was coded with uuencode

    uuencode [-m] rmt_name
      encode file (stdin) and write to stdout, when decoding a file
      named rmt_name is created

    wc [file]
      count lines, words, chars on stdin or file and report to stdout


Modules
-------

  API: "SER" Version 1  (ctrl, getc, putc)
    sswiftlink - swiftlink device driver
    sfifo64    - driver for 16550 UART based rs232-cards)
    srs232std  - driver for standard userport RS232 interface *not complete*

  API: "SER" Version 2 (ctrl)
    fifo64    - driver for 16550 UART based rs232-cards)
    rs232std  - driver for standard userport RS232 interface
    swiftlink - swiftlink device driver should also support Turbo232

  API: "PKG" Version 1 (putpacket, getpacket)
    slip - SLIP packet encapsulation over serial lines
    ppp  - PPP protocol and packet encapsulation over serial lines
    loop - loop back packet driver

  API: "IP4" Version 1 (connect, listen, accept, sockinfo)
    tcpip - TCP/IP packet wise communication

  API: "RTC" Version 1 (time_read,time_write, date_read, date_write, raw_write)
    ciartc   - emulate real time clock using timer alarm of CIA1
    dcf77    - read German time signal from user port (radio)
    ide64rtc - RTC on IDE64 interface card
    smwrtc   - for the Smart Watch (Dallas DS1216 B series)


Module-Dependencies
-------------------

  sfifo64      (SERv1)  getty
  srs232std   -------> 
  sswiftlink            microterm

                      |
                      | 232echo
                      | 232term
                      |
              (SERv2) |        (PKG)   |         (IP4)    telnet
  swiftlink  -------> | slip  -------> | tcpip  ------->  ftp
  rs232std            | ppp            |                  connd 
                                       |
  loop  -----------------------------> |
                                       |

Setup of TCP/IP subsystem
-------------------------

  in case of SLIP

  l sh
  # swiftlink
  # slip 9600 &           (or an other supported baud rate)
  # tcpip 192.168.0.64 &  (replace with the IP address you use)

  or in case of PPP

  l sh
  # swiftlink
  # ppp 9600 &            (you may also apply username and password here)
  # tcpip &               (the IP address will be autodetected)

  if you don't have a swiftlink or compatible cardridge, you may also
  use rs232std - the driver for the standard userport interface
  (up to 2400baud)


Micro Terminal
--------------

  Some of the basic VT102/ANSI escape codes are implemented (enough for 
  running IRC remotely)

    Example (i assume you have a linux-box next to your C64):

    - build a nullmodem connection between the second serial port of your
      Linux-PC and the Swiftlink-Cardridge that is pugged into the C64.
      (and configured to NMI and $de00)

    - load and start linux and LNG (microterm)
        l sswiftlink
        l microterm

        or

        l swiftlink / rs232std
        l 232term

    - log into linux as root and type:
        /sbin/setserial /dev/cua1 spd_normal
        /sbin/agetty -h /dev/cua1 9600 vt102

    - you should get a login message on the C64 screen.
      log into your linux box and type
        stty cols 40
        stty rows 25
        irc

      HAVE FUN !


SLIP based connection
---------------------

First get the above (micro terminal) running, than read on.

On Linux-side (just an example):
  Add the line "192.168.0.64 c64" to the file /etc/hosts
  slattach -v -s BAUDRATE -p slip /dev/ttyS1 &
  ifconfig sl0 up mtu 984 192.168.0.1
  route add -host 192.168.0.64 sl0

  implies: C64 has IP 192.168.0.64 Linux-Bos has IP 192.168.0.1
           Nullmodem connection at serial port No.2 of the Linux-Box 

On LUnix-site:
  swiftlink  (or rs232std)
  slip BAUDRATE &
  tcpip 192.168.0.64 &

Now try "ping c64" on your Linux-Box (you might want to make a dump of all
IP-Packets flowing between Linux and LUnix: "tcpdump -i sl0")

Run "connd 200 sh" on the LUnix side, than log into LUnix from the Linux-Box
with "telnet c64 200"

Get redir from http://users.qual.net/~sammy/hacks to let people from the
internet log into your C64 trough the Linux-Box (Linux-Box acting as a kind
of firewall).


PPP based connection
--------------------

Same as SLIP with some small differences. PPP isn't just a way to 
encapsulate IP packets, it also includes a couple of protocols to
negotiate link capabilities and IP configuration. The current PPP
implementation is a baseline solution, there are still many things to
improve. 

sample setup to connect with a linux machine...

on linux side:
  pppd /dev/ttyS1 BAUDRATE 192.168.0.1:192.168.0.64 passive noauth

  You might also need to add the "local" option to pppd, if your nullmodem
  cable doesn't connect the CD, DTR and DTS lines.
 
on LUnix side:
  swiftlink / rs232std
  ppp BAUDRATE &
  tcpip &

The PPP implementation on LUnix side will retrieve the IP settings from
the remote machine and will send a faked IP packet to the TCP/IP stack
to make him learn his IP-address automatically.

Limitations:
 There currently is no way to terminate the PPP connection under LUnix.
 This means you have to restart LUnix each time you want to do a new
 ppp-connection.


Known Bugs
----------

  Some!
  Plase let me know, if you find a way to crash the system
  (report any other bug too)

  other bugs:
   - both ppp and slip work very unreliable at baud rates higher than
     19200 (at least at 1MHz - i prefer to run it at 9600 baud)


Additional documentation
------------------------

apps/README   - more information about writing and compiling apps - for luna
		and ca65 (.o65 file format)

kernel/README - detailed description of system variables and some other
                more general things

kernel/atari/README      - Status of the Atari port
devel_utils/atari/README - Atari tools readme file

There are several other READMEs in the kernel directory.

        
Where to get it
---------------

  You can get all stuff mentioned above from my WWW site at:

   http://www.heilbronn.netsurf.de/~dallmann/lunix/lng.html

  Starting with version 0.17 LUnix is hosted on sourceforge
  (www.sourceforge.net). You can download daily snapshots or
  directly access the source tree through CVS.
   

Conclusion
----------
 
  Take a look into the sources, make your modifications, find bugs, have ideas
  and (most important) SEND REPORTS !  :-)
  
  Besides don't forget: HAVE FUN !!
     
...
  Daniel  (eMail: Dallmann@heilbronn.netsurf.de)
