# ============================================================================
# Makefile for NeuroSync-Silicon / NeuroBIST-Edge Linux Subsystem
# ============================================================================

obj-m += neuro_driver.o

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

default:
	@echo "================================================================="
	@echo " NeuroSync-Silicon: Building Linux Kernel Device Driver"
	@echo " Target Interface: /dev/neuro_edge"
	@echo "================================================================="
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
