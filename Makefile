# compile switches:
# =================
#  look into the machine specific config.h for details on compile switches.
#  (eg. kernel/c64/config.h)

COMPFLAGS=

# selection of target machine
# ===========================
#
# MACHINE=c64 to create Commodore64 version (binaries in bin64)
# MACHINE=c128 for Commodore128 version (binaries in bin128)
# MACHINE=atari for Atari 65XE/800/130 version (no binaries right now)
# MACHINE=nintendo for NES/Famicom (binaries in bintendo)

MACHINE=nintendo

# Modules to include in package (created with "make package")

MODULES=sswiftlink sfifo64 rs232std swiftlink fifo64

# Applications to include in package
# the applications (in binary form) do not depend on the machine selection

APPS=getty lsmod microterm ps sh sleep testapp wc cat tee uuencode \
     uudecode 232echo 232term kill rm ls buf cp uptime time meminfo \
     strminfo uname more beep help env date ciartc dcf77 smwrtc \
     hextype clear true false echo touch expand \
     b-co b-cs ide64rtc cd pwd
	         
# Test Applications

TAPPS=amalloc

# Scripts

SAPPS=dir man hello.sh sysinfo sysinfo.sh

# Internet Applications
# will be put in the same package als APPS now, but may go into a
# seperate one, in case the APP-package grows to big

IAPPS=connd ftp tcpipstat tcpip ppp loop slip httpd telnet popclient

#============== end of configurable section ============================

.PHONY : all apps kernel libstd help package clean distclean devel

export PATH+=:$(PWD)/devel_utils/:$(PWD)/devel_utils/nintendo:$(PWD)/devel_utils/atari:.
export LUPO_INCLUDEPATH=:$(PWD)/kernel:$(PWD)/include
export LNG_LIBRARIES=$(PWD)/lib/libstd.a
export COMPFLAGS
export MACHINE

ifeq "$(MACHINE)" "nintendo"
    BINDIR=bintendo
else ifeq "$(MACHINE)" "atari"
    BINDIR=binatari
else
    BINDIR=$(patsubst c%,bin%,$(MACHINE))
endif

ifeq "$(MACHINE)" "nintendo"
all : kernel libstd apps
else ifeq "$(MACHINE)" "atari"
all : kernel
else
all : kernel libstd apps help
endif

apps : devel kernel libstd
	$(MAKE) -C apps

samples : devel libstd
	-$(MAKE) -C samples

kernel : devel
	-rm -f include/config.h
	$(MAKE) -C kernel

libstd : devel
	$(MAKE) -C lib

help :
	$(MAKE) -C help

devel :
	$(MAKE) -C devel_utils
	$(MAKE) -C devel_utils/nintendo
	# atari dev tools fail to build. commenting these out for now.
	#$(MAKE) -C devel_utils/atari
	#$(MAKE) -C devel_utils/apple

binaries: all
	-mkdir $(BINDIR)
	-cp kernel/boot.$(MACHINE) kernel/lunix.$(MACHINE) $(MODULES:%=kernel/modules/%) $(BINDIR)

mesen: nintendodisc
	# mesen label files
	-rm ./lunix.mlb
	sed -nE 's/#define\s+(\w+)\s+([0-9]+).*/\2 \1/p' ./include/zp.h | xargs printf 'R:%x:%s\n' >> ./lunix.mlb
	sed -nE 's/#define\s+(\w+)\s+\$$(.*)/\1 \2/p' ./include/ksym.h | awk '{ $$2 = sprintf("%d","0x" $$2) - "0x6000"; printf("W:%x:%s\n", $$2, $$1) }' >> ./lunix.mlb
	mono ~/.local/bin/Mesen.exe ./lunix.fds &

# TODO: make packaging smarter. don't just hard-code everything.
nintendodisc: nintendopackage
	mkfds -# -i -b 4 lunix.fds pkg/kyodaku.bin pkg/ascii.bin pkg/reset.bin pkg/boot.bin pkg/lunix.bin \
pkg/sh.bin \
pkg/ls.bin \
pkg/cat.bin \
pkg/pwd.bin \
pkg/ps.bin \
pkg/wc.bin \
pkg/sleep.bin \
pkg/kill.bin \
pkg/meminfo.bin \
pkg/uname.bin \
pkg/more.bin \
pkg/env.bin \
pkg/clear.bin \
pkg/true.bin \
pkg/false.bin \
pkg/echo.bin \
pkg/hello.bin

