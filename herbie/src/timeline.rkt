#lang racket
(require "config.rkt")
(provide timeline-event! timeline-log! timeline-push! without-timeline)
(module+ debug (provide *timeline*))

;; This is a box so we can get a reference outside the engine, and so
;; access its value even in a timeout.
(define *timeline* (box '()))

(register-reset (λ () (set-box! *timeline* '())))

(define (timeline-event! type)
  (define initial (hash 'type type 'time (current-inexact-milliseconds)))
  (define b (make-hash (hash->list initial))) ; convert to mutable hash
  (set-box! *timeline* (cons b (unbox *timeline*))))

(define (timeline-log! key value)
  (unless (null? (unbox *timeline*))
    (define h (car (unbox *timeline*)))
    (when (hash-has-key? h key)
      (error 'timeline "Attempting to log key ~a to timeline twice (value ~a)" key value))
    (hash-set! h key value)))

(define (timeline-push! key . values)
  (unless (null? (unbox *timeline*))
    (define val (if (= (length values) 1) (car values) values))
    (define (try-cons x)
      (if (list? x)
          (cons val x)
          (error 'timeline "Attempting to push onto a timeline non-list ~a (value ~a)" key x)))
    (hash-update! (car (unbox *timeline*)) key  try-cons '())))

(define (without-timeline thunk)
  (define old-timeline (unbox *timeline*))
  (set-box! *timeline* (list (make-hash)))
  (begin0 (thunk)
    (set-box! *timeline* old-timeline)))
