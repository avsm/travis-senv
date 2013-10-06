_build/main.native: *.ml
	ocamlbuild -use-ocamlfind -pkg cmdliner main.native

clean:
	rm -rf _build main.native
