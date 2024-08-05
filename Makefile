# ******************************************************************************
#
# @file			Makefile
#
# @brief        Makefile for embark qemu launcher utility
#
# @copyright   Copyright (C) 2024 Barrett Edwards. All rights reserved.
#        
# @date        Jul 2024
# @author      Barrett Edwards <thequakemech@gmail.com>
#
# This script requires the use of a bash version 4+ which supports arrays. 
# On macOS, the current bash version is 3.x. So a newer version of bash is
# needed and can be installed with homebrew. This Makefile includes targets 
# that can be used to install homebrew and then bash on OSX 
#
# ******************************************************************************

INSTALL_PATH?=/usr/local/bin
BASHPATH=$(shell which bash)

all: 

install_homebrew: 
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

install_bash:
	sudo brew install bash 	

install: embark.bash
	sudo cp embark.bash $(INSTALL_PATH)/embark
	if [ `uname -a | cut -d" " -f1` = "Darwin" ] ; then \
		sudo sed -e "1s_^.*_#!$(BASHPATH)_" -i "" $(INSTALL_PATH)/embark ; \
	fi

uninstall:
	sudo rm $(INSTALL_PATH)/embark

# List all non file name targets as PHONY
.PHONY: all install install_homebrew install_bash uninstall

# Variables 
# $^ 	Will expand to be all the sensitivity list
# $< 	Will expand to be the frist file in sensitivity list
# $@	Will expand to be the target name (the left side of the ":" )
# -c 	gcc will compile but not try and link 
