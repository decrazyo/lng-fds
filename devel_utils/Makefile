.PHONY : all clean

CC=gcc
COMPFLAGS=-O6 -ansi -Wall -W -Wstrict-prototypes -Wshadow -Wmissing-declarations -Wmissing-prototypes -fomit-frame-pointer

# list of applications
APPS=luna lupo lld relate chkobj chklib mksfxpkg

all : $(APPS)

clean :
	-rm $(APPS)

$(APPS) : Makefile

# Rules
% : %.c ; $(CC) $< -o $@ $(COMPFLAGS)
