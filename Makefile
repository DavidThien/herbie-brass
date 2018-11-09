.PHONY: install run clean

threads=1

install:
	raco pkg install --skip-installed softposit-rkt

run:
	@echo Running Herbie BRASS evaluation
	racket brass-eval.rkt --threads $(threads) herbie/bench > brass-output.txt

test:
	@echo Testing Herbie BRASS evaluation install \(should output a single table\)
	racket brass-eval.rkt test.fpcore

clean:
	raco pkg remove softposit-rkt
	rm brass-output.txt

