all: main.pdf

main.pdf: abstract.scrbl design.scrbl conclusion.scrbl examples.scrbl implementation.scrbl intro.scrbl main.scrbl related.scrbl defs.rkt bib.rkt
	scribble --pdf main.scrbl

