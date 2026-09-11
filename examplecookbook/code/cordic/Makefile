# ===========================================================================
#  Makefile for the CORDIC example.
#
#  Targets
#    make lint        Verilator lint of the synthesisable SystemVerilog
#    make vhdl        analyse, elaborate and run the VHDL testbench (QuestaSim)
#    make sv          run the SystemVerilog class testbench (Verilator)
#    make cpp         run the plain C++ testbench (Verilator)
#    make uvmlike     run the UVM-shaped C++ environment (Verilator)
#    make vectors     regenerate the stimulus/expected vectors with Python
#    make cocotb      run the cocotb testsuite
#    make waves       as `sv', with a VCD
#    make all         everything
#    make clean
# ===========================================================================

SHELL      := /bin/bash
ROOT       := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SV_DIR     := $(ROOT)/sv
VHDL_DIR   := $(ROOT)/vhdl
VL_DIR     := $(ROOT)/verilator
PY_DIR     := $(ROOT)/python
VEC_DIR    := $(ROOT)/vectors
BUILD      := $(ROOT)/build

RTL_SV     := $(SV_DIR)/cordic_pkg.sv $(SV_DIR)/cordic_rot.sv
TB_SV      := $(SV_DIR)/cordic_if.sv $(SV_DIR)/tb_cordic_pkg.sv \
              $(SV_DIR)/tb_cordic_top.sv
RTL_VHDL   := $(VHDL_DIR)/cordic_pkg.vhd $(VHDL_DIR)/cordic_rot.vhd
TB_VHDL    := $(VHDL_DIR)/tb_cordic_rot.vhd

N_RANDOM   ?= 300
SEED       ?= 1

VERILATOR  ?= verilator
VCOM       ?= vcom
VSIM       ?= vsim
VLIB       ?= vlib
PYTHON     ?= python3

# Warnings that are switched off on purpose; each one is discussed in the
# book.  A real project keeps this list short and justifies every entry.
VL_WAIVE   := -Wno-CONSTRAINTIGN -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
              -Wno-UNUSEDSIGNAL -Wno-DECLFILENAME

.PHONY: all lint vhdl sv cpp uvmlike bitexact vectors model cocotb cocotb-vhdl cocotb-sv waves clean

#  `all' deliberately leaves out the VHDL and cocotb targets, which need
#  tools that may not be installed.  Run them explicitly.
all: lint sv cpp uvmlike bitexact

# ---------------------------------------------------------------------------
#  Lint.  Run this before anything else, every time.  In SystemVerilog the
#  linter does the job VHDL's type checker does for free.
# ---------------------------------------------------------------------------
lint:
	$(VERILATOR) --lint-only -Wall -Wno-DECLFILENAME $(RTL_SV) \
	             --top-module cordic_rot
	@echo "lint: clean"

# ---------------------------------------------------------------------------
#  VHDL
# ---------------------------------------------------------------------------
#  Needs a VHDL simulator; the commands below are QuestaSim/ModelSim.
vhdl:
	@mkdir -p $(BUILD)/vhdl
	cd $(BUILD)/vhdl && \
	  $(VLIB) work && \
	  $(VCOM) -2008 -quiet $(RTL_VHDL) $(TB_VHDL) && \
	  $(VSIM) -c -gG_N_RANDOM=$(N_RANDOM) \
	          -do "set NumericStdNoWarnings 1; run -all; quit" tb_cordic_rot

# ---------------------------------------------------------------------------
#  SystemVerilog class testbench, run under Verilator.
#
#  Note what is lost: no constraint solver, no covergroups, and the clocking
#  blocks are compiled out (see the shim at the top of tb_cordic_pkg.sv).
#  Under QuestaSim the same sources run with all three.
# ---------------------------------------------------------------------------
sv:
	@mkdir -p $(BUILD)/obj_sv
	$(VERILATOR) --binary --timing -j 0 $(VL_WAIVE) \
	  -Mdir $(BUILD)/obj_sv -o Vtb \
	  $(RTL_SV) $(TB_SV) --top-module tb_cordic_top
	$(BUILD)/obj_sv/Vtb +NRANDOM=$(N_RANDOM) +SEED=$(SEED)

