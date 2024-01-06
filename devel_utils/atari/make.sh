#!/bin/sh

# This script will prepare a disk image with LNG
# The disk will be booted by MyDOS and then autoexec.bat will load LNG

if [ ! -f makeimage ]; then gcc $CFLAGS -o makeimage makeimage.c; fi
if [ ! -f unix2atr ]; then  gcc $CFLAGS -o unix2atr unix2atr-0.9.c; fi

if [ ! -f ../../kernel/boot.atari ]; then DIR=$PWD; cd ../..; make; cd $DIR; fi

rm -rf atarifiles lngboot.atr
mkdir atarifiles
cp mydos/* atarifiles/
cp ../../kernel/boot.atari .
cp ../../kernel/lunix.atari .
./makeimage boot.atari lunix.atari atarifiles/LUNIX.BIN
./unix2atr -um 720 lngboot.atr atarifiles
rm boot.atari lunix.atari atarifiles/*
rmdir atarifiles

echo "Generation complete, use lngboot.atr"
