#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

include $(DEVKITARM)/ds_rules

dslink7sourcefiles :=	$(wildcard arm7/source/*.c) $(wildcard arm7/source/*.s)

dslink9sourcefiles :=	$(wildcard arm9/source/*.c) $(wildcard arm9/source/*.s) \
			$(wildcard arm9/data/*.*)

dslink7sfiles	:=	source/bootstubarm7.s
dslink7cfiles	:=	source/exodecr.c

dslink9files	:=	source/bootstubarm9.s

dslink7ofiles	:=	$(dslink7sfiles:.s=.o) $(dslink7cfiles:.c=.o)
dslink9ofiles	:=	$(dslink9files:.s=.o)

DEPSDIR	:=	.

export TOPDIR	:=	$(CURDIR)

UNAME := $(shell uname -s)

ifneq (,$(findstring MINGW,$(UNAME)))
	EXEEXT			:= .exe
endif

.PHONY: host/dslink$(EXEEXT)

all:	host/dslink$(EXEEXT) dslink.nds

dslink.nds:	data dslink7.elf dslink9.elf
	ndstool -h 0x200 -c $@  -b dslink.bmp "dslink;the wifi code loader;" -7 dslink7.elf -9 dslink9.elf

host/dslink$(EXEEXT):
	$(MAKE) -C host

source/bootstubarm9.o: data/dslink.arm9.exo data/dslink.arm7.exo

CFLAGS	:=	-O2

dslink7.elf:	$(dslink7ofiles)
	$(CC) -nostartfiles -nostdlib -specs=ds_arm7.specs -Wl,--nmagic -Wl,-Map,dslink7.map $^ -o $@

dslink9.elf:	$(dslink9ofiles)
	$(CC) -nostartfiles -nostdlib -specs=ds_arm9.specs -Wl,--nmagic -Wl,-Map,dslink9.map $^ -o $@

deps:
	mkdir deps

data:
	mkdir data

data/dslink.arm7.exo: arm7/dslink.arm7.bin
	exomizer raw -b -q $< -o $@

data/dslink.arm9.exo: arm9/dslink.arm9.bin
	exomizer raw -b -q $< -o $@

arm7/dslink.arm7.bin:	arm7/dslink.arm7.elf
	$(OBJCOPY) -O binary $< $@

arm9/dslink.arm9.bin:	arm9/dslink.arm9.elf
	$(OBJCOPY) -O binary $< $@

arm7/dslink.arm7.elf:	$(dslink7sourcefiles)
	@$(MAKE) ARM7ELF=$(CURDIR)/$@ -C arm7

arm9/dslink.arm9.elf:	$(dslink9sourcefiles) arm9/Makefile
	@$(MAKE) ARM9ELF=$(TOPDIR)/$@ -C arm9

clean:
	@rm -fr data deps $(dslink7ofiles) source/bootstubarm9i.o $(dslink9ofiles)
	@rm -fr dslink7.elf dslink9.elf dslink7.map dslink9.map dslink.nds source/*.d
	@$(MAKE) -C arm7 clean
	@$(MAKE) -C arm9 clean
	@$(MAKE) -C host clean
