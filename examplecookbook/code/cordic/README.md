# The CORDIC example

The worked example of Chapter 10. The same rotator, implemented twice and
verified six ways.

    make lint        Verilator lint of the synthesisable SystemVerilog
    make vhdl        VHDL RTL + VHDL testbench (needs a VHDL simulator)
    make sv          SystemVerilog RTL + class testbench, under Verilator
    make cpp         SystemVerilog RTL + plain C++ testbench
    make uvmlike     SystemVerilog RTL + the UVM-shaped C++ environment
    make bitexact    bit-exact check against the Python model
    make cocotb      VHDL RTL + the cocotb testbench
    make cocotb-sv   SystemVerilog RTL + the same cocotb testbench
                     (needs Verilator >= 5.036, or a commercial simulator)
    make vectors     regenerate the vectors and the generated headers
    make all         lint + everything that needs only free tools
    make clean

## Layout

    sv/         synthesisable SystemVerilog, the interface, the class testbench
    vhdl/       synthesisable VHDL and the VHDL testbench
    verilator/  C++ testbenches and the svtlm.h mini-framework
    python/     the golden model, the vector generator, the cocotb tests
    vectors/    generated, safe to delete

## What checks what

| Testbench            | Language | Simulator  | Reference          | Check      |
|----------------------|----------|------------|--------------------|------------|
| `tb_cordic_rot.vhd`  | VHDL     | QuestaSim  | `ieee.math_real`   | tolerance  |
| `tb_cordic_top.sv`   | SV       | Verilator  | `$sin`/`$cos`      | tolerance  |
| `tb_cordic.cpp`      | C++      | Verilator  | `<cmath>`          | tolerance  |
| `main_uvmlike.cpp`   | C++      | Verilator  | `<cmath>`          | tolerance  |
| `tb_vectors.cpp`     | C++      | Verilator  | `cordic_model.py`  | bit-exact  |
| `test_cordic.py`     | Python   | any        | `cordic_model.py`  | bit-exact  |

The last two rows are what tie the two implementations together: the
SystemVerilog and the VHDL are each checked bit for bit against the same
Python model, so they are known to agree with each other.

## Requirements

Verilator 5.0+, Python 3.8+ and a C++17 compiler for the SystemVerilog side;
cocotb 1.7+ for the Python testbench. Those need no licence. The two VHDL
targets need a VHDL simulator: the command lines in the Makefile are
QuestaSim/ModelSim, and any IEEE 1076-2008 simulator will run the sources.