nintendopackage: binaries
	-mkdir pkg
	mkbin -n 'KYODAKU-' -a 0x2800 -t 2 pkg/kyodaku.bin $(BINDIR)/kyodaku.nam
	mkbin -n 'ASCII' -a 0x1000 -t 1 pkg/ascii.bin $(BINDIR)/ascii.chr
	mkbin -n 'RESET' -a 0xdffc -s 2 pkg/reset.bin $(BINDIR)/boot.nintendo
	mkbin -n 'BOOT' pkg/boot.bin $(BINDIR)/boot.$(MACHINE)
	mkbin -n 'LUNIX' pkg/lunix.bin $(BINDIR)/lunix.$(MACHINE)
	mkbin -n 'sh' -a 0x0000 pkg/sh.bin apps/sh
	mkbin -n 'ls' -a 0x0000 pkg/ls.bin apps/ls
	mkbin -n 'cat' -a 0x0000 pkg/cat.bin apps/cat
	mkbin -n 'pwd' -a 0x0000 pkg/pwd.bin apps/pwd
	mkbin -n 'ps' -a 0x0000 pkg/ps.bin apps/ps
	mkbin -n 'wc' -a 0x0000 pkg/wc.bin apps/wc
	mkbin -n 'sleep' -a 0x0000 pkg/sleep.bin apps/sleep
	mkbin -n 'kill' -a 0x0000 pkg/kill.bin apps/kill
	mkbin -n 'meminfo' -a 0x0000 pkg/meminfo.bin apps/meminfo
	mkbin -n 'uname' -a 0x0000 pkg/uname.bin apps/uname
	mkbin -n 'more' -a 0x0000 pkg/more.bin apps/more
	mkbin -n 'env' -a 0x0000 pkg/env.bin apps/env
	mkbin -n 'clear' -a 0x0000 pkg/clear.bin apps/clear
	mkbin -n 'true' -a 0x0000 pkg/true.bin apps/true
	mkbin -n 'false' -a 0x0000 pkg/false.bin apps/false
	mkbin -n 'echo' -a 0x0000 pkg/echo.bin apps/echo
	mkbin -n 'hello' -a 0x0000 pkg/hello.bin $(BINDIR)/hello.txt


cbmpackage : binaries
	-mkdir pkg
	cd $(BINDIR) ; mksfxpkg $(MACHINE) ../pkg/core.$(MACHINE) \
           "*loader" boot.$(MACHINE) lunix.$(MACHINE) $(MODULES)
	cd apps ; mksfxpkg $(MACHINE) ../pkg/apps.$(MACHINE) $(APPS) $(IAPPS)
	cd help ; mksfxpkg $(MACHINE) ../pkg/help.$(MACHINE) *.html
	cd scripts ; mksfxpkg $(MACHINE) ../pkg/scripts.$(MACHINE) $(SAPPS)
	echo "The following may fail"
	-cd samples ; \
	 cp --target-directory=. luna/skeleton ca65/skeleton.o65 cc65/hello ; \
	 mksfxpkg $(MACHINE) ../pkg/samples.$(MACHINE) skeleton skeleton.o65 hello ; \
	 rm skeleton skeleton.o65 hello

ataripackage: binaries
	makeimage $(BINDIR)/boot.$(MACHINE) $(BINDIR)/lunix.$(MACHINE) $(BINDIR)/atari.bin
	cp $(BINDIR)/atari.bin pkg

ataridisc: binaries
	makeatr lng-$(MACHINE).atr $(BINDIR)/atari.bin

cbmdisc: binaries
	echo creating LUnix disc image for $(MACHINE)
	c1541 -format lunix,00 d64 lunix-$(MACHINE).d64 > /dev/null

	cd $(BINDIR); for i in \
		loader fasthead fastloader \
		boot.$(MACHINE) lunix.$(MACHINE) $(MODULES) \
		; do c1541 -attach ../lunix-$(MACHINE).d64 -write $$i > /dev/null \
		; done

	cd kernel; for i in \
		lunixrc \
		; do c1541 -attach ../lunix-$(MACHINE).d64 -write $$i .$$i > /dev/null \
		; done

	cd apps; for i in \
		$(APPS) $(IAPPS) $(TAPPS) \
		; do c1541 -attach ../lunix-$(MACHINE).d64 -write $$i > /dev/null \
		; done

	cd help; for i in \
		*.html \
		; do c1541 -attach ../lunix-$(MACHINE).d64 -write $$i > /dev/null \
		; done

	cd scripts; for i in \
		$(SAPPS) \
		; do c1541 -attach ../lunix-$(MACHINE).d64 -write $$i > /dev/null \
		; done

ifeq "$(MACHINE)" "nintendo"
disc:	nintendodisc
package: nintendopackage
else ifeq "$(MACHINE)" "atari"
disc:	ataridisc
package: ataripackage
else
disc:	cbmdisc
package: cbmpackage
endif

clean :
	$(MAKE) -C kernel clean
	$(MAKE) -C apps clean
	$(MAKE) -C lib clean
	$(MAKE) -C help clean
	$(MAKE) -C samples clean

distclean : clean
	$(MAKE) -C kernel distclean
	$(MAKE) -C devel_utils clean
	$(MAKE) -C devel_utils/atari clean
	$(MAKE) -C devel_utils/apple clean
	$(MAKE) -C devel_utils/nintendo clean
	-cd kernel ; rm -f boot.c* lunix.c* globals.txt
	-cd bin64 ; rm -f $(MODULES) boot.* lunix.* lng.c64
	-cd bin128 ;  rm -f $(MODULES) boot.* lunix.* lng.c128
	-cd bintendo ; rm -f $(MODULES) boot.* lunix.*
	-cd include ; rm -f jumptab.h jumptab.ca65.h ksym.h zp.h
	-rm -rf pkg binatari
	find . -name "*~" -exec rm -v \{\} \;
	find . -name "#*" -exec rm -v \{\} \;
