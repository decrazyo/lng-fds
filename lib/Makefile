.PHONY : all clean

COMPFLAGS=

export LUPO_INCLUDEPATH=../include
VPATH=../include

# list of applications
PARTS=libc_malloc libc_free libc_remalloc sreadline print_hex8 getopt \
      bcdtohex hextobcd checkbcd checkdate dateconvert adc_32_8 mult_32_8

all : libstd.a

libstd.a : $(PARTS:%=%.o)
	lld -Lo libstd.a $(PARTS:%=%.o)

# Rules
%.o : %.s ; luna -qWO $< -o $@ $(COMPFLAGS)

# additional dependencies
$(PARTS:%=%.o) : lib_conf.h

clean   : 
	-rm $(PARTS:%=%.o) libstd.a
