# Herbie BRASS Evaluation

This is version 1.0 of the Herbie BRASS evaluation code.

## Dependencies

* racket
* git
* make
* tee
* gcc
* libmpfr-dev

Note that these dependencies must be installed before running `make setup`. All packages except racket can be installed through the apt repositories, although some may be automatically installed on your system. To install them, simply run

```
sudo apt update
sudo apt install package
```

where `package` is the package you want to install. Note that `make setup` assumes you have all the aforementioned dependencies installed, so make sure you install those before running the setup command.

If you want to include posits in the evaluation, then this script must be run on Linux because the posit library is only available on Linux.

## Installation instructions

Install [racket](https://download.racket-lang.org/), then run
```
make setup
```
This will install the racket `softposit-rkt` package and build the racket files. You can test the installation with
```
make test
```
which will output the result of a single test to stdout and indicate if posits work on your machine. This test is expected to take a couple minutes using about half a GB of RAM and one CPU core while it runs. Note that posits are an experimental new format not built by the Herbie team, so support across different machines is inconsistent. If posits don't work on your machine, `make test` will indicate that to you and you can then disable posits by passing in `posits=disable` to `make run`.

Although there should be no problems with the setup, there is an old bug in MPFR that may pop up depending on the version from the apt repository you are using. If you run into any problems, then then follow the instructions at the end of the document to manually install MPFR.

## Running the Eval

You can run the full evaluation with
```
make run
```
which will create the output file `brass-output.txt` with the results of the test. It will also display the results to stdout. You can make the eval use more threads with
```
make run threads=n
```
where `n` is the number of threads to use. The script defaults to 1. Note that this command will take several hours to run, but will produce intermediate output once each test completes. Each test will take a few minutes to run.

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

The table displays the average bits error of running each program in each precision. Each column represents a fixed program, and each row represents a fixed precision. So the first column, first row in the table (with value `31.213`) is the result of running the starting program (`(λ (x) (/ (- 1 (cos x)) (* x x)))`) in double precision. There are a few things to note on this table, first Herbie was able to improve the same program running in both single and double precision to less than a bit of error. Second, running Herbie's single precision result in double precision gives more error than the double precision result, and vice versa for single precision. Lastly, for this example, all columns or rows with `posit16` are marked `#f` because each program that it would run has an unsupported operation in it.

Note that if posits are disabled, then the `posit16` columns and rows will not be printed.

## Manually Installing MPFR

NOTE: only use these directions if MPFR was unable to be installed correctly. These instructions also depend on the previous dependencies being installed.

1. To manually install MPFR, you must also install M4, curl, and patch, which can be installed by running
```
sudo apt update
sudo apt install m4
sudo apt install patch
sudo apt install curl
```

2. MPFR depends on GMP, so first download the tarball from the [GMP website](https://gmplib.org/#DOWNLOAD) and extract it into its own directory.

3. Inside the GMP directory, run
```
./configure
make
make check
```
Although running `make test` did not produce any errors on any of the systems that were tested, the GMP installation instructions specifically mention that there is an unfortunately high chance of failure. If this happens, contact the Herbie team, and we will walk through what errors you are getting.

4. You can then install GMP by running
```
sudo make install
```
which will install GMP to `/usr/local`.

5. A this point, we are ready to start the MPFR installation itself. Download the MPFR tarball from the [MPFR website](https://www.mpfr.org/mpfr-4.0.2/#download) and unzip it into its own directory.

6. Any patches that have come out since the latest release can be downloaded and patched by running
```
curl https://www.mpfr.org/mpfr-4.0.2/allpatches | patch -N -Z -p1
```
in the extracted MPFR directory. As of the time of writing, no patches exist, so you should get the notification `Only garbage was found in the patch input.`

7. Compile MPFR with
```
./configure
make
make check
```
Again, the `make check` command is just a sanity check. If any errors arise, contact the Herbie team for help walking through the errors.

8. MPFR can then be installed with
```
sudo make install
```

9. You can check that everything was installed correctly by running `make test` in the `brass-eval` directory.
