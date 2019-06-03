#lang racket

(require racket/date)
(require racket/cmdline)
(require "herbie/src/config.rkt")
(require "herbie/src/common.rkt")
(require "herbie/src/points.rkt")
(require "herbie/src/alternative.rkt")
(require "herbie/src/sandbox.rkt")
(require "herbie/src/mainloop.rkt")
(require "herbie/src/programs.rkt")
(require "herbie/src/formats/test.rkt")
(require "herbie/src/formats/datafile.rkt")
(require "herbie/src/float.rkt")

(define (calc-error prog precondition precision prec-res points)
  (if (and prog prec-res points)
    (begin
      (match precision
        ['double (enable-flag! 'precision 'double)]
        ['single (disable-flag! 'precision 'double)]
        ['posit16 void])
      ;; Setting bit-width and num-points for errors-score
      (let ([bit-width (if (eq? precision 'double) 64 32)])
        (with-handlers ([exn:fail? (λ (e) #f)])
          (errors-score (errors prog points)))))
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
  (define error-results "")
  (define precision-strings (map ~a precisions))
  (define max-precision-string-length (apply max (map string-length precision-strings)))
  (set! error-results (string-append error-results (format "|~a|" (string-join (make-list max-precision-string-length " ") ""))))
  (for ([prec (cons "start prog" precision-strings)])
    (set! error-results (string-append error-results (format "~a|" prec))))
  (set! error-results (string-append error-results "\n"))

  (for ([prec-row precision-strings] [prec-results results])
    (set! error-results (string-append error-results (format "|~a|" (add-space-till-length prec-row max-precision-string-length))))
    (for ([prog-results prec-results] [prec-col (cons "start prog" precision-strings)])
      (set! error-results (string-append error-results (format "~a|" (make-string-length (~a prog-results) (string-length prec-col))))))
    (set! error-results (string-append error-results "\n")))
  error-results)

(define (run-test-proc t precisions)
  (define output-string "")
  (set! output-string (string-append output-string (format "Now running test: ~a\n" (test-name t))))
  (set! output-string (string-append output-string (format "Starting program: ~a\n" (test-program t))))
  (define test-results (for/list ([precision precisions])
    (match precision
      ['single (disable-flag! 'precision 'double)]
      ['double (enable-flag! 'precision 'double)]
      ['posit16 void])
    (define ctx-prec (if (or (eq? precision 'double) (eq? precision 'single)) 'real precision))
    (define precision-ctx (for/list ([var (program-variables (test-program t))])
                            (cons var ctx-prec)))
    (define precision-prog-body (with-handlers ([exn:fail?
                                                  (λ (e) (program-body (test-program t)))])
                                  (desugar-program (program-body (test-program t)) precision-ctx)))
    (define precision-test (if (eq? precision 'posit16)
                             (struct-copy test t
                                          [precision 'posit16]
                                          [input precision-prog-body])
                             t))
    (define result (get-test-result precision-test))
    (if (test-success? result)
      (set! output-string (string-append output-string (format "Precision ~a result: ~a\n" precision (alt-program (test-success-end-alt result)))))
      (set! output-string (string-append output-string (format "Precision ~a timed out or failed\n" precision))))
    result))

  (define start-prog (test-program t))
  (define precondition (test-precondition t))
  (define programs (cons start-prog (for/list ([res test-results])
                                      (if (test-success? res)
                                        (alt-program (test-success-end-alt res))
                                        #f))))
  (define res (for/list ([precision precisions] [prec-res (cdr programs)] [res test-results])
    (for/list ([prog programs])
      (if (and prog (test-success? res))
        (let* ([prog* (list 'λ (program-variables prog) (resugar-program (program-body prog)))]
               [pcon (mk-pcontext (test-success-newpoints res) (test-success-newexacts res))]
               [ctx-prec (if (or (eq? precision 'double) (eq? precision 'single)) 'real precision)]
               [precision-ctx (for/list ([var (program-variables prog*)]) (cons var ctx-prec))]
               [precision-prog-body (with-handlers ([exn:fail?
                                                  (λ (e) #f)])
                                  (desugar-program (program-body prog*) precision-ctx))]
               [precision-prog `(λ ,(program-variables prog*) ,precision-prog-body)])
          (calc-error precision-prog precondition precision (and prec-res precision-prog-body) pcon))
        #f))))
  (set! output-string (string-append output-string (print-error-table res precisions)))
  (set! output-string (string-append output-string "\n"))
  output-string)

(define (make-worker)
  (place ch
    (let loop ()
      (match (place-channel-get ch)
        [`(apply ,self ,test ,precisions)
          (let ([result (run-test-proc test precisions)])
            (place-channel-put ch `(done ,self ,result)))])
      (loop))))

(define (run-tests bench-dirs num-threads use-posits)
  (define tests (append-map load-tests bench-dirs))
  (define num-tests (length tests))
  (define seed (get-seed))

  (define precisions (if use-posits '(double single posit16) '(double single)))

  (define workers
    (for/list ([wid (in-range num-threads)])
      (make-worker)))

  (printf "Running ~a brass eval workers on ~a tests (seed: ~a)\n" num-threads num-tests seed)
  (for ([worker workers])
    (place-channel-put worker `(apply ,worker ,(car tests) ,precisions))
    (set! tests (cdr tests)))

  (let loop ([out '()])
    (with-handlers ([exn:break?
                      (λ (_)
                         (eprintf "Terimating after ~a problem~a!\n"
                                  (length out (if (= (length out) 1) "" "s"))
                                  out))])
      (match-define `(done ,worker ,res) (apply sync workers))
      (display res)

      (unless (null? tests)
        (place-channel-put worker `(apply ,worker ,(car tests) ,precisions))
        (set! tests (cdr tests)))

      (define out* (cons 'done out))

      (if (= (length out*) num-tests)
        out*
        (loop out*))))

  (map place-kill workers)
  'done)

(module+ main
  (define seed (random 1 (expt 2 31)))
  (define num-threads 1)
  (define use-posits #t)
  (set-seed! seed)
  (command-line
   #:program "travis.rkt"
   #:once-each
   [("--seed") rs "The random seed to use in point generation. If false (#f), a random seed is used'"
    (define given-seed (read (open-input-string rs)))
    (when given-seed (set-seed! given-seed))]
   [("--threads") ts "The number of threads to use. If false (#f), defaults to 1."
    (when ts (set! num-threads (string->number ts)))]
   [("--no-posits") "Disable posits. Posits are on by default."
    (set! use-posits #f)]
   #:args bench-dirs
   (exit (if (run-tests bench-dirs num-threads use-posits) 0 1))))
