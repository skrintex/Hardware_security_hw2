# Filename: Makefile
#
# Copyright (c) 2013, Intel Corporation
# All rights reserved

.PHONY: help
help:
	@printf "Usage: make [PARAM=VALUE] ... target\n"
	@printf "\n"
	@printf "Valid parameters:\n"
	@printf "    NUM_BLOCKS - Number of AES blocks (default: 1)\n"
	@printf "    NUM_VECS   - Number of test vectors per instance (default: 1000)\n"
	@printf "\n"
	@printf "Miscellaneous targets:\n"
	@printf "    help          - Display this help message\n"
	@printf "    clean         - Clean intermediate files\n"
	@printf "\n"
	@printf "Verilator targets (open-source, use these on a local machine):\n"
	@printf "    verilator-sim           - Compile and simulate with Verilator\n"
	@printf "    verilator-openssl-check - Simulate then cross-check against OpenSSL\n"
	@printf "\n"
	@printf "Cadence Incisive targets:\n"
	@printf "    inca-elab          - Elaborate the design\n"
	@printf "    inca-tgz           - Build gzipped tarball\n"
	@printf "    inca-sim           - Simulate the design\n"
	@printf "    inca-gui           - Debug with the SimVision GUI\n"
	@printf "    inca-openssl-check - Simulate then cross-check outputs against OpenSSL\n"
	@printf "\n"
	@printf "Synopsys VCS targets:\n"
	@printf "    vcs-elab           - Elaborate the design\n"
	@printf "    vcs-tgz            - Build gzipped tarball\n"
	@printf "    vcs-sim            - Simulate the design\n"
	@printf "    vcs-gui            - Debug with VCS GUI\n"
	@printf "    openssl-check      - Simulate then cross-check outputs against OpenSSL\n"

.PHONY: clean
clean:
	rm -rf .simvision INCA_libs* waves.shm obj_dir
	rm -f irun.*.log irun.key
	rm -f params.sv params.sv.in
	rm -f vectors_Nk4.txt vectors_Nk6.txt vectors_Nk8.txt
	rm -f vcs.openssl.log irun.openssl.log verilator.log

# Unconditional target
FORCE:

VLOG_INC_FILES := include/flops.svh include/aes.svh

VLOG_HDL_FILES := \	
	hdl/aes128.sv \
	hdl/noise_gen.sv \
    hdl/aes_key_expand.sv \
    hdl/aes_cipher.sv \
    hdl/aes_inv_cipher.sv \
    hdl/aes_encrypt.sv \
    hdl/aes_decrypt.sv

VLOG_HVL_FILES := \
    hvl/aes_dpi_pkg.sv \
    hvl/clk_gen.sv \
    hvl/aes_ec_tb.sv \
    hvl/aes_tb.sv

C_FILES := hvl/aes.c hvl/aes_dpi.c
C_INC_FILES := include/aes.h

SRC := \
    $(VLOG_INC_FILES) \
    $(VLOG_HDL_FILES) \
    $(VLOG_HVL_FILES) \
    $(C_INC_FILES) \
    $(C_FILES)

# Parameterization
NUM_BLOCKS := 1
NUM_VECS   := 1000

PYTHON3       := python3
OPENSSL_CHECK := openssl_check.py

params.sv.in: FORCE
	@printf "parameter NUM_BLOCKS = $(NUM_BLOCKS);\n" > $@

params.sv: params.sv.in
	@(test ! -f params.sv || ! diff params.sv params.sv.in > /dev/null) && cp -f $< $@ || true

# -----------------------------------------------------------------------------
# Verilator targets  (Verilator 5.x, open-source)
# -----------------------------------------------------------------------------
VERILATOR       := verilator
VERILATOR_FLAGS := \
    --sv \
    --cc \
    --assert \
    --timing \
    -CFLAGS "-Iinclude -I../include" \
    +incdir+include \
    --top-module aes_tb \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    -Wno-UNOPTFLAT \
    -Wno-INITIALDLY \
    -Wno-REDEFMACRO \
    -Wno-MULTIDRIVEN \
    -Wno-ALWCOMBORDER

VERILATOR_SIM := obj_dir/Vaes_tb
SIM_MAIN      := sim_main.cpp

$(VERILATOR_SIM): $(SRC) params.sv $(SIM_MAIN)
	@printf "\n>>> Verilating ...\n"
	$(VERILATOR) $(VERILATOR_FLAGS) \
	    $(VLOG_HDL_FILES) $(VLOG_HVL_FILES) \
	    2>&1 | tee verilator.log
	@printf "\n>>> Building simulation binary ...\n"
	@# Build everything EXCEPT the final link (which has wrong .o ordering)
	$(MAKE) -C obj_dir -f Vaes_tb.mk Vaes_tb__ALL.a 2>&1 | tee -a verilator.log
	@# Compile global runtime objects (verilated.o etc.)
	$(MAKE) -C obj_dir -f Vaes_tb.mk verilated.o verilated_dpi.o verilated_timing.o verilated_threads.o 2>&1 | tee -a verilator.log
	@# Compile user files
	cd obj_dir && gcc -I. -I/usr/share/verilator/include -I/usr/share/verilator/include/vltstd \
	    -Iinclude -I../include -Os -c -o aes.o ../hvl/aes.c 2>&1 | tee -a ../verilator.log
	cd obj_dir && gcc -I. -I/usr/share/verilator/include -I/usr/share/verilator/include/vltstd \
	    -Iinclude -I../include -Os -c -o aes_dpi.o ../hvl/aes_dpi.c 2>&1 | tee -a ../verilator.log
	cd obj_dir && g++ -I. -I/usr/share/verilator/include -I/usr/share/verilator/include/vltstd \
	    -Iinclude -I../include -fcoroutines -Os -c -o sim_main.o ../$(SIM_MAIN) 2>&1 | tee -a ../verilator.log
	@# Final link: --start-group wraps archive so DPI symbols resolve correctly
	cd obj_dir && g++ -Os \
	    sim_main.o aes.o aes_dpi.o \
	    verilated.o verilated_dpi.o verilated_timing.o verilated_threads.o \
	    -Wl,--start-group Vaes_tb__ALL.a -Wl,--end-group \
	    -pthread -lpthread -latomic \
	    -o Vaes_tb 2>&1 | tee -a ../verilator.log

