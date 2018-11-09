# Herbie BRASS Evaluation

This is version 1.0 of the Herbie BRASS evaluation code.

## Dependencies
* git
* racket
* make

## Installation instructions
Install [racket](https://download.racket-lang.org/), then run
```
make setup
```
This will install the racket `softposit-rkt` package and build the racket files. You can test the installation with
```
make test
```
which will output the result of a single test to stdout and indicate if posits work on your machine. Note that posits are an experimental new format not built by the Herbie team, so support across different machines is inconistent. If posits don't work on your machine, `make test` will indicate that to you and you can then disable posits by passing in `posits=n` to `make run`. You can run the full evaluation with
```
make run
```
which will create the output file `brass-output.txt` with the results of the test. You can make the eval use more threads with
```
make run threads=n
```
where `n` is the number of threads to use. The script defaults to 1

## Description

This brass evaluation script will run Herbie on its suite of benchmarks, once for each currently supported precision (`double`, `float`, and `posit16`). More information on posits can be found at [posithub](http://posithub.org/). The script will take the output of each Herbie run, as well as the starting program, and calculate the error of running that program in each precision. That is, the output of Herbie's run in double precision will be tested in `double`, `single`, and `posit16` precisions. The error is displayed as average bits of error with lower error being better. Note that Herbie will occasionally time out on intractable tests (e.g. tests where sampling points is impossible, or where establishing the correct value of a calculation would be prohibitively expensive) or error on test that cannot be run (posit16 is an in-development numerical representation, so not all operators used in the benchmarks are supported). Tests that time out or cannot be run will be displayed as `#f` on the table.

The output of the script (for a single test) will look something like the following:

```
Now running test: cos2 (problem 3.4.1)
Starting program: (λ (x) (/ (- 1 (cos x)) (* x x)))
Precision double result: (λ (x) (if (or (<= x -0.0015201712728501085) (not (<= x 5.4768267791406294e-14))) (* (tan (/ x 2)) (/ (sin x) (* x x))) (- (+ (* 1/720 (pow x 4)) 1/2) (* 1/24 (pow x 2)))))
Precision single result: (λ (x) (exp (- (log 1/2) (+ (* (pow x 4) 1/1440) (* 1/12 (pow x 2))))))
Precision posit16 timed out or failed
|       |start prog|double|single|posit16|
|double |31.2135576|0.4414|15.009|#f     |
|single |29.0321010|14.317|0.8522|#f     |
|posit16|#f        |#f    |#f    |#f     |
```

The first line displays the name of the test, followed by the starting program. This starting program is the input program to Herbie run on each precision. The next two lines display Herbie's result running on double and single precision. You can see here that Herbie came up with different programs for single and double precisions, including branch condition for the double precision result. All runs on `posit16` precision for this test are labelled `#f` because `cos` is currently an unsupported operator.

The table displays the average bits error of running each program in each precision. Each column represnts a fixed program, and each row represents a fixed precision. So the first column, first row in the table (with value `31.213`) is the result of running the starting program (`(λ (x) (/ (- 1 (cos x)) (* x x)))`) in double precision. There are a few things to note on this table, first Herbie was able to improve the same program running in both single and double precisionto less than a bit of error. Second, running Herbie's single precision result in double precision gives more error than the double precision result, and vice versa for single precision. Lastly, for this example, all columns or rows with `posit16` are marked `#f` because each program that it would run has an unspported operation in it.

Note that if posists are disabled, then the `posit16` columns and rows will not be printed.
