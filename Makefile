PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

_build/main.native: *.ml
	ocamlbuild -use-ocamlfind -pkg cmdliner main.native

.PHONY: install clean

install:
	mkdir -p $(BINDIR)
	cp main.native $(BINDIR)/travis-senv

clean:
	rm -rf _build main.native
