.PHONY: setup run clean test

threads=1
posits=y

setup:
	raco pkg install --skip-installed softposit-rkt
	raco make brass-eval.rkt

run:
	@echo Running Herbie BRASS evaluation
ifeq ($(posits), n)
	racket brass-eval.rkt --no-posits --threads $(threads) herbie/bench > brass-output.txt
else
	racket brass-eval.rkt --threads $(threads) herbie/bench > brass-output.txt
endif

test:
	@echo Testing Herbie BRASS evaluation install \(should output a single table\)
	@racket brass-eval.rkt test.fpcore && echo "Posits work on your machine" || echo "Posits don't work on your machine. you can disable them with \"posits=n\" when you run \"make run\""

clean:
	raco pkg remove softposit-rkt
	rm brass-output.txt
	rm -rf compiled
