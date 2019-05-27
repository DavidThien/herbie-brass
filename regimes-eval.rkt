#lang racket

(require "herbie/src/common.rkt")
(require "herbie/src/alternative.rkt")
(require "herbie/src/mainloop.rkt")
(require "herbie/src/sandbox.rkt")
(require "herbie/src/points.rkt")
(require "herbie/src/formats/test.rkt")

(define (run-test-proc base-test)
  (printf "Now running test: ~a\n" (test-name base-test))
  (printf "Starting program: ~a\n" (test-program base-test))
  (define base-result (get-test-result base-test))
  (if (test-success? base-result)
    (printf "Base regime error improvement: ~a → ~a\n"
            (errors-score (test-success-start-error base-result))
            (errors-score (test-success-end-error base-result)))
    (printf "Base regime test timed out or failed\n"))
  (when (test-success? base-result)
    (define base-result-prog (alt-program (test-success-end-alt base-result)))

    (define expanded-test (struct-copy test base-test
                                       [precondition 'TRUE]
                                       [output (caddr base-result-prog)]))
    (define expanded-result (get-test-result expanded-test))
    (if (test-success? expanded-result)
      (let* ([start-err (errors-score (test-success-start-error expanded-result))]
             [end-err (errors-score (test-success-end-error expanded-result))]
             [target-err (errors-score (test-success-target-error expanded-result))]
             [err-diff (- target-err end-err)])
        (printf "Expanded regime error improvement: ~a → ~a\n"
                 start-err end-err)
        (printf "Base output error: ~a\n" target-err)
        (printf "Herbie improved this expanded regime by ~a bits\n" err-diff))
      (printf "Expanded regime test timed out or failed\n"))))

(define (run-tests bench-dirs)
  (define tests (append-map load-tests bench-dirs))
  (println (car tests))
  (println "test")
  (define seed (get-seed))

  (printf "Running ~a tests (seed: ~a)\n" (length tests) seed)

  (for ([test tests])
    (run-test-proc test)))

(module+ main
  (define seed (random 1 (expt 2 31)))
  (set-seed! seed)
  (command-line
    #:program "regimes-eval.rkt"
    #:once-each
    [("--seed") rs "The random seed to use in point generation. If false (#f), a random seed is used'"
     (define given-seed (read (open-input-string rs)))
     (when given-seed (set-seed! given-seed))]
    #:args bench-dirs
    (exit (if (run-tests bench-dirs) 0 1))))
