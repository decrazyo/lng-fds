.PHONY : all clean

COMPFLAGS=

export LUPO_INCLUDEPATH=../include
export LNG_LIBRARIES=../lib/libstd.a

VPATH=../include

# list of applications
APPS=ca65/skeleton.o65 luna/skeleton

# list of applications that must be linked against libstd
LAPPS=

all : $(APPS) $(LAPPS)
	$(MAKE) -C cc65 all
	$(MAKE) -C scc6502 all

# Rules

% : %.s ; luna -qWR $< -o $@ $(COMPFLAGS)
%.o : %.s ; luna -qWO $< -o $@ $(COMPFLAGS)

%.o65 : %.ca65.s
# These are allowed to fail because cc65 package may not be present
	-lupo -dUSING_CA65=1 $< -o $@.s
	-ca65 -t lunix $@.s
	-ld65 -C ca65/lunix.cfg -o $@ $@.o
#	-@ld65 -t lunix -o $@ $@.o

$(LAPPS) : $(LAPPS:%=%.o)
	lld -qN $@.o -o $@

# additional dependencies
$(APPS) : system.h rs232.h jumptab.h stdio.h

$(LAPPS) : system.h rs232.h jumptab.h stdio.h ../lib/libstd.a

clean   :
	-rm -f $(APPS) $(LAPPS) $(LAPPS:%=%.o) *.o65*
	$(MAKE) -C cc65 clean
	$(MAKE) -C scc6502 clean

