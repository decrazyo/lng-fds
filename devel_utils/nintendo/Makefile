.PHONY : all clean

CC=gcc
COMPFLAGS=-std=gnu99 -Wall

# list of applications
APPS=mkbin mkfds

all : $(APPS)

clean :
	-rm $(APPS)

$(APPS) : Makefile

# Rules
% : %.c ; $(CC) $< -o $@ $(COMPFLAGS)
