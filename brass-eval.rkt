#lang racket

(require racket/date)
(require racket/cmdline)
(require "config.rkt")
(require "common.rkt")
(require "points.rkt")
(require "alternative.rkt")
(require "sandbox.rkt")
(require "formats/test.rkt")
(require "formats/datafile.rkt")

(define (run-tests . bench-dirs)
  (define tests (append-map load-tests bench-dirs))
  (define seed (get-seed))
  (printf "Running Herbie on ~a tests (seed: ~a)...\n" (length tests) seed)
  (define (make-test-list)
    (for/list ([test tests])
      (get-test-result test)))
  (printf "Running in double precision.\n")
  (enable-flag! 'precision 'double)
  (define double-precision-results (make-test-list))
  (printf "Running in single precision.\n")
  (disable-flag! 'precision 'double)
  (define single-precision-results (make-test-list))
  (println double-precision-results)
  (println single-precision-results)
  (printf "Single Start | Single End | Double Start | Double End")
  (for/list ([double-test double-precision-results]
             [single-test single-precision-results])
    (if (and (test-result? double-test) (test-result? single-test))
      (printf "Test failed or timed out.\n")
      (let ([double-start-error (test-result-start-error double-test)]
            [single-start-error (test-result-start-error single-test)]
            [double-end-error (test-result-end-error double-test)]
            [single-end-error (test-result-end-error single-test)])
        (printf "~a | ~a | ~a | ~a\n" single-start-error single-end-error
                double-start-error double-end-error)))))

(module+ main
  (define seed (random 1 (expt 2 31)))
  (set-seed! seed)
  (command-line
   #:program "travis.rkt"
   #:once-each
   [("--seed") rs "The random seed to use in point generation. If false (#f), a random seed is used'"
    (define given-seed (read (open-input-string rs)))
    (when given-seed (set-seed! given-seed))]
   #:args bench-dir
   (exit (if (apply run-tests bench-dir) 0 1))))
