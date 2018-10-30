#lang racket

(require racket/date)
(require racket/cmdline)
(require "config.rkt")
(require "common.rkt")
(require "points.rkt")
(require "alternative.rkt")
(require "sandbox.rkt")
(require "mainloop.rkt")
(require "programs.rkt")
(require "formats/test.rkt")
(require "formats/datafile.rkt")
(require "float.rkt")

(define precisions '(double single posit16))

(define (calc-error prog precondition precision prec-res points)
  (if (and prog prec-res points)
    (begin
      (match precision
        ['double (enable-flag! 'precision 'double)]
        ['single (disable-flag! 'precision 'double)]
        ['posit16 void])
      ;; Setting bit-width and num-points for errors-score
      (let ([bit-width (if (eq? precision 'double) 64 32)])
        (errors-score (errors prog points) #:bit-width bit-width)))
    #f))

(define (add-space-till-length str n)
  (if (< (string-length str) n)
    (string-append str (string-join (make-list (- n (string-length str)) " ") ""))
    str))

(define (make-string-length str n)
  (cond
    [(< (string-length str) n) (add-space-till-length str n)]
    [(> (string-length str) n) (substring str 0 n)]
    [else str]))

(define (print-error-table results precisions)
  (define precision-strings (map ~a precisions))
  (define max-precision-string-length (apply max (map string-length precision-strings)))
  (printf "|~a|" (string-join (make-list max-precision-string-length " ") ""))
  (for ([prec (cons "start prog" precision-strings)])
    (printf "~a|" prec))
  (displayln "")

  (for ([prec-row precision-strings] [prec-results results])
    (printf "|~a|" (add-space-till-length prec-row max-precision-string-length))
    (for ([prog-results prec-results] [prec-col (cons "start prog" precision-strings)])
      (printf "~a|" (make-string-length (~a prog-results) (string-length prec-col))))
    (displayln "")))

(define (run-tests . bench-dirs)
  (define tests (append-map load-tests bench-dirs))
  (define seed (get-seed))
  (printf "Running Herbie on ~a tests (seed: ~a)...\n" (length tests) seed)
  (for/list ([t tests])
    (printf "Now running test: ~a\n" (test-name t))
    (printf "Starting program: ~a\n" (test-program t))
    (define test-results (for/list ([precision precisions])
      (match precision
        ['single (disable-flag! 'precision 'double)]
        ['double (enable-flag! 'precision 'double)]
        ['posit16 void])
      (define precision-test (if (eq? precision 'posit16)
                               (struct-copy test t
                                            [precision 'posit16])
                               t))
      (define result (get-test-result precision-test))
      (if (test-result? result)
        (printf "Precision ~a result: ~a\n" precision (alt-program (test-result-end-alt result)))
        (printf "Precision ~a timed out or failed\n" precision))
      result))

    (define start-prog (test-program t))
    (define precondition (test-precondition t))
    (define programs (cons start-prog (for/list ([res test-results])
                                        (if (test-result? res)
                                          (alt-program (test-result-end-alt res))
                                          #f))))
    (define res (for/list ([precision precisions] [prec-res (cdr programs)] [res test-results])
      (for/list ([prog programs])
        (if (and prog (test-result? res))
          (let* ([pcon (mk-pcontext (test-result-newpoints res) (test-result-newexacts res))]
                 [ctx-prec (if (or (eq? precision 'double) (eq? precision 'single)) 'real precision)]
                 [precision-ctx (for/list ([var (program-variables prog)]) (cons var ctx-prec))]
                 [precision-prog-body (desugar-program (program-body prog) precision-ctx)]
                 [precision-prog `(λ ,(program-variables prog) ,precision-prog-body)])
            (calc-error precision-prog precondition precision prec-res pcon))
          #f))))
    (print-error-table res precisions)
    (displayln "")))

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
