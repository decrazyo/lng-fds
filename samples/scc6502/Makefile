#******************************************************************************
#
# Filename:	scc6502/tests/Makefile
#
# Description:
#
# Update History:   (most recent first)
#     I. Curtis  18-Jun-97 20:57 -- Created.
#
#******************************************************************************

SCC=/home/groepaz/Desktop/lng/scc6502
LNG=/home/groepaz/Desktop/lng/cvs02012003/lng

export PATH+=:$(LNG)/devel_utils/:$(LNG)/devel_utils/atari:.
export SCC_INCPATH=$(SCC)/include
export SCC_LIBPATH=$(SCC)/lib
export LUPO_INCLUDEPATH=$(LNG)/include:$(SCC_INCPATH):$(SCC_LIBPATH)
export LNG_LIBRARIES=$(LNG)/lib/libstd.a

LUPO_INCLUDEPATH=$(LNG)/include:$(SCC_INCPATH):$(SCC_LIBPATH)

TESTS=hello first second third fourth fifth case extern hexdump

#.PRECIOUS: %.s %.i %.o

#%.s:%.c
#	@$(SCC)/scc6502 $*.c

#%.o:%.s
#	@luna -WO -o $*.o $*.s

#%.o:%.c
#	@$(SCC)/scc6502 $*.c
#	@luna -WO -o $*.o $*.s

%:%.c
	-$(SCC)/scc6502 -tlunix -I$(SCC_INCPATH) -L$(SCC_LIBPATH) $*.c
	-luna -WR -o $* $*.s

all: $(TESTS)

clean:
	-rm -f $(TESTS)
	-rm -f *.o
	-rm -f *.a
	-rm -f *.s 
	-rm -f c64.out