waves:
	@mkdir -p $(BUILD)/obj_wav
	$(VERILATOR) --binary --timing --trace -j 0 $(VL_WAIVE) \
	  -Mdir $(BUILD)/obj_wav -o Vtb \
	  $(RTL_SV) $(TB_SV) --top-module tb_cordic_top
	$(BUILD)/obj_wav/Vtb +NRANDOM=20 +WAVES
	@echo "wrote tb_cordic.vcd"

# ---------------------------------------------------------------------------
#  Plain C++ testbench
# ---------------------------------------------------------------------------
cpp:
	@mkdir -p $(BUILD)/obj_cpp
	$(VERILATOR) --cc --exe --build --trace -j 0 $(VL_WAIVE) \
	  -Mdir $(BUILD)/obj_cpp -o Vcpp \
	  $(RTL_SV) $(VL_DIR)/tb_cordic.cpp --top-module cordic_rot
	$(BUILD)/obj_cpp/Vcpp

# ---------------------------------------------------------------------------
#  UVM-shaped C++ environment
# ---------------------------------------------------------------------------
uvmlike:
	@mkdir -p $(BUILD)/obj_uvm
	$(VERILATOR) --cc --exe --build -j 0 $(VL_WAIVE) \
	  -Mdir $(BUILD)/obj_uvm -o Vuvmlike \
	  -CFLAGS "-I$(VL_DIR) -std=c++17" \
	  $(RTL_SV) $(VL_DIR)/main_uvmlike.cpp --top-module cordic_rot
	$(BUILD)/obj_uvm/Vuvmlike

# ---------------------------------------------------------------------------
#  Bit-exact check against the Python model, using generated vectors
# ---------------------------------------------------------------------------
bitexact: vectors
	@mkdir -p $(BUILD)/obj_vec
	$(VERILATOR) --cc --exe --build -j 0 $(VL_WAIVE) \
	  -Mdir $(BUILD)/obj_vec -o Vvec \
	  -CFLAGS "-I$(VL_DIR) -std=c++17" \
	  $(RTL_SV) $(VL_DIR)/tb_vectors.cpp --top-module cordic_rot
	$(BUILD)/obj_vec/Vvec

# ---------------------------------------------------------------------------
#  Python
# ---------------------------------------------------------------------------
vectors:
	@mkdir -p $(VEC_DIR)
	$(PYTHON) $(PY_DIR)/gen_vectors.py --n $(N_RANDOM) --seed $(SEED) \
	          --out $(VEC_DIR)/cordic_vectors.txt \
	          --header $(VL_DIR)/cordic_vectors.h \
	          --svh $(SV_DIR)/cordic_vectors.svh \
          --rom $(SV_DIR)/cordic_atan_rom.svh

model:
	$(PYTHON) $(PY_DIR)/cordic_model.py

# The same Python testbench, against both implementations.  The SV run needs
# Verilator 5.036 or later (cocotb refuses anything older) or a commercial
# simulator; the VHDL run needs a VHDL simulator.
cocotb: cocotb-vhdl

cocotb-vhdl:
	$(MAKE) -C $(PY_DIR) -f Makefile.cocotb clean
	$(MAKE) -C $(PY_DIR) -f Makefile.cocotb

cocotb-sv:
	$(MAKE) -C $(PY_DIR) -f Makefile.cocotb clean
	$(MAKE) -C $(PY_DIR) -f Makefile.cocotb SV=1

# ---------------------------------------------------------------------------
clean:
	rm -rf $(BUILD) $(PY_DIR)/sim_build $(PY_DIR)/__pycache__ \
	       $(PY_DIR)/results.xml *.vcd
