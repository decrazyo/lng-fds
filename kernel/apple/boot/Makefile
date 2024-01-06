# simple Makefile (DD)
#  equivalent to TOMAKE script

.PHONY : clean bootdisc

bootdisc : bootldr1 boot.dsk
	diskimage boot.dsk -b bootldr1 -t0 -s0

bootldr1 : bootldr1.h bootldr1.s
	luna -Oq bootldr1.s -o bootldr1.o
	lld -a -s 2048 -o bootldr1 bootldr1.o

boot.dsk :
	diskimage boot.dsk -f

clean :
	-rm bootldr1 bootldr1.o boot.dsk
