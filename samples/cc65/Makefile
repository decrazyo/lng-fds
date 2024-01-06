
CC65_ASMINC=/usr/lib/cc65/asminc

all: hello.o65

hello.o65: hello.c
	#cl65 -t none crt0.s hello.c none.lib -o hello -C lunix.cfg
	-ca65 -l -t lunix crt0.s -o crt0.o
	-ca65 -I $(CC65_ASMINC) -l -t lunix ctype.s -o ctype.o
	-ca65 -I $(CC65_ASMINC) -l -t lunix stdio.s -o stdio.o
	-cc65 -t lunix hello.c -o hello.s
	-ca65 -l -t lunix hello.s -o hello.o
	-ld65 -C lunix.cfg -o hello.o65 crt0.o hello.o none.lib stdio.o ctype.o
	
clean:
	-rm hello
	-rm *.lst
	-rm *.o
