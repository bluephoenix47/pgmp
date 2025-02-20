#lang racket

;; First run
;; > raco pgmp --profile example/exclusive-cond.rkt
;;
;; The test suite will fail the first time, since I will not yet be
;; optimized.
;;
;; Next run
;; > racket -t example/exclusive-cond.rkt
;;
;; The test suite will pass, silently.
;;
;; Alternatively, run
;; > raco test example/exclusive-cond.rkt
;;
;; The test submodule performs the profile, save, run workflow
;; programatically.
(require pgmp)

(module+ main
  (require rackunit)
  (define flag #f)
  (define (set-flag x) (unless flag (set! flag x)))
  (for ([x (list 1 2 3 4 5 #\x #\a 'a 'b 'c)])
    (exclusive-cond
      [(begin (set-flag 'bad) (char? x)) (displayln "A char")]
      [(begin (set-flag 'good) (number? x)) (displayln "A number")]
      [(begin (set-flag 'bad) (symbol? x)) (displayln "A symbol")]))
  (check-equal? flag 'good))

(module+ test
  (require syntax/location)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (run-with-profiling (quote-module-path ".."  main)))
  (save-profile (build-path (current-directory) "exclusive-cond.rkt"))
  (parameterize ([current-output-port (open-output-nowhere)])
    (dynamic-require (quote-module-path ".." main) 0)))
