.PHONY : all clean

CC=gcc
COMPFLAGS=-O6 -ansi -Wall -W -Wstrict-prototypes -Wshadow -Wmissing-declarations -Wmissing-prototypes -fomit-frame-pointer

# list of applications
APPS=makeatr makeimage femul-1.4
OLDAPPS=binload-2.5 atr2unix-1.2 unix2atr-0.9

all : $(APPS)

clean :
	-rm $(APPS)

$(APPS) : Makefile

# Rules
% : %.c ; $(CC) $< -o $@ $(COMPFLAGS)
