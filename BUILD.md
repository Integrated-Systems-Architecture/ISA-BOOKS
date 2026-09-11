# The lab booklet series

Six self-contained LaTeX booklets, each built independently:

    designcookbook/         SystemVerilog for VHDL Designers -- Design
    verificationcookbook/   SystemVerilog for VHDL Designers -- Verification
    simulationcookbook/     SystemVerilog for VHDL Designers -- Simulation
    examplecookbook/        SystemVerilog for VHDL Designers -- Example (CORDIC)
    gitcookbook/            Git & GitHub -- A Quick Reference Manual
    fusesoccookbook/        FuseSoC, Vendoring, Makefiles & Regtool -- A Quick Reference Manual

The first four used to be a single book; it was split into companion
booklets so each can be handed out, updated and rebuilt on its own. They
share one template.

## Building any of them

    cd <booklet>/
    latexmk -pdf main.tex          # recommended
    pdflatex main && makeindex main && pdflatex main && pdflatex main

Requires a TeX Live installation with `listings`, `tcolorbox`, `tikz`,
`pgfplots`, `tikz-timing`, `booktabs`, `titlesec`, `import`, `cleveref`,
`siunitx`, `lmodern`. On Debian/Ubuntu:

    sudo apt install texlive-latex-recommended texlive-latex-extra \
                     texlive-fonts-extra texlive-science texlive-pictures \
                     latexmk lmodern

`gitcookbook` and `fusesoccookbook` need a smaller subset (no `pgfplots`,
`tikz-timing`, `siunitx`, no index); see each one's own `BUILD.md`.

## The shared templates

    _shared/preamble/packages.tex   every \usepackage, for all four SV booklets
    _shared/preamble/listings.tex   code styles, the rosetta side-by-side boxes
    _shared/preamble/macros.tex     admonition boxes, page style, headings,
                                     and the cross-booklet reference macros
                                     (\refdesignbook, \refverificationbook,
                                     \refsimulationbook, \refexamplebook, and
                                     their capitalised \Ref... forms)
    _shared/STYLE.md                 the author guide the chapters were written to

    _shared/preamble_lite/packages.tex   every \usepackage, for the two short
                                          reference booklets below
    _shared/preamble_lite/listings.tex   code styles: shell, Makefile,
                                          .core/.hjson, plain output
    _shared/preamble_lite/macros.tex     admonition boxes, page style, headings

`gitcookbook` and `fusesoccookbook` are not part of the first template:
they are short, single-topic reference manuals, not chapters of the
SV-for-VHDL-Designers book, so they don't need `pgfplots`, UVM syntax
highlighting or the VHDL/SV rosetta boxes. They share a second, lighter
template instead -- `_shared/preamble_lite/` -- since their own package,
listings and macro needs are identical.

Each booklet's `main.tex` loads its shared preamble with
`\input{../_shared/preamble/...}` or `\input{../_shared/preamble_lite/...}`;
nothing chapter-local overrides it. A style change is made once in the
relevant `_shared/` folder and takes effect in every booklet that shares
it the next time each is rebuilt.

## Layout inside each of the four SV booklets

    main.tex                    the only file you compile
    frontmatter/                title page, preface, how-to-read
    chapters/NN-key/chapter.tex one folder per chapter, with its own figures/
    backmatter/                 appendices, bibliography
    .gitignore                  LaTeX (and, for examplecookbook, CORDIC) build products

`examplecookbook/code/cordic/` additionally holds the worked example's
sources (VHDL, SystemVerilog, C++, Python) -- see its own `README.md`.

## Cross-references between booklets

Chapter files load no packages and define no booklet-local macros;
everything they use is in `_shared/preamble/`. A `\cref{...}` to a chapter,
section, listing, figure or table that still lives in the *same* booklet
resolves normally. A reference to material that moved into a *different*
booklet was rewritten, when the booklets were split, to one of the
`\refdesignbook` / `\refverificationbook` / `\refsimulationbook` /
`\refexamplebook` macros (capitalised forms `\Refdesignbook` etc. for
sentence-initial use) instead of a page number, since cleveref cannot
number a page in another PDF. When adding a *new* cross-booklet mention,
use these macros directly rather than `\cref`.

## History

This series began as a single book (`cookbook/`, no longer present) that
covered design, verification, simulation and one worked example together.
It was split into four booklets so each could be scoped, handed out and
rebuilt independently, then joined by `gitcookbook` and `fusesoccookbook`:
short reference manuals for the tooling the labs assume (Git/GitHub, and
FuseSoC/vendoring/Makefiles/regtool) rather than chapters of the same
book. Those two later shared their own preamble too, once it became clear
they needed the identical small set of packages, code-listing styles and
admonition macros -- `_shared/preamble_lite/`.
