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

## Use as a submodule

This repository is vendored into the lab repository
[`ISA-LAB`](https://github.com/Integrated-Systems-Architecture/ISA-LAB) as the
`books/` submodule:

```sh
git clone --recurse-submodules https://github.com/Integrated-Systems-Architecture/ISA-LAB.git
# already cloned:
git submodule update --init books
```

Commit changes here first, push, then update the gitlink in `ISA-LAB`.
