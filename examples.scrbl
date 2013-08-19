#lang scribble/base
@(require "defs.rkt")
@(require scribble/manual)
@(require scriblib/footnote)
@(require scriblib/figure)
@(require racket/port)
@section[#:tag "examples" "Examples"]
This section presents several macros that use profiling information to
eptimize the expanded code. The first example is @racket[exclusive-cond],
which was mentioned in @secref{intro}. The second is a profile
directed loop unrolling example. While loop unrolling can be done with
block-level profiling, it is simple to do as a macro, and avoids the problem of
reconstructing loops from basic-blocks. The final example is a sequence library
that is conditionally represented using a linked-list or a vector, depending on
profile information.

@subsection{exclusive-cond}
@racket[cond] is a Scheme branching construct, described briefly in in
@secref{intro}. The following example of @racket[cond] shows the
forms it can take.

@;@racketblock[#,(port->string (open-input-file "cond-all.ss"))]
@racketblock[
(cond
  [ls (car ls)]
  [ls => car]
  [(or ls (car ls))])]

The first clauses has a test on the left-hand side and some
expression on the right-hand side. Clauses of this form are evaluated in
order. The right-hand side of the first clause with a true left-hand
side is evaluated.

The second form passes the value of the left-hand side to the function
on the right-hand side only if the left-hand side evaluates to a true
value. In Scheme, any value that is not @racket[#f] is true, so this
can be used to post-process non-boolean true values. 

That last form simply returns the value of the left-hand side if it
evaluates to a true value. The last form is equivalent to the clause
@racket[(e => (lambda (x) x))].

@figure-here["exclusive-cond" 
        "Implementation of exclusive-cond"
@#reader scribble/comment-reader 
(racketblock 
(define-syntax exclusive-cond
  (lambda (x)
    (define-record-type clause
      (nongenerative)
      (fields (immutable clause) (immutable count))
      (protocol
        (lambda (new)
          (lambda (e1 e2)
            (new e1 (or (profile-query-weight e2) 0))))))
    (define parse-clause
      (lambda (clause)
        (syntax-case clause (=>)
          ;;[(e0) (make-clause clause ???)]
          [(e0 => e1) (make-clause clause #'e1)]
          [(e0 e1 e2 ...) (make-clause clause #'e1)]
          [_ (syntax-error clause "invalid exclusive-cond clause")])))
    (define (helper clause* els) 
      (define (sort-em clause*)
        (sort (lambda (cl1 cl2) (> (clause-count cl1) (clause-count cl2))) 
          (map parse-clause clause*)))
      #`(cond
          #,@(map clause-clause (sort-em clause*))
          #,@(if els #`(,els) #'())))
    (syntax-case x (else)
      [(_ m1 ... (else e1 e2 ...)) (helper #'(m1 ...) #'(else e1 e2 ...))]
      [(_ m1 ...) (helper #'(m1 ...) #f)])))
)]

@; How does exclusive-cond use profile information to implement cond
The @racket[exclusive-cond] macro, @figure-ref{exclusive-cond}, shows an
implementation of @racket[cond] that will rearrange clauses based on
the profiling information of the right-hand sides. Since the left-hand
sides will be executed depending on the order of the clauses, profiling
information from the left-hand side is not enough to determine which
clause is true most often. Unfortunately, this means we
cannot @note{By manually hacking source objects, it may be possible
but would not be pretty.} implement the last syntax for @racket[cond]
clauses which has only a left-hand side.

@; How are clauses parsed
In order to sort the clauses, all clauses are parsed before the code is
generated. @racket[exclusive-cond] first parses each clause into a
clause record.  The clause record stores the original syntax for the
clause and the weighted profile count for that clause. @todo{Maybe why
we pick an expression from the body of each clause here, instead of up
there} Since a valid @racket[exclusive-cond] clause is also a valid
@racket[cond] clause, the syntax is simply copied.

@todo{syntax or code?}

@; How are clauses emitted in order
After parsing each clause, the clause records are sorted by the profile
weight. Once sorted, a @racket[cond] expression is generated by
emitting each clause in sorted order. If an @racket[else] clause exists, it
is always emitted last.

@figure-here["exclusive-cond-expansion"
        "an example of exclusive-cond and its expansion"
@#reader scribble/comment-reader 
@racketblock[
(exclusive-cond
  [(fixnum? n) e1] ;; e1 executed 3 times
  [(flonum? n) e2] ;; e2 executed 8 times
  [(bignum? n) e3] ;; e3 executed 5 times
  [else (error "something bad happened")])
]
@racketblock[
(cond
  [(flonum? n) e2]
  [(bignum? n) e3]
  [(fixnum? n) e1]
  [else (error "something bad happened")])
]]

@Figure-ref{exclusive-cond-expansion} shows an example of
@racket[exclusive-cond] and the code to which it expands. In this
example, we assume @racket[e1] is executed 3 times, @racket[e2] is
executed 8 times, and @racket[e3] is executed 5 times.

@subsubsection{case}
@; How does case work
@racket[case] pattern matching construct that is easily given profile
directed optimization by implementing it in terms of
@racket[exclusive-cond]. @racket[case] takes an expression
@racket[key-expr] and an arbitrary number of clauses, followed by an
optional @racket[else] clause. The left-hand side of each clause is a
list of constants. @racket[case] executes the right-hand side of the
first clause in which @racket[key-expr] is @racket[eqv?] to some element
of the left-hand. If @racket[key-expr] is not @racket[eqv?] to any
element of any left-hand side, then the right-hand side of the
@racket[else] clause is executed if an @racket[else] clause exists.

@figure-here["case-example"
        (elem "an example of a " @racket[case] " expression")
@racketblock[
(case x
  [(1 2 3) e1]
  [(3 4 5) e2]
  [else e3])
]]

@Figure-ref{case-example} shows an example @racket[case] expression. If
@racket[x] is 1, 2, or 3, then @racket[e1] is executed. If @racket[x] is
4 or 5, then @racket[e2] is executed. Note that while 3 appears in
the second clause, if @racket[x] is 3 then @racket[e1] will be
evaluated. The first occurrence always take precedence. 

@; How are clauses parsed
Since @racket[case] permits clauses to have overlapping elements and uses
order to determine which branch to take, we must remove overlapping elements
before clauses can be reordered. Each clause is parsed into the set of
left-hand side keys and right-hand side bodies. Overlapping keys are
removed by keeping only the first instance of each key when processing
the clauses in the original order. After removing overlapping keys, an
@racket[exclusive-cond] is generated. 

@figure-here["case-expansion"
        (elem "how the previous example expands to " @racket[exclusive-cond])
@racketblock[
(exclusive-cond x
  [(memv x (1 2 3)) e1]
  [(memv x (4 5)) e2]
  [else e3])
]]

@Figure-ref{case-expansion} shows how the example @racket[case]
expression from @figure-ref{case-example} expands into
@racket[exclusive-cond]. Note the duplicate 3 in the second clause is
dropped to preserve ordering constraints from @racket[case].

@subsection{Loop Unrolling}
Loop unrolling is a standard compiler optimizations.  However, striking
a balance between code growth and speed is tricky. By using profile
information, the compiler can focus on the most executed loops.  

Some of Scheme's basic loop constructs are simple macros, so we
demonstrate loop unrolling using macros. Profile directed loop unrolling
could be done using block-level profile information. However, loop
unrolling at the block-level requires associating loops with basic
blocks and cannot easily handle arbitrary recursive functions. As this
example shows, doing loop unrolling as a macro is simple and can easily
handle recursive functions. 

Note that in our implementation, we wait until after macro expansion
to do profile directed loop unrolling. We pass the source-level profile
information associated with function calls through the compiler, but wait
until many more loops can be exposed than only those created by a single
macro. @todo{This paragraph seems out of place.}

@; Explain a basic let-loop
A loop can be written using a named let in Scheme, as shown in
@figure-ref{fact5}. This defines a recursive function @racket[fact] and
calls it with the argument @racket[5]. This named let might normally be
implemented using @racket[letrec] as seen in @figure-ref{named-let-simple}.

@figure-here["fact5"
        "an example loop written with a named let";;"the most commonly written loop in all of computer science"
@racketblock[
(let fact ([n 5])
  (if (zero? n)
      1
      (* n (fact (sub1 n)))))]]

@figure-here["named-let-simple"
        "a simple definition of a named let"
@racketblock[
(define-syntax let
  (syntax-rules ()
    [(_ name ([x e] ...) body1 body2 ...)
     ((letrec ([name (lambda (x ...) body1 body2 ...)])) e ...)]i
    #;[(_ ([x e] ...) body1 body2 ...)
     ((lambda (x ...) body1 body2 ...) e ...)]))
]]

@figure-here["named-let"
        "a macro that does profile directed loop unrolling"
@racketblock[#:escape srsly-unsyntax
(define-syntax named-let
  (lambda (x)
    (syntax-case x ()
      [(_ name ([x e] ...) b1 b2 ...)
       #`((letrec ([tmp (lambda (x ...)
             #,(let* ([profile-weight 
                        (or (profile-query-weight #'b1) 0)]
                      [unroll-limit 
                        (+ 1 (* 3 (/ profile-weight 1000)))])
                 #`(define-syntax name
                     (let ([count #,unroll-limit]
                           [weight #,profile-weight])
                       (lambda (q)
                         (syntax-case q ()
                           [(_ enew (... ...))
                             (if (or (= count 0)
                                     (< weight 100))
                                 #'(tmp enew (... ...))
                                 (begin
                                   (set! count (- count 1))
                                   #'((lambda (x ...) b1 b2 ...) 
                                      enew (... ...))))])))))
             b1 b2 ...)])
            tmp)
          e ...)])))]]

@; Explain how to do a profile directed named let unrolling
@racket[named-let] (@figure-ref{named-let}) defines a macro that unrolls
the body of the loop between 1 and 3 times, depending on profile
information. The macro uses profile information associated with the body
of the loop to determine how frequently the loop is executed. Loops
that take up less than 10% of the max execution count are not unrolled
at all. If a loop is executed 100% of the max execution count, then it
may be unrolled 3 times. Note that in @racket[named-let] the name of the
loop is not assignable, as it is in the standard Scheme named let.

@; Explain multiple call sites
Note that in this macro, @emph{each} call site is unrolled the same
number of times. A named-let may have multiple recursive calls, some of
which may be more frequently used than others. A more clever macro could
unroll each call site a different number of times, depending on how many
times that particular call is executed. This would allow more fine grain
control over code growth.

Similar macros are easy to write for @racket[do] loops, and even
@racket[letrec] to unroll general recursive functions. Note that even in
the @racket[named-let] example, call to the loop do not need to be tail
calls. This simple example demonstrates unrolling recursive
functions and not only loops.
@todo{I don't like that paragraph}

@subsection{Data type Selection}
@; Motivate an example that normal compilers just can't do
The previous optimizations focus on low level changes that can improve
code performance. Reordering clauses of a @racket[cond] can improve
speed by maximizing straight-line code emitted later in the compiler.
Loop unrolling can reduce overhead associate with loops and maximize
straight-line code emitted later in the compiler. While profile directed
meta-programming enables more of such low level optimizations, it
also enables higher level decisions normally done by the programmer

@figure-here["sequence-datatype"
        "a macro that defines a sequence datatype based on profile information"
@racketblock[ #:escape srsly-unsyntax
(define-syntax define-sequence-datatype
  (let ([ht (make-eq-hashtable)])
    (define args
      `((seq? . #'(x))
        (seq-map . #'(f s))
        (seq-first . #'(s))
        (seq-ref . #'(s n))
        (seq-set! . #'(s i obj))) )
    (define defs 
      `((make-seq . (,#'list . ,#'vector))
        (seq? . (,#'list? . ,#'vector?))
        (seq-map . (,#'map . ,#'for-each))
        (seq-first . (,#'car . ,#'(lambda (x) (vector-ref x 0))))
        (seq-ref . (,#'list-ref . ,#'vector-ref))
        (seq-set! . (,#'(lambda (ls n obj) (set-car! (list-tail ls n) obj)) . ,#'vector-set!))))
    (define (choose-args name)
      (cond 
        [(assq name defs) => cdr]
        [else (syntax-error name "not a valid sequence method:")]))
    (define (choose name)
      (let ([seq-set!-count (hashtable-ref ht 'seq-set! 0)]
            [seq-ref-count (hashtable-ref ht 'seq-ref 0)]
            [seq-first-count (hashtable-ref ht 'seq-first 0)]
            [seq-map-count (hashtable-ref ht 'seq-map 0)])
      (cond 
        [(assq name defs) => 
          (lambda (x)
            (let ([x (cdr x)])
              (if (> (+ seq-set!-count seq-ref-count) (+ seq-first-count seq-map-count))
                  (cdr x)
                  (car x))))]
        [else (syntax-error name "not a valid sequence method:")])))
    (lambda (x)
      (syntax-case x ()
        [(_ var (init* ...) name* ...)
         (for-each 
           (lambda (name) (hashtable-set! ht name (or (profile-query-weight name) 0)))
           (map syntax->datum #'(name* ...)))
         (with-syntax ([(body* ...) (map (lambda (name) (choose (syntax->datum name))) #'(name* ...))]
                       [(args* ...) (map (lambda (args) (choose-args (syntax->datum name))) #'(name* ...))])
           #`(begin (define (name* args* ...) (begin name* (body* args* ...))) ...
                    (define var (#,(choose 'make-seq) init* ...))))]))))
]]

@; Introduce example
Consider a program in which a sequence is obviously required, but which
data structure is best used to implement the sequence is not obvious.
This example shows how to choose the implementation based on profile
information. The example in @figure-ref{sequence-datatype} chooses
between a list and a vector. If @racket[seq-set!] and @racket[seq-ref]
operations are used more often than @racket[seq-map] and
@racket[seq-first] then a @racket[vector] is used, otherwise a
@racket[list] is used.

@figure-here["seq1-example"
        "an example use of the define-sequence-datatype macro"
@racketblock[
(define-sequence-datatype seq1 (0 0 0 0)
  seq? 
  seq-map 
  seq-first 
  seq-ref 
  seq-set!)
]]

@; Discuss quirks in example implementation
@Figure-ref{seq1-example} demonstrates the usage of the
@racket[define-sequence-datatype] macro. The macro requires the names of
the sequence functions to be given.  The unique source information
attached to each name is used to profile the operations of that
@emph{particular} sequence. The definitions of each operation evaluate
the name to ensure function inlining does not distort profile counts. A
clever compiler might try to throw out the effect-free reference to
@racket[name] in the body of each operation, so this implementation is
fragile.
