# ISA Lab Booklets

LaTeX sources for the booklet series handed out with the Integrated Systems
Architecture labs. Six self-contained booklets, each built on its own:

| Booklet | Title |
| --- | --- |
| `designcookbook/` | SystemVerilog for VHDL Designers — Design |
| `verificationcookbook/` | SystemVerilog for VHDL Designers — Verification |
| `simulationcookbook/` | SystemVerilog for VHDL Designers — Simulation |
| `examplecookbook/` | SystemVerilog for VHDL Designers — Example (CORDIC) |
| `gitcookbook/` | Git & GitHub — A Quick Reference Manual |
| `fusesoccookbook/` | FuseSoC, Vendoring, Makefiles & Regtool — A Quick Reference Manual |

A prebuilt `main.pdf` is committed in each folder, so readers do not need a TeX
installation.

## Building

```sh
cd <booklet>/
latexmk -pdf main.tex
```

See [`BUILD.md`](BUILD.md) for the required TeX packages, the shared preamble
templates under `_shared/`, the layout inside each booklet, and the rules for
cross-references between booklets. Authors should also read
[`_shared/STYLE.md`](_shared/STYLE.md).

## The CORDIC example

`examplecookbook/code/cordic/` holds the worked example's sources (VHDL,
SystemVerilog, C++, Python) and a `Makefile` that runs every testbench the
booklet discusses. Run it from that folder:

| Target | What it does |
| --- | --- |
| `make lint` | Verilator lint of the synthesisable SystemVerilog. Run it first, every time. |
| `make sv` | SystemVerilog class testbench under Verilator |
| `make cpp` | plain C++ testbench under Verilator |
| `make uvmlike` | UVM-shaped C++ environment under Verilator |
| `make bitexact` | Verilator run checked against the Python model, on generated vectors |
| `make vhdl` | VHDL testbench under QuestaSim/ModelSim |
| `make cocotb` | cocotb testsuite (VHDL); `make cocotb-sv` for the SystemVerilog one |
| `make vectors` | regenerate the stimulus and expected vectors with Python |
| `make model` | run the Python reference model on its own |
| `make waves` | as `make sv`, with a VCD |
| `make all` | `lint sv cpp uvmlike bitexact` |
| `make clean` | remove `build/`, cocotb output and VCDs |

`make all` leaves out `vhdl` and `cocotb` on purpose: they need tools that may
not be installed. Run those explicitly.

Knobs, all overridable on the command line: `N_RANDOM` (random vectors,
default 300), `SEED` (default 1), and the tool names `VERILATOR`, `VCOM`,
`VSIM`, `VLIB`, `PYTHON`. For example:

```sh
make sv N_RANDOM=5000 SEED=7
```

Everything is built under `build/`, which is gitignored. See
`examplecookbook/code/cordic/README.md` for what each source file is.
