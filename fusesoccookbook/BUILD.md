# Building the booklet

    latexmk -pdf main.tex          # recommended
    pdflatex main && pdflatex main # or, by hand (two passes, for the TOC)

Requires a TeX Live installation with `listings`, `tcolorbox`, `tikz`,
`booktabs`, `titlesec`, `import`, `cleveref`, `lmodern` -- the same small
subset gitcookbook needs (no `pgfplots`, `tikz-timing`, `siunitx`, no index).

## Layout

    main.tex                          the only file you compile
    ../_shared/preamble_lite/packages.tex   every \usepackage lives here (shared with gitcookbook)
    ../_shared/preamble_lite/listings.tex   code styles: shell, Makefile, .core/.hjson, plain output
    ../_shared/preamble_lite/macros.tex     admonition boxes, page style, headings
    frontmatter/titlepage.tex         title page
    chapters/01-fusesoc/              .core files: filesets, targets, dependencies
    chapters/02-vendoring/            .vendor.hjson, util/vendor.py, lock files
    chapters/03-makefiles/            the two Makefile shapes used across the labs
    chapters/04-regtool/              register_interface + the regtool/reggen flow
    backmatter/appendix-quickref.tex  one-page command + field reference

Chapter files load no packages and define no global macros; everything they
use is in `../_shared/preamble_lite/`, shared with gitcookbook (see
`books/BUILD.md`). Same conventions as the rest of the series:
`\begin{shcode}` for shell/fusesoc/make commands, `\begin{makecode}` for
Makefile excerpts, `\begin{corecode}` for `.core`/`.hjson` excerpts,
`\begin{txtcode}` for plain output, and the
`gotcha`/`tipbox`/`notebox`/`ruleofthumb` admonitions.

## Scope, on purpose

This booklet only explains what a student needs to read the `.core` files,
Makefiles and register descriptions already in `lab0/` and `lab1/`, and to
write new ones of their own. It is not a FuseSoC, GNU Make or regtool
manual: for anything past this scope, point at `fusesoc.readthedocs.io`,
the GNU Make manual and the OpenTitan regtool docs, same as the booklet's
own back-cover blurb says.
