#lang racket

(require racket/date)
(require racket/cmdline)
(require "config.rkt")
(require "common.rkt")
(require "points.rkt")
(require "alternative.rkt")
(require "sandbox.rkt")
(require "mainloop.rkt")
(require "formats/test.rkt")
(require "formats/datafile.rkt")
(require "float.rkt")

(define precisions '(double single))

(define (calc-error prog precondition precision)
  (if prog
    (begin
      (match precision
        ['double (enable-flag! 'precision 'double)]
        ['single (disable-flag! 'precision 'double)])
      ;; Setting bit-width and num-points for errors-score
      (let ([points (prepare-points prog precondition #:num-points 8000)]
            [bit-width (if (eq? precision 'double) 64 32)])
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
  (define all-test-results (for/list ([test tests])
    (define test-results (for/list ([precision precisions])
      (printf "Running in ~a precision.\n" precision)
      (match precision
        ['single (disable-flag! 'precision 'double)]
        ['double (enable-flag! 'precision 'double)])
      (println (test-input test))
      (get-test-result test)))

    (define start-prog (test-program test))
    (define precondition (test-precondition test))
    (define programs (cons start-prog
                           (map (compose alt-program test-result-end-alt) test-results)))
    (for/list ([precision precisions])
      (for/list ([prog programs])
        (calc-error prog precondition precision)))))

  (for ([test-result all-test-results] [test tests])
    (printf "Test name: ~a\n" (test-name test))
    (print-error-table test-result precisions)
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
