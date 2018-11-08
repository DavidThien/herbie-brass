.PHONY: install run clean

install:
	raco pkg install softposit-rkt

run:
	racket brass-eval.rkt herbie/bench

clean:
