.PHONY: install

install:
	raco pkg install softposit-rkt
	git clone git@github.com:uwplse/herbie.git
	git clone git@github.com:FPBench/FPBench.git
