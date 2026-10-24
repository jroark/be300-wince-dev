# Shared build rules for BE-300 (Windows CE 3.0 MIPS) apps.
#
# In an app directory:
#     APP     := Hello            # program name: exe, package, launcher key
#     CAPTION := Hello BE-300     # optional launcher caption
#     include ../../be300.mk
#
# Targets:
#   all      build/$(APP).exe and build/$(APP).cbea (+ Setup.ini)
#   run      install the .cbea into a scratch NAND copy and boot the emulator
#   cf       build/$(APP)-cf.img: CF card that auto-launches the exe
#            (\CE\R4100\AutoRun.exe, plus EXTRA_FILES)
#   cf-run   boot the stock NAND (scratch copy) with that CF card inserted
#   clean
# Override SRCS, RCS, LIBS, EXTRA_FILES, CBEA_FLAGS (extra mkcbea.py
# options), CF_SIZE (MB) and CFLAGS as needed.

BE300_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
LLVM_BIN   ?= $(shell brew --prefix llvm 2>/dev/null || echo /opt/homebrew/opt/llvm)/bin

CC     := $(BE300_ROOT)/tools/be300-cc
LD     := $(BE300_ROOT)/tools/be300-ld
MKCBEA := $(BE300_ROOT)/tools/mkcbea.py
MKCF   := $(BE300_ROOT)/tools/mkcf.sh
RUNEMU := $(BE300_ROOT)/tools/run-emu.sh
AR     := $(LLVM_BIN)/llvm-ar
RC     := $(LLVM_BIN)/llvm-rc

APP         ?= $(notdir $(CURDIR))
CAPTION     ?= $(APP)
SRCS        ?= $(wildcard *.c)
RCS         ?= $(wildcard *.rc)
LIBS        ?= coredll
EXTRA_FILES ?=
CBEA_FLAGS  ?=
CFLAGS      ?= -Os -Wall
CF_SIZE     ?= 16
BUILD       ?= build

RT_SRCS := $(wildcard $(BE300_ROOT)/rt/*.c)
RT_OBJS := $(patsubst $(BE300_ROOT)/rt/%.c,$(BE300_ROOT)/build/rt/%.o,$(RT_SRCS))
RT_LIB  := $(BE300_ROOT)/build/rt/libbe300rt.a

OBJS := $(patsubst %.c,$(BUILD)/%.o,$(SRCS))
RES  := $(if $(RCS),$(BUILD)/$(APP).res)
EXE  := $(BUILD)/$(APP).exe
CBEA := $(BUILD)/$(APP).cbea
CFIMG := $(BUILD)/$(APP)-cf.img

# The H/PC Pro 3.0 SDK from the eVC ISO is a fallback after the Casio SDK.
SDK_LIBDIRS := $(BE300_ROOT)/sdk/Lib $(wildcard $(BE300_ROOT)/sdk/hpc/Lib)
SDK_INCDIRS := $(BE300_ROOT)/sdk/Include $(wildcard $(BE300_ROOT)/sdk/hpc/Include)

all: $(CBEA)

$(BUILD)/%.o: %.c | $(BUILD)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(RES): $(RCS) | $(BUILD)
	$(RC) $(addprefix /I ,$(SDK_INCDIRS)) /D UNDER_CE=300 /D _WIN32_WCE=300 \
	    /D UNICODE /D _UNICODE /D MIPS /FO $@ $(RCS)

$(EXE): $(OBJS) $(RES) $(RT_LIB)
	$(LD) -o $@ --map $(BUILD)/$(APP).map $(OBJS) $(RT_LIB) \
	    $(addprefix -L ,$(SDK_LIBDIRS)) $(addprefix -l ,$(LIBS)) \
	    $(if $(RES),--res $(RES))

$(CBEA): $(EXE) $(EXTRA_FILES)
	$(MKCBEA) -o $@ --program "$(APP)" --caption "$(CAPTION)" --exe $(EXE) \
	    $(addprefix --file ,$(EXTRA_FILES)) $(CBEA_FLAGS) --setup-ini $(BUILD)/Setup.ini

$(BE300_ROOT)/build/rt/%.o: $(BE300_ROOT)/rt/%.c
	@mkdir -p $(dir $@)
	$(CC) -Os -Wall -c $< -o $@

$(RT_LIB): $(RT_OBJS)
	rm -f $@
	$(AR) rcs --format=gnu $@ $^

$(BUILD):
	mkdir -p $@

$(CFIMG): $(EXE) $(EXTRA_FILES)
	$(MKCF) -s $(CF_SIZE) $@ $(EXE) $(EXTRA_FILES)

cf: $(CFIMG)

run: $(CBEA)
	$(RUNEMU) -o $(BUILD)/nand.run.bin $(CBEA)

cf-run: $(CFIMG)
	$(RUNEMU) -o $(BUILD)/nand.run.bin --cf $(CFIMG)

clean:
	rm -rf $(BUILD)

.PHONY: all cf run cf-run clean
-include $(OBJS:.o=.d)
