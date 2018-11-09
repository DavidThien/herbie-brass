.PHONY: install run clean

threads=1

install:
	raco pkg install --skip-installed softposit-rkt

run:
	echo Running Herbie BRASS evaluation
	racket brass-eval.rkt --threads $(threads) herbie/bench > brass-output.txt

clean:
	raco pkg remove softposit-rkt
	rm brass-output.txt
