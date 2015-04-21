#lang scribble/base
@(require
   "defs.rkt"
   "bib.rkt"
   scribble/manual
   scriblib/footnote
   scriblib/figure)

@title[#:tag "study-virtual-call"]{Profile-Guided Receiver Class Prediction}
Profile-guided receiver class prediction@~citea["holzle1994optimizing"
"grove95"] is a well-known PGO for object-oriented languages.
However, when an object-oriented language is implemented via
meta-programming as a domain-specific language (DSL), the host language
may not be able to implement this PGO.
In this second case study, we implement a simplified object system as a
syntax extension.
Using our design, we easily equip this object system with
profile-guided receiver class predication.
This demonstrates that our design is both expressive enough to implement
well-known PGOs and powerful enough to provide DSLs with PGOs not
available in the host language.
The full implementation of profile-guided receiver class prediction is
44 lines long, while the implementation of the entire object system
(including the PGO) is 129 lines long.
@figure**["method-call-impl" "Implementation of profile-guided receiver class prediction"
@#reader scribble/comment-reader #:escape-id UNSYNTAX
(RACKETBLOCK0
(define-syntax (method syn)
  (syntax-case syn ()
    [(_ obj m val* ...)
     ....
     ;; Don't copy the object expression throughout the template.
     #`(let* ([x obj])
         (cond
           #,@(if no-profile-data?
                  ;; If no profile data, instrument!
                  (for/list ([d instr-dispatch-calls] [class all-classes])
                    #`((instance-of? x #,class) (#,d x m val* ...)))
                  ;; If profile data, inline up to the top @racket[inline-limit] classes
                  ;; with non-zero weights
                  (for/list ([class (take sorted-classes inline-limit)])
                    #`((instance-of? x #,class)
                       #,(inline-method class #'x #'m #'(val* ...)))))
           ;; Fall back to dynamic dispatch
           [else (dynamic-dispatch x m val* ...)]))])))]

@Figure-ref{method-call-impl} shows the implementation of profile-guided
receiver class prediction.
A method call such as @racket[(method s area)] is actually a
meta-program that generates code as follows.
First, it generates a new profile point for each class in the system.
When profile information is not available, the method call generates a
@racket[cond] expression with a clause for each class in the system@note{A
production implementation would create a table of instrumented dynamic
dispatch calls and dynamically dispatch through this table, instead of
instrumenting code with @racket[cond].  However, using @racket[cond]
simplifies visualizing the instrumentation.}.
Each clause tests if @racket[s] is an instance of a specific
class, ignores the result, and uses normal dynamic dispatch to call the
@racket[area] method of @racket[s].
However, @emph{a different profile point is associated with each branch}.
That is, each method call site is instrumented by generating a multi-way
branch to the standard dynamic dispatch routine, but with a separate
profile point in each branch.
When profile information @emph{is} available, the method call generates a
@racket[cond] expression with clauses for the most frequently used classes
at this method call site.
Each clause again tests if @racket[s] is an instance of a specific
class, but the body of the clause is generated by inlining the method
for that class---that is, it performs polymorphic inline caching for the
most frequently used classes based on profile information.
The full implementation of profile-guided receiver class prediction
is 44 lines long. The rest of the object system implementation is an
additional 87 lines long.
@todo{Maybe implement the instrumented hash table later}

@Figure-ref{method-call-example} shows an example code snippet using
this object system.
@Figure-ref{method-call-output} demonstrates the resulting code after
instrumentation, and the resulting code after optimization.
Note that each occurrence of @racket[(instrumented-dispatch x area)]
has a different profile point, so each occurrence is profiled separately.
@figure["method-call-example" "Example of profile-guided receiver class prediction"
@#reader scribble/comment-reader #:escape-id UNSYNTAX
(RACKETBLOCK0
(class Square
  ((length 0))
  (define-method (area this)
    (sqr (field this length))))
(class Circle
  ((radius 0))
  (define-method (area this)
    (* pi (sqr (field this radius)))))
(class Triangle
  ((base 0) (height 0))
  (define-method (area this)
    (* 1/2 base height)))
....
(for/list ([s (list cir1 cir2 cir3 sqr1)])
  (method s area))
)]

@figure["method-call-output" (elem "Generated code from "
@Figure-ref{method-call-example})
@#reader scribble/comment-reader #:escape-id UNSYNTAX
(RACKETBLOCK0
;; ---------------------------
;; Generated code after instrumentation
....
(for/list ([s (list cir1 cir2 cir3 sqr1)])
  (let* ([x s])
    (cond
      [(instance-of? x 'Square)    ;; Run 1 time
       (instrumented-dispatch x area)]
      [(instance-of? x 'Circle)    ;; Run 3 times
       (instrumented-dispatch x area)]
      [(instance-of? x 'Triangle)  ;; Run 0 times
       (instrumented-dispatch x area)]
      [else (dynamic-dispatch x area)])))

;; ---------------------------
;; Generated code after optimization
....
(for/list ([s (list cir1 cir2 cir3 sqr1)])
  (let* ([x s])
    (cond
      [(instance-of? x 'Square)  ;; Run 1 time
       (sqr (field x length))]
      [(instance-of? x 'Circle)  ;; Run 3 times
       (* pi (sqr (field x radius)))]
      [else (dynamic-dispatch x area)]))))]

As a further improvement, we could reuse @racket[exclusive-cond] to test
for classes in the the most likely order.
@figure-here["method-call-exclusive-cond" "Profile-guided receiver class prediction, sorted."
@#reader scribble/comment-reader #:escape-id UNSYNTAX
(RACKETBLOCK0
;; ---------------------------
;; After optimization
....
(for/list ([s (list cir1 cir2 cir3 sqr1)])
  (let* ([x s])
    (exclusive-cond
      [(instance-of? x 'Square)  ;; Run 1 time
       (sqr (field x length))]
      [(instance-of? x 'Circle)  ;; Run 3 times
       (* pi (sqr (field x radius)))]
      [else (dynamic-dispatch x area)])))

;; ---------------------------
;; After more optimization
....
(for/list ([s (list cir1 cir2 cir3 sqr1)])
  (let* ([x s])
    (cond
      [(instance-of? x 'Circle)  ;; Run 3 times
       (* pi (sqr (field x radius)))]
      [(instance-of? x 'Square)  ;; Run 1 time
       (sqr (field x length))]
      [else (dynamic-dispatch x area)]))))]
