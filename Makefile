
# PRU_CGT environment variable must point to the TI PRU compiler directory. E.g.:
#(Linux) export PRU_CGT=/home/jason/ti/ccs_v6_1_0/ccsv6/tools/compiler/ti-cgt-pru_2.1.0
#(Windows) set PRU_CGT=C:/TI/ccs_v6_0_1/ccsv6/tools/compiler/ti-cgt-pru_2.1.0
#export PRU_CGT=/usr/share/ti/cgt-pru
export PRU_CGT=/usr

ifndef PRU_CGT
define ERROR_BODY

**************************************************************************************
PRU_CGT environment variable is not set. Examples given:
(Linux) export PRU_CGT=/home/jason/ti/ccs_v6_1_0/ccsv6/tools/compiler/ti-cgt-pru_2.1.0
(Windows) set PRU_CGT=C:/TI/ccs_v6_0_1/ccsv6/tools/compiler/ti-cgt-pru_2.1.0
**************************************************************************************

endef
$(error $(ERROR_BODY))
endif

MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(notdir $(patsubst %/,%,$(dir $(MKFILE_PATH))))
PROJ_NAME1=pru0
PROJ_NAME2=pru1
LINKER_COMMAND_FILE=./AM335x_PRU.cmd
INCLUDE=--include_path=./include/
STACK_SIZE=0x100
HEAP_SIZE=0x100
GEN_DIR=build
MACHINE := $(shell awk '{print $$NF}' /proc/device-tree/model)
TM1_PIN=P8_27
TM2_PIN=P8_27
MODE=pruout
#Common compiler and linker flags (Defined in 'PRU Optimizing C/C++ Compiler User's Guide)
CFLAGS=-v3 -O2 --display_error_number --endian=little --hardware_mac=on --obj_directory=$(GEN_DIR) --pp_directory=$(GEN_DIR) -ppd -ppa
#Linker flags (Defined in 'PRU Optimizing C/C++ Compiler User's Guide)
LFLAGS=--reread_libs --warn_sections --stack_size=$(STACK_SIZE) --heap_size=$(HEAP_SIZE)

TARGET1=$(GEN_DIR)/$(PROJ_NAME1).out
TARGET2=$(GEN_DIR)/$(PROJ_NAME2).out
MAP1=$(GEN_DIR)/$(PROJ_NAME1).map
MAP2=$(GEN_DIR)/$(PROJ_NAME2).map
SOURCES=$(wildcard *.cpp)
#Using .object instead of .obj in order to not conflict with the CCS build process
OBJECT1=$(patsubst %,$(GEN_DIR)/%,$(SOURCES:.cpp=.object)) $(GEN_DIR)/irigacq-pru0.object 
OBJECT2=$(patsubst %,$(GEN_DIR)/%,$(SOURCES:.cpp=.object)) $(GEN_DIR)/irigacq-pru1.object
#OBJECTS=$(patsubst %,$(GEN_DIR)/%,$(SOURCES:.cpp=.object)) 

all: printStart $(TARGET1) $(TARGET2) printEnd

$(GEN_DIR)/irigacq-pru0.object: irigacq-pru0.asm
	@mkdir -p $(GEN_DIR)
	@echo 'CC	$<'
	clpru --include_path=$(PRU_CGT)/include $(INCLUDE) $(CFLAGS) -fe $@ $<

$(GEN_DIR)/irigacq-pru1.object: irigacq-pru1.asm
	@mkdir -p $(GEN_DIR)
	@echo 'CC	$<'
	clpru --include_path=$(PRU_CGT)/include $(INCLUDE) $(CFLAGS) -fe $@ $<

printStart:
	@echo ''
	@echo '************************************************************'
	@echo 'Building project: tm-arm'
	@echo '**********************************************************************************************'
	gcc  -O3 -Ofast -Wall -o tm-arm tm-arm.c -lprussdrv -lpthread
printEnd:
	@echo '************************************************************'
	@echo 'Building project: tm-pru firmware'
	@echo '**********************************************************************************************'
printEnd:
	@echo ''
	@echo 'Finished building project: tm-pru firmware'
	@echo '************************************************************'
	@echo ''

# Invokes the linker (-z flag) to make the .out file
$(TARGET1): $(OBJECT1) $(LINKER_COMMAND_FILE)
	@echo ''
	@echo 'Building targets: '
	@echo 'Invoking: PRU Linker'
	$(PRU_CGT)/bin/clpru $(CFLAGS) -z -i$(PRU_CGT)/lib -i$(PRU_CGT)/include $(LFLAGS) -o $(GEN_DIR)/irigacq-pru0.out $(GEN_DIR)/irigacq-pru0.object  -m$(MAP1) $(LINKER_COMMAND_FILE) --library=libc.a
	$(PRU_CGT)/bin/hexpru bin0.cmd
	@echo 'Finished building targets: '
	@echo ''
	@echo 'Output files can be found in the "$(GEN_DIR)" directory'

$(TARGET2): $(OBJECT2) $(LINKER_COMMAND_FILE)
	@echo ''
	@echo 'Building targets: '
	@echo 'Invoking: PRU Linker'
	$(PRU_CGT)/bin/clpru $(CFLAGS) -z -i$(PRU_CGT)/lib -i$(PRU_CGT)/include $(LFLAGS) -o $(GEN_DIR)/irigacq-pru1.out $(GEN_DIR)/irigacq-pru1.object  -m$(MAP2) $(LINKER_COMMAND_FILE) --library=libc.a
	$(PRU_CGT)/bin/hexpru bin1.cmd
	@echo 'Finished building targets: '
	@echo ''
	@echo 'Output files can be found in the "$(GEN_DIR)" directory'

# Invokes the compiler on all c files in the directory to create the object files
$(GEN_DIR)/%.object: %.c
	@mkdir -p $(GEN_DIR)
	@echo ''
	@echo 'Building file: $<'
	@echo 'Invoking: PRU Compiler'
	$(PRU_CGT)/bin/clpru --include_path=$(PRU_CGT)/include $(INCLUDE) $(CFLAGS) -fe $@ $<

.PHONY: all clean

# Remove the $(GEN_DIR) directory
clean:
	@echo ''
	@echo '************************************************************'
	@echo 'Cleaning project: irig-pru firmware'
	@echo ''
	@echo 'Removing files in the "$(GEN_DIR)" directory'
	@rm -rf $(GEN_DIR)
	@echo ''
	@echo 'Finished cleaning project: irig-pru'
	@echo '************************************************************'
	@echo ''

# Includes the dependencies that the compiler creates (-ppd and -ppa flags)
-include $(OBJECT1:%.object=%.pp)

run:
	@echo ''
	@echo '************************************************************'
	@echo 'Running the application'
	./tm-arm $(GEN_DIR)/text0.bin $(GEN_DIR)/text1.bin
	@echo 'Application execution completed'
	@echo '************************************************************'
pinsetup:
# Configure the PRU pins based on which Beagle is running
	@echo '************************************************************'
#	@echo 'Configuring the PRU pins '
#	@echo ' Beaglebone $(MACHINE) identified '
#    @config-pin  $(TM1_PIN) $(MODE) 
#	@echo ' channel $(TM1_PIN) $(MODE)  '
#	@config-pin -q $(TM1_PIN) 
