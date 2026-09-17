# ===========================================================================
#  Builds every booklet and copies its PDF to this folder under the title
#  printed on its title page.
#
#    make            build all six, copy the PDFs here
#    make gitcookbook    build one booklet only
#    make clean      remove the LaTeX aux files, keep the PDFs
#    make distclean  also remove the copies here and each booklet's main.pdf
# ===========================================================================

BOOKS := designcookbook verificationcookbook simulationcookbook \
         examplecookbook gitcookbook fusesoccookbook

# The name each booklet's PDF is copied out as.
NAME_designcookbook       := The Design Cookbook
NAME_verificationcookbook := The Verification Cookbook
NAME_simulationcookbook   := The Simulation Cookbook
NAME_examplecookbook      := The Example Cookbook
NAME_gitcookbook          := Git & GitHub Cookbook
NAME_fusesoccookbook      := FuseSoC, Vendoring, Makefiles & Regtool

LATEXMK ?= latexmk
LATEXMKFLAGS ?= -pdf -interaction=nonstopmode -halt-on-error

.PHONY: all clean distclean $(BOOKS)

all: $(BOOKS)

# `-cd' makes latexmk run in the booklet's own folder, so the aux files and
# the \input{../_shared/...} paths resolve the way they do by hand.
$(BOOKS):
	$(LATEXMK) $(LATEXMKFLAGS) -cd $@/main.tex
	cp $@/main.pdf "$(NAME_$@).pdf"

clean:
	for b in $(BOOKS); do $(LATEXMK) -c -cd $$b/main.tex; done

distclean:
	for b in $(BOOKS); do $(LATEXMK) -C -cd $$b/main.tex; done
	for b in $(BOOKS); do rm -f "$(NAME_$$b).pdf"; done
