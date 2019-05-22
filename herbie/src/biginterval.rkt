#lang racket

(require math/bigfloat)
(require "common.rkt" "syntax/types.rkt")

(module+ test (require rackunit "float.rkt" math/flonum))

(struct ival (lo hi err? err) #:transparent)

(provide (contract-out
          [struct ival ([lo bigvalue?] [hi bigvalue?] [err? boolean?] [err boolean?])]
          [mk-ival (-> real? ival?)]
          [ival-pi (-> ival?)]
          [ival-e  (-> ival?)]
          [ival-bool (-> boolean? ival?)]
          [ival-add (-> ival? ival? ival?)]
          [ival-sub (-> ival? ival? ival?)]
          [ival-neg (-> ival? ival?)]
          [ival-mult (-> ival? ival? ival?)]
          [ival-div (-> ival? ival? ival?)]
          [ival-fma (-> ival? ival? ival? ival?)]
          [ival-fabs (-> ival? ival?)]
          [ival-sqrt (-> ival? ival?)]
          [ival-cbrt (-> ival? ival?)]
          [ival-hypot (-> ival? ival? ival?)]
          [ival-exp (-> ival? ival?)]
          [ival-expm1 (-> ival? ival?)]
          [ival-log (-> ival? ival?)]
          [ival-log1p (-> ival? ival?)]
          [ival-pow (-> ival? ival? ival?)]
          [ival-sin (-> ival? ival?)]
          [ival-cos (-> ival? ival?)]
          [ival-tan (-> ival? ival?)]
          [ival-asin (-> ival? ival?)]
          [ival-acos (-> ival? ival?)]
          [ival-atan (-> ival? ival?)]
          [ival-atan2 (-> ival? ival? ival?)]
          [ival-sinh (-> ival? ival?)]
          [ival-cosh (-> ival? ival?)]
          [ival-tanh (-> ival? ival?)]
          [ival-fmod (-> ival? ival? ival?)]
          [ival-and (->* () #:rest (listof ival?) ival?)]
          [ival-or  (->* () #:rest (listof ival?) ival?)]
          [ival-not (-> ival? ival?)]
          [ival-<  (->* () #:rest (listof ival?) ival?)]
          [ival-<= (->* () #:rest (listof ival?) ival?)]
          [ival->  (->* () #:rest (listof ival?) ival?)]
          [ival->= (->* () #:rest (listof ival?) ival?)]
          [ival-== (->* () #:rest (listof ival?) ival?)]
          [ival-!= (->* () #:rest (listof ival?) ival?)]
          [ival-if (-> ival? ival? ival? ival?)]))

(define (mk-ival x)
  (define err? (or (nan? x) (infinite? x)))
  (define x* (bf x)) ;; TODO: Assuming that float precision < bigfloat precision
  (ival x* x* err? err?))

(define (ival-pi)
  (ival (rnd 'down identity pi.bf) (rnd 'up identity pi.bf) #f #f))

(define (ival-e)
  (ival (rnd 'down bfexp 1.bf) (rnd 'up bfexp 1.bf) #f #f))

(define (ival-bool b)
  (ival b b #f #f))

(define ival-true (ival-bool #t))

(define-syntax-rule (rnd mode op args ...)
  (parameterize ([bf-rounding-mode mode])
    (op args ...)))

(define (ival-neg x)
  ;; No rounding, negation is exact
  (ival (bf- (ival-hi x)) (bf- (ival-lo x)) (ival-err? x) (ival-err x)))

(define (ival-add x y)
  (ival (rnd 'down bf+ (ival-lo x) (ival-lo y))
        (rnd 'up bf+ (ival-hi x) (ival-hi y))
        (or (ival-err? x) (ival-err? y))
        (or (ival-err x) (ival-err y))))

(define (ival-sub x y)
  (ival (rnd 'down bf- (ival-lo x) (ival-hi y))
        (rnd 'up bf- (ival-hi x) (ival-lo y))
        (or (ival-err? x) (ival-err? y))
        (or (ival-err x) (ival-err y))))

(define (bfmin* a . as)
  (if (null? as) a (apply bfmin* (bfmin a (car as)) (cdr as))))

(define (bfmax* a . as)
  (if (null? as) a (apply bfmax* (bfmax a (car as)) (cdr as))))

(define (ival-mult x y)
  (define err? (or (ival-err? x) (ival-err? y)))
  (define err (or (ival-err x) (ival-err y)))
  (match* ((classify-ival x) (classify-ival y))
   [(1 1)
    (ival (rnd 'down bf* (ival-lo x) (ival-lo y))
          (rnd 'up bf* (ival-hi x) (ival-hi y)) err? err)]
   [(1 -1)
    (ival (rnd 'down bf* (ival-hi x) (ival-lo y))
          (rnd 'up bf* (ival-lo x) (ival-hi y)) err? err)]
   [(1 0)
    (ival (rnd 'down bf* (ival-hi x) (ival-lo y))
          (rnd 'up bf* (ival-hi x) (ival-hi y)) err? err)]
   [(-1 0)
    (ival (rnd 'down bf* (ival-lo x) (ival-hi y))
          (rnd 'up bf* (ival-lo x) (ival-lo y)) err? err)]
   [(-1 1)
    (ival (rnd 'down bf* (ival-lo x) (ival-hi y))
          (rnd 'up bf* (ival-hi x) (ival-lo y)) err? err)]
   [(-1 -1)
    (ival (rnd 'down bf* (ival-hi x) (ival-hi y))
          (rnd 'up bf* (ival-lo x) (ival-lo y)) err? err)]
   [(0 1)
    (ival (rnd 'down bf* (ival-lo x) (ival-hi y))
          (rnd 'up bf* (ival-hi x) (ival-hi y)) err? err)]
   [(0 -1)
    (ival (rnd 'down bf* (ival-hi x) (ival-lo y))
          (rnd 'up bf* (ival-lo x) (ival-lo y)) err? err)]
   [(0 0) ; The "else" case is always correct, but is slow
    ;; We round only down, and approximate rounding up with bfnext below
    (define opts
      (rnd 'down list
           (bf* (ival-lo x) (ival-lo y)) (bf* (ival-hi x) (ival-lo y))
           (bf* (ival-lo x) (ival-hi y)) (bf* (ival-hi x) (ival-hi y))))
    (ival (apply bfmin* opts) (bfnext (apply bfmax* opts)) err? err)]))

(define (ival-div x y)
  (define err? (or (ival-err? x) (ival-err? y) (and (bf<= (ival-lo y) 0.bf) (bf>= (ival-hi y) 0.bf))))
  (define err (or (ival-err x) (ival-err y) (and (bf= (ival-lo y) 0.bf) (bf= (ival-hi y) 0.bf))))
    ;; We round only down, and approximate rounding up with bfnext below
  (match* ((classify-ival x) (classify-ival y))
    [(_ 0)
     (ival -inf.bf +inf.bf err? err)]
    [(1 1)
     (ival (rnd 'down bf/ (ival-lo x) (ival-hi y))
           (rnd 'up bf/ (ival-hi x) (ival-lo y)) err? err)]
    [(1 -1)
     (ival (rnd 'down bf/ (ival-hi x) (ival-hi y))
           (rnd 'up bf/ (ival-lo x) (ival-lo y)) err? err)]
    [(-1 1)
     (ival (rnd 'down bf/ (ival-lo x) (ival-lo y))
           (rnd 'up bf/ (ival-hi x) (ival-hi y)) err? err)]
    [(-1 -1)
     (ival (rnd 'down bf/ (ival-hi x) (ival-lo y))
           (rnd 'up bf/ (ival-lo x) (ival-hi y)) err? err)]
    [(0 1)
     (ival (rnd 'down bf/ (ival-lo x) (ival-lo y))
           (rnd 'up bf/ (ival-hi x) (ival-lo y)) err? err)]
    [(0 -1)
     (ival (rnd 'down bf/ (ival-hi x) (ival-hi y))
           (rnd 'up bf/ (ival-lo x) (ival-hi y)) err? err)]
    [(_ _)
     (define opts
       (rnd 'down list
            (bf/ (ival-lo x) (ival-lo y)) (bf/ (ival-hi x) (ival-lo y))
            (bf/ (ival-lo x) (ival-hi y)) (bf/ (ival-hi x) (ival-hi y))))
     (ival (apply bfmin* opts) (bfnext (apply bfmax* opts)) err? err)]))

(define (ival-exp x)
  (ival (rnd 'down bfexp (ival-lo x)) (rnd 'up bfexp (ival-hi x)) (ival-err? x) (ival-err x)))

(define (ival-expm1 x)
  (ival (rnd 'down bfexpm1 (ival-lo x)) (rnd 'up bfexpm1 (ival-hi x)) (ival-err? x) (ival-err x)))

(define (ival-log x)
  (define err (or (ival-err x) (bf<= (ival-hi x) 0.bf)))
  (define err? (or err (ival-err? x) (bf<= (ival-lo x) 0.bf)))
  (ival (rnd 'down bflog (ival-lo x)) (rnd 'up bflog (ival-hi x))
        err? err))

(define (ival-log1p x)
  (define err (or (ival-err x) (bf<= (ival-hi x) -1.bf)))
  (define err? (or err (ival-err? x) (bf<= (ival-lo x) -1.bf)))
  (ival (rnd 'down bflog1p (ival-lo x)) (rnd 'up bflog1p (ival-hi x))
        err? err))

(define (ival-sqrt x)
  (define err (or (ival-err x) (bf<= (ival-hi x) 0.bf)))
  (define err? (or err (ival-err? x) (bf<= (ival-lo x) 0.bf)))
  (ival (rnd 'down bfsqrt (ival-lo x)) (rnd 'up bfsqrt (ival-hi x))
        err? err))

(define (ival-cbrt x)
  (ival (rnd 'down bfcbrt (ival-lo x)) (rnd 'up bfcbrt (ival-hi x)) (ival-err? x) (ival-err x)))

(define (ival-hypot x y)
  (define err? (or (ival-err? x) (ival-err? y)))
  (define err (or (ival-err x) (ival-err y)))
  (define x* (ival-fabs x))
  (define y* (ival-fabs y))
  (ival (rnd 'down bfhypot (ival-lo x*) (ival-lo y*))
        (rnd 'up bfhypot (ival-hi x*) (ival-hi y*))
        err? err))

(define (ival-pow x y)
  (define err? (or (ival-err? x) (ival-err? y)))
  (define err (or (ival-err x) (ival-err y)))
  (cond
   [(bf>= (ival-lo x) 0.bf)
    (let ([lo
           (if (bf< (ival-lo x) 1.bf)
               (rnd 'down bfexpt (ival-lo x) (ival-hi y))
               (rnd 'down bfexpt (ival-lo x) (ival-lo y)))]
          [hi
           (if (bf> (ival-hi x) 1.bf)
               (rnd 'up bfexpt (ival-hi x) (ival-hi y))
               (rnd 'up bfexpt (ival-hi x) (ival-lo y)))])
      (ival lo hi err? err))]
   [(and (bf= (ival-lo y) (ival-hi y)) (bfinteger? (ival-lo y)))
    (ival (rnd 'down bfexpt (ival-lo x) (ival-lo y))
          (rnd 'up bfexpt (ival-lo x) (ival-lo y))
          err? err)]
   [else
    ;; In this case, the base range includes negatives and the exp range includes reals
    ;; Focus first on just the negatives in the base range
    ;; All the reals in the exp range just make NaN a possible output
    ;; If there are no integers in the exp range, those NaNs are the only output
    ;; If there are, the min of the negative base values is from the biggest odd integer in the range
    ;;  and the max is from the biggest even integer in the range
    (define a (bfceiling (ival-lo y)))
    (define b (bffloor (ival-hi y)))
    (define lo (ival-lo x))
    (define neg-range
      (cond
       [(bf< b a)
        (ival +nan.bf +nan.bf #t #t)]
       [(bf= a b)
        (ival (rnd 'down bfexpt (ival-lo x) a) (rnd 'up bfexpt (ival-hi x) a) err? err)]
       [(bfodd? b)
        (ival (rnd 'down bfexpt (ival-lo x) b)
              (rnd 'up bfmax (bfexpt (ival-hi x) (bf- b 1.bf)) (bfexpt (ival-lo x) (bf- b 1.bf))) err? err)]
       [(bfeven? b)
        (ival (rnd 'down bfexpt (ival-lo x) (bf- b 1.bf))
              (rnd 'up bfmax (bfexpt (ival-hi x) b) (bfexpt (ival-lo x) b)) err? err)]
       [else (ival +nan.bf +nan.bf #f #t)]))
    (if (bf> (ival-hi x) 0.bf)
        (ival-union neg-range (ival-pow (ival 0.bf (ival-hi x) err? err) y))
        neg-range)]))

(define (ival-fma a b c)
  (ival-add (ival-mult a b) c))

(define (ival-and . as)
  (ival (andmap ival-lo as) (andmap ival-hi as)
        (ormap ival-err? as) (ormap ival-err as)))

(define (ival-or . as)
  (ival (ormap ival-lo as) (ormap ival-hi as)
        (ormap ival-err? as) (ormap ival-err as)))

(define (ival-not x)
  (ival (not (ival-hi x)) (not (ival-lo x)) (ival-err? x) (ival-err x)))

(define (ival-cos x)
  (define lopi (rnd 'down identity pi.bf))
  (define hipi (rnd 'up identity pi.bf))
  (define a (rnd 'down bffloor (bf/ (ival-lo x) (if (bf< (ival-lo x) 0.bf) lopi hipi))))
  (define b (rnd 'up   bffloor (bf/ (ival-hi x) (if (bf< (ival-hi x) 0.bf) hipi lopi))))
  (cond
   [(and (bf= a b) (bfeven? a))
    (ival (rnd 'down bfcos (ival-hi x)) (rnd 'up bfcos (ival-lo x)) (ival-err? x) (ival-err x))]
   [(and (bf= a b) (bfodd? a))
    (ival (rnd 'down bfcos (ival-lo x)) (rnd 'up bfcos (ival-hi x)) (ival-err? x) (ival-err x))]
   [(and (bf= (bf- b a) 1.bf) (bfeven? a))
    (ival -1.bf (rnd 'up bfmax (bfcos (ival-lo x)) (bfcos (ival-hi x))) (ival-err? x) (ival-err x))]
   [(and (bf= (bf- b a) 1.bf) (bfodd? a))
    (ival (rnd 'down bfmin (bfcos (ival-lo x)) (bfcos (ival-hi x))) 1.bf (ival-err? x) (ival-err x))]
   [else
    (ival -1.bf 1.bf (ival-err? x) (ival-err x))]))

(define half.bf (bf/ 1.bf 2.bf))

(define (ival-sin x)
  (define lopi (rnd 'down identity pi.bf))
  (define hipi (rnd 'up identity pi.bf))
  (define a (rnd 'down bffloor (bf- (bf/ (ival-lo x) (if (bf< (ival-lo x) 0.bf) lopi hipi)) half.bf))) ; half.bf is exact
  (define b (rnd 'up bffloor (bf- (bf/ (ival-hi x) (if (bf< (ival-hi x) 0.bf) hipi lopi)) half.bf)))
  (cond
   [(and (bf= a b) (bfeven? a))
    (ival (rnd 'down bfsin (ival-hi x)) (rnd 'up bfsin (ival-lo x)) (ival-err? x) (ival-err x))]
   [(and (bf= a b) (bfodd? a))
    (ival (rnd 'down bfsin (ival-lo x)) (rnd 'up bfsin (ival-hi x)) (ival-err? x) (ival-err x))]
   [(and (bf= (bf- b a) 1.bf) (bfeven? a))
    (ival -1.bf (rnd 'up bfmax (bfsin (ival-lo x)) (bfsin (ival-hi x))) (ival-err? x) (ival-err x))]
   [(and (bf= (bf- b a) 1.bf) (bfodd? a))
    (ival (rnd 'down bfmin (bfsin (ival-lo x)) (bfsin (ival-hi x))) 1.bf (ival-err? x) (ival-err x))]
   [else
    (ival -1.bf 1.bf (ival-err? x) (ival-err x))]))

(define (ival-tan x)
  (ival-div (ival-sin x) (ival-cos x)))

(define (ival-atan x)
  (ival (rnd 'down bfatan (ival-lo x)) (rnd 'up bfatan (ival-hi x)) (ival-err? x) (ival-err x)))

(define (classify-ival x)
  (cond [(bf>= (ival-lo x) 0.bf) 1] [(bf<= (ival-hi x) 0.bf) -1] [else 0]))

(define (ival-atan2 y x)
  (define err? (or (ival-err? x) (ival-err? y)))
  (define err (or (ival-err x) (ival-err y)))

  (define tl (list (ival-hi y) (ival-lo x)))
  (define tr (list (ival-hi y) (ival-hi x)))
  (define bl (list (ival-lo y) (ival-lo x)))
  (define br (list (ival-lo y) (ival-hi x)))

  (define-values (a-lo a-hi)
    (match (cons (classify-ival x) (classify-ival y))
      ['(-1 -1) (values tl br)]
      ['( 0 -1) (values tl tr)]
      ['( 1 -1) (values bl tr)]
      ['( 1  0) (values bl tl)]
      ['( 1  1) (values br tl)]
      ['( 0  1) (values br bl)]
      ['(-1  1) (values tr bl)]
      [_        (values #f #f)]))

  (if a-lo
      (ival (rnd 'down apply bfatan2 a-lo) (rnd 'up apply bfatan2 a-hi) err? err)
      (ival (rnd 'down bf- pi.bf) (rnd 'up identity pi.bf)
            (or err? (bf>= (ival-hi x) 0.bf))
            (or err (and (bf= (ival-lo x) 0.bf) (bf= (ival-hi x) 0.bf) (bf= (ival-lo y) 0.bf) (bf= (ival-hi y) 0.bf))))))

(define (ival-asin x)
  (ival (rnd 'down bfasin (ival-lo x)) (rnd 'up bfasin (ival-hi x))
        (or (ival-err? x) (bf< (ival-lo x) -1.bf) (bf> (ival-hi x) 1.bf))
        (or (ival-err x) (bf< (ival-hi x) -1.bf) (bf> (ival-lo x) 1.bf))))

(define (ival-acos x)
  (ival (rnd 'down bfacos (ival-hi x)) (rnd 'up bfacos (ival-lo x))
        (or (ival-err? x) (bf< (ival-lo x) -1.bf) (bf> (ival-hi x) 1.bf))
        (or (ival-err x) (bf< (ival-hi x) -1.bf) (bf> (ival-lo x) 1.bf))))

(define (ival-fabs x)
  (cond
   [(bf> (ival-lo x) 0.bf) x]
   [(bf< (ival-hi x) 0.bf)
    (ival (bf- (ival-hi x)) (bf- (ival-lo x)) (ival-err? x) (ival-err x))]
   [else ; interval stradles 0
    (ival 0.bf (bfmax (bf- (ival-lo x)) (ival-hi x)) (ival-err? x) (ival-err x))]))

(define (ival-sinh x)
  (ival (rnd 'down bfsinh (ival-lo x)) (rnd 'up bfsinh (ival-hi x)) (ival-err? x) (ival-err x)))

(define (ival-cosh x)
  (define y (ival-fabs x))
  (ival (rnd 'down bfcosh (ival-lo y)) (rnd 'up bfcosh (ival-hi y)) (ival-err? y) (ival-err y)))

(define (ival-tanh x)
  (ival (rnd 'down bftanh (ival-lo x)) (rnd 'up bftanh (ival-hi x)) (ival-err? x) (ival-err x)))

(define (ival-fmod x y)
  (define y* (ival-fabs y))
  (define quot (ival-div x y*))
  (define a (rnd 'down bftruncate (ival-lo quot)))
  (define b (rnd 'up bftruncate (ival-hi quot)))
  (define err? (or (ival-err? x) (ival-err? y) (bf= (ival-lo y*) 0.bf)))
  (define err (or (ival-err x) (ival-err y) (bf= (ival-hi y*) 0.bf)))
  (define tquot (ival a b err? err))

  (cond
   [(bf= a b) (ival-sub x (ival-mult tquot y*))]
   [(bf<= b 0.bf) (ival (bf- (ival-hi y*)) 0.bf err? err)]
   [(bf>= a 0.bf) (ival 0.bf (ival-hi y*) err? err)]
   [else (ival (bf- (ival-hi y*)) (ival-hi y*) err? err)]))

(define (ival-cmp x y)
  (define can-< (bf< (ival-lo x) (ival-hi y)))
  (define must-< (bf< (ival-hi x) (ival-lo y)))
  (define can-> (bf> (ival-hi x) (ival-lo y)))
  (define must-> (bf> (ival-lo x) (ival-hi y)))
  (values can-< must-< can-> must->))

(define (ival-<2 x y)
  (define-values (c< m< c> m>) (ival-cmp x y))
  (ival m< c< (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y))))

(define (ival-<=2 x y)
  (define-values (c< m< c> m>) (ival-cmp x y))
  (ival (not c>) (not m>) (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y))))

(define (ival->2 x y)
  (define-values (c< m< c> m>) (ival-cmp x y))
  (ival m> c> (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y))))

(define (ival->=2 x y)
  (define-values (c< m< c> m>) (ival-cmp x y))
  (ival (not c<) (not m<) (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y))))

(define (ival-==2 x y)
  (define-values (c< m< c> m>) (ival-cmp x y))
  (ival (and (not c<) (not c>)) (or (not m<) (not m>)) (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y))))

(define (ival-comparator f name)
  (procedure-rename
   (λ as
     (if (null? as)
         ival-true
         (let loop ([head (car as)] [tail (cdr as)] [acc ival-true])
           (match tail
             ['() acc]
             [(cons next rest)
              (loop next rest (ival-and (f head next) ival-true))]))))
   name))

(define ival-<  (ival-comparator ival-<2  'ival-<))
(define ival-<= (ival-comparator ival-<=2 'ival-<=))
(define ival->  (ival-comparator ival->2  'ival->))
(define ival->= (ival-comparator ival->=2 'ival->=))
(define ival-== (ival-comparator ival-==2 'ival-==))

(define (ival-!=2 x y)
  (define-values (c< m< c> m>) (ival-cmp x y))
  (ival (or c< c>) (or m< m>) (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y))))

(define (ival-!= . as)
  (if (null? as)
      ival-true
      (let loop ([head (car as)] [tail (cdr as)])
        (if (null? tail)
            ival-true
            (ival-and
             (foldl ival-and ival-true (map (curry ival-!=2 head) tail))
             (loop (car tail) (cdr tail)))))))

(define (ival-union x y)
  (match (ival-lo x)
   [(? bigfloat?)
    (ival (bfmin (ival-lo x) (ival-lo y)) (bfmax (ival-hi x) (ival-hi y))
          (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y)))]
   [(? boolean?)
    (ival (and (ival-lo x) (ival-lo y)) (or (ival-hi x) (ival-hi y))
          (or (ival-err? x) (ival-err? y)) (or (ival-err x) (ival-err y)))]))

(define (propagate-err c x)
  (ival (ival-lo x) (ival-hi x)
        (or (ival-err? c) (ival-err? x))
        (or (ival-err c) (ival-err x))))

(define (ival-if c x y)
  (cond
   [(ival-lo c) (propagate-err c x)]
   [(not (ival-hi c)) (propagate-err c y)]
   [else (propagate-err c (ival-union x y))]))

(module+ test
  (define num-tests 1000)

  (define (sample-interval)
    (if (= (random 0 2) 0)
        (let ([v1 (sample-double)] [v2 (sample-double)])
          (ival (bf (min v1 v2)) (bf (max v1 v2)) (or (nan? v1) (nan? v2)) (and (nan? v1) (nan? v2))))
        (let* ([v1 (bf (sample-double))] [exp (random 0 31)] [mantissa (random 0 (expt 2 exp))] [sign (- (* 2 (random 0 2)) 1)])
          (define v2 (bfstep v1 (* sign (+ exp mantissa))))
          (if (= sign -1)
              (ival v2 v1 (or (bfnan? v1) (bfnan? v2)) (and (bfnan? v1) (bfnan? v2)))
              (ival v1 v2 (or (bfnan? v1) (bfnan? v2)) (and (bfnan? v1) (bfnan? v2)))))))

  (define (sample-bf)
    (bf (sample-double)))

  (define (sample-from ival)
    (if (bigfloat? (ival-lo ival))
        (let ([p (random)])
          (bf+ (bf* (bf p) (ival-lo ival)) (bf* (bf- 1.bf (bf p)) (ival-hi ival))))
        (let ([p (random 0 2)])
          (if (= p 0) (ival-lo ival) (ival-hi ival)))))

  (define (ival-valid? ival)
    (or (boolean? (ival-lo ival))
        (bfnan? (ival-lo ival))
        (bfnan? (ival-hi ival))
        (bf<= (ival-lo ival) (ival-hi ival))))

  (define (ival-contains? ival pt)
    (or (ival-err? ival)
        (if (bigfloat? pt)
            (if (bfnan? pt)
                (ival-err? ival)
                (and (bf<= (ival-lo ival) pt) (bf<= pt (ival-hi ival))))
            (or (equal? pt (ival-lo ival)) (equal? pt (ival-hi ival))))))

  (check ival-contains? (ival-bool #f) #f)
  (check ival-contains? (ival-bool #t) #t)
  (check ival-contains? (ival-pi) pi.bf)
  (check ival-contains? (ival-e) (bfexp 1.bf))
  (test-case "mk-ival"
    (for ([i (in-range num-tests)])
      (define pt (sample-double))
      (with-check-info (['point pt])
        (check-pred ival-valid? (mk-ival pt))
        (check ival-contains? (mk-ival pt) (bf pt)))))

  (define arg1
    (list (cons ival-neg   bf-)
          (cons ival-fabs  bfabs)
          (cons ival-sqrt  bfsqrt)
          (cons ival-cbrt  bfcbrt)
          (cons ival-exp   bfexp)
          (cons ival-expm1 bfexpm1)
          (cons ival-log   bflog)
          (cons ival-log1p bflog1p)
          (cons ival-sin   bfsin)
          (cons ival-cos   bfcos)
          (cons ival-tan   bftan)
          (cons ival-asin  bfasin)
          (cons ival-acos  bfacos)
          (cons ival-atan  bfatan)
          (cons ival-sinh  bfsinh)
          (cons ival-cosh  bfcosh)
          (cons ival-tanh  bftanh)))

  (for ([(ival-fn fn) (in-dict arg1)])
    (test-case (~a (object-name ival-fn))
       (for ([n (in-range num-tests)])
         (define i (sample-interval))
         (define x (sample-from i))
         (with-check-info (['fn ival-fn] ['interval i] ['point x] ['number n])
           (check-pred ival-valid? (ival-fn i))
           (check ival-contains? (ival-fn i) (fn x))))))

  (define (bffmod x y)
    (bf- x (bf* (bftruncate (bf/ x y)) y)))

  (define arg2
    (list (cons ival-add bf+)
          (cons ival-sub bf-)
          (cons ival-mult bf*)
          (cons ival-div bf/)
          (cons ival-hypot bfhypot)
          (cons ival-atan2 bfatan2)
          (cons ival-< bf<)
          (cons ival-> bf>)
          (cons ival-<= bf<=)
          (cons ival->= bf>=)
          (cons ival-== bf=)
          (cons ival-!= (compose not bf=))))

  (for ([(ival-fn fn) (in-dict arg2)])
    (test-case (~a (object-name ival-fn))
       (for ([n (in-range num-tests)])
         (define i1 (sample-interval))
         (define i2 (sample-interval))
         (define x1 (sample-from i1))
         (define x2 (sample-from i2))

         (with-check-info (['fn ival-fn] ['interval1 i1] ['interval2 i2] ['point1 x1] ['point2 x2] ['number n])
           (define iy (ival-fn i1 i2))
           (check-pred ival-valid? iy)
           (check ival-contains? iy (fn x1 x2))))))

  (test-case "ival-fmod"
    (for ([n (in-range num-tests)])
      (define i1 (sample-interval))
      (define i2 (sample-interval))
      (define x1 (sample-from i1))
      (define x2 (sample-from i2))

      (define y (parameterize ([bf-precision 8000]) (bffmod x1 x2)))

      ;; Known bug in bffmod where rounding error causes invalid output
      (unless (or (bf<= (bf* y x1) 0.bf) (bf> (bfabs y) (bfabs x2)))
        (with-check-info (['fn ival-fmod] ['interval1 i1] ['interval2 i2]
                          ['point1 x1] ['point2 x2] ['number n])
          (define iy (ival-fmod i1 i2))
          (check-pred ival-valid? iy)
          (check ival-contains? iy y)))))
  )
