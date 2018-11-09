#lang racket

(require math/flonum)
(require math/bigfloat)
(require "../common.rkt")
(require "../points.rkt")
(require "../float.rkt")
(require "../programs.rkt")
(require "../alternative.rkt")

(provide localize-error reset-analyze-cache!)

(define (repeat c)
  (for/list ([(p e) (in-pcontext (*pcontext*))])
    c))

(define *analyze-cache* (make-hash))
(define *analyze-context* (make-parameter #f))

(define (localize-on-expression expr vars cache precision)
  (hash-ref! cache (cons expr precision)
             (λ ()
                (match expr
                  [(? constant?)
                   (cons (repeat (->bf expr)) (repeat 1))]
                  [(? variable?)
                   (cons (map ->bf (dict-ref vars expr)) (repeat 1))]
                  [`(if ,c ,ift ,iff)
                   (let ([exact-ift (car (localize-on-expression ift vars cache precision))]
                         [exact-iff (car (localize-on-expression iff vars cache precision))]
                         [exact-cond (for/list ([(p _) (in-pcontext (*pcontext*))])
				       ((eval-prog `(λ ,(map car vars) ,c) 'bf) p))])
                     (cons (for/list ([c exact-cond] [t exact-ift] [f exact-iff]) (if c t f))
                           (repeat 1)))]
                  [`(,f ,args ...)
                   (let* ([argvals
                           (flip-lists (map (compose car (curryr localize-on-expression vars cache precision)) args))]
                          [f-exact  (operator-info f 'bf)]
                          [f-approx (operator-info f 'fl)]
                          [exact  (map (curry apply f-exact) argvals)]
                          [approx (map (compose (curry apply f-approx) (curry map ->flonum)) argvals)]
                          [error
                           (map (λ (ex ap) (+ 1 (abs (ulp-difference (->flonum ex)
								     (->flonum ap))))) exact approx)])
                     (cons exact error))]))))

(define (reset-analyze-cache!)
  (*analyze-context* (*pcontext*))
  (hash-clear! *analyze-cache*))

(define (localize-error prog precision)
  (define varmap (map cons (program-variables prog)
		      (flip-lists (for/list ([(p e) (in-pcontext (*pcontext*))])
				    p))))
  (define cache
    (if (eq? (*analyze-context*) (*pcontext*))
        *analyze-cache*
        (make-hash)))
  (define expr->loc (location-hash prog))

  (localize-on-expression (program-body prog) varmap cache precision)

  (define locs
    (reap [sow]
          (for ([(expr locs) (in-hash expr->loc)]
                #:when (hash-has-key? cache (cons expr precision)))
            (define err (cdr (hash-ref cache (cons expr precision))))
            (when (ormap (curry < 1) err)
              (for-each (compose sow (curry cons err)) locs)))))

  (map cdr
       (take-up-to
        (sort locs > #:key (compose errors-score car))
        (*localize-expressions-limit*))))