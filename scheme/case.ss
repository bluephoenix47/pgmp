;; Copyright © 2015 Cisco Systems, Inc

(library (case)
  (export case)
  (import (exclusive-cond) (except (chezscheme) case))

  (define-syntax (case x)
    (define (helper key-expr clause* els?)
      (define-record-type clause (fields (mutable keys) body))
      (define (parse-clause clause)
        (syntax-case clause ()
          [((k ...) e1 e2 ...) (make-clause #'(k ...) #'(e1 e2 ...))]
          [_ (syntax-error "invalid case clause" clause)]))
      (define (emit clause*)
        #`(let ([t #,key-expr])
            (exclusive-cond
              #,@(map (lambda (clause)
                        #`[(memv t '#,(clause-keys clause))
                           #,@(clause-body clause)])
                      clause*)
              . #,els?)))
      (let ([clause* (map parse-clause clause*)])
         (define ht (make-hashtable equal-hash equal?))
         (define (trim-keys! clause)
           (clause-keys-set! clause
              (let f ([keys (clause-keys clause)])
                (if (null? keys)
                    '()
                    (let* ([key (car keys)]
                           [datum-key (syntax->datum key)])
                      (if (hashtable-ref ht datum-key #f)
                          (f (cdr keys))
                          (begin
                            (hashtable-set! ht datum-key #t)
                            (cons key (f (cdr keys))))))))))
                  (for-each trim-keys! clause*)
                  (emit clause*)))
      (syntax-case x (else)
        [(_ e clause ... [else e1 e2 ...])
         (helper #'e #'(clause ...) #'([else e1 e2 ...]))]
        [(_ e clause ...)
         (helper #'e #'(clause ...) #'())])))
