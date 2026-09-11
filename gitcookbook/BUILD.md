# Building the booklet

    latexmk -pdf main.tex          # recommended
    pdflatex main && pdflatex main # or, by hand (two passes, for the TOC)

Requires a TeX Live installation with `listings`, `tcolorbox`, `tikz`,
`booktabs`, `titlesec`, `import`, `cleveref`, `lmodern` -- the same
requirements as the SystemVerilog cookbook in the sibling `cookbook/`
folder, minus `pgfplots`/`tikz-timing`/`siunitx`, which this booklet does
not use.

## Layout

    main.tex                       the only file you compile
    preamble/packages.tex          every \usepackage lives here
    preamble/listings.tex          code styles (shell sessions, plain output)
    preamble/macros.tex            admonition boxes, page style, headings
    frontmatter/titlepage.tex      title page
    chapters/01-basics/            what Git actually does (theory)
    chapters/02-commands/          everyday commands (cheatsheet style)
    chapters/03-github/            remotes, forks, pull requests, issues
    backmatter/appendix-quickref.tex  one-page command summary

Chapter files load no packages and define no global macros; everything
they use is in `preamble/`. Same conventions as `../cookbook/STYLE.md`:
`\begin{shcode}` for shell/Git commands, `\begin{txtcode}` for plain
output or file contents, and the `gotcha`/`tipbox`/`notebox`/
`ruleofthumb` admonitions.