.PHONY: verilator-elab
verilator-elab: $(VERILATOR_SIM)

.PHONY: verilator-sim
verilator-sim: $(VERILATOR_SIM)
	@printf "\n>>> Running Verilator simulation ...\n"
	$(VERILATOR_SIM) +NUM_VECS=$(NUM_VECS)

.PHONY: verilator-openssl-check
verilator-openssl-check: $(VERILATOR_SIM)
	@printf "\n>>> Running simulation to dump AES vectors ...\n"
	$(VERILATOR_SIM) +NUM_VECS=$(NUM_VECS) 2>&1 | tee verilator.log
	@printf "\n>>> Cross-checking simulation output against OpenSSL ...\n"
	$(PYTHON3) $(OPENSSL_CHECK) --dir .
	@printf "\n>>> OpenSSL cross-check complete.\n"

# -----------------------------------------------------------------------------
# Cadence Incisive Enterprise targets
# -----------------------------------------------------------------------------
export INCA_64BIT := true

IRUN            := irun
IRUN_ELAB_FLAGS := -access +rwc -incdir include -cflags '-Iinclude'
IRUN_ELAB_FILES := $(VLOG_HDL_FILES) $(VLOG_HVL_FILES) $(C_FILES)
IRUN_SIM_FLAGS  := -nowarn WSEM2009
IRUN_SIM_CMD    := irun-sim.cmd

INCA_libs: $(SRC) params.sv
	$(IRUN) -elaborate -l irun.elab.log $(IRUN_ELAB_FLAGS) $(IRUN_ELAB_FILES)

INCA_libs.tar.gz: INCA_libs
	@printf "INCA_64BIT=true $(IRUN) -R -l irun.sim.log +NUM_VECS=$(NUM_VECS) $(IRUN_SIM_FLAGS)\n" > $(IRUN_SIM_CMD)
	@chmod +x $(IRUN_SIM_CMD)
	tar -czf $@ $^ $(IRUN_SIM_CMD)
	@rm -f $(IRUN_SIM_CMD)

.PHONY: inca-elab
inca-elab: INCA_libs

.PHONY: inca-tgz
inca-tgz: INCA_libs.tar.gz

.PHONY: inca-sim
inca-sim: INCA_libs
	$(IRUN) -R -l irun.sim.log +NUM_VECS=$(NUM_VECS) $(IRUN_SIM_FLAGS)

.PHONY: inca-gui
inca-gui: INCA_libs
	$(IRUN) -R -l irun.sim.log -gui $(IRUN_SIM_FLAGS)

.PHONY: inca-openssl-check
inca-openssl-check: INCA_libs
	@printf "\n>>> Running simulation to dump AES vectors ...\n"
	$(IRUN) -R -l irun.openssl.log +NUM_VECS=$(NUM_VECS) $(IRUN_SIM_FLAGS)
	@printf "\n>>> Cross-checking simulation output against OpenSSL ...\n"
	$(PYTHON3) $(OPENSSL_CHECK) --dir .
	@printf "\n>>> OpenSSL cross-check complete.\n"

# -----------------------------------------------------------------------------
# Synopsys VCS targets
# -----------------------------------------------------------------------------
VCS            := vcs
VCS_ELAB_FLAGS := -debug_access+r -sverilog +incdir+include -cflags '-I../include'
VCS_ELAB_FILES := $(VLOG_HDL_FILES) $(VLOG_HVL_FILES) $(C_FILES)
VCS_SIM_FLAGS  :=
VCS_SIM_CMD    := vcs-sim.cmd

simv simv.daidir: $(SRC) params.sv
	$(VCS) -full64 -l vcs.elab.log $(VCS_ELAB_FLAGS) $(VCS_ELAB_FILES)

simv.tar.gz: simv simv.daidir
	@printf "./simv -l vcs.sim.log +NUM_VECS=$(NUM_VECS) $(VCS_SIM_FLAGS)\n" > $(VCS_SIM_CMD)
	@chmod +x $(VCS_SIM_CMD)
	tar -czf $@ $^ $(VCS_SIM_CMD)
	@rm -f $(VCS_SIM_CMD)

.PHONY: vcs-elab
vcs-elab: simv

.PHONY: vcs-tgz
vcs-tgz: simv.tar.gz

.PHONY: vcs-sim
vcs-sim: simv
	./simv -l vcs.sim.log +NUM_VECS=$(NUM_VECS) $(VCS_SIM_FLAGS)

.PHONY: vcs-gui
vcs-gui: simv
	./simv -l vcs.sim.log -gui $(VCS_SIM_FLAGS)

.PHONY: openssl-check
openssl-check: simv
	@printf "\n>>> Running simulation to dump AES vectors ...\n"
	./simv -l vcs.openssl.log +NUM_VECS=$(NUM_VECS) $(VCS_SIM_FLAGS)
	@printf "\n>>> Cross-checking simulation output against OpenSSL ...\n"
	$(PYTHON3) $(OPENSSL_CHECK) --dir .
	@printf "\n>>> OpenSSL cross-check complete.\n"
