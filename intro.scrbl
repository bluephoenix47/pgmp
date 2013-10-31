#lang scribble/base
@(require scribble/manual)
@(require "defs.rkt")
@(require "bib.rkt")
@title[#:tag "intro" "Introduction"]
@; Introduce meta-programming
Meta-programming is a technique for creating programs by defining
meta-language constructs that generate programs in a source language.
Many languages have some kind of meta-programming; C preprocessor macros,
C++ templates, Template Haskell, Scheme macros, and MetaML are all
examples of meta-programming@~cite[taha00 erdweg11 czarnecki04 sheard02
dybvig93]. Not all constructs in the meta-language will have an
equivalent construct with the same expressivity in the source language.
The translation from meta-language to source-language will necessarily
impose additional restrictions not specified in the original program.
That is, the compiler operating on the generated source-program has to
make optimization decisions based on an overspecification of the orignal
program and has less flexibility when optimizing. 

For instance, Scheme's @racket[case] construct (similar to C's
@racket[switch] statement) is a meta-program that generates a series of
@racket[if] statements. However, @racket[case] does not imposes a specific
order of execution for clauses, while a series of @racket[if] statement's
does. The meta-program could take advantage of @racket[case]'s
unspecified order of execution to reorder the clauses based on profile
information, while optimizations done on the generate source program
could do no such optimization. More generally, meta-programmers
implementing abstract libraries, such as Boost@todo{Cite?}, and new
languages, such as Typed Racket @todo{felleisen04, tobin-hochstadt06,
tobin-hochstadt11}, could take advantage of flexibility at the
meta-language level to implement optimizations that would be impossible
for a compiler at the source-level language. To do this,
meta-programmers need the same techniques and tools to generate
source-language code that compiler writers use to generate machine
code.

@; NB: What is profile directed optimization?
Profile-directed optimization is a compiler technique that uses
data gathered at run-time on representative inputs to recompile and
generate optimized code. The code generated by this recompilation
usually exhibits improved performance on that class of inputs than the
code generate with static optimization heuristics. For instance, a
compiler can decide exactly how many times a loop should be unrolled if
it has exact execution counts for the loop instead of guessing based on
static heuristics. Many compilers such as .NET, GCC, and LLVM use
profile directed optimizations. The profile information used by these
compilers, such as execution counts of basic blocks or control flow
graph nodes, is low-level compared to the source-language operated on by
meta-programs. So the optimizations that use the profile information are
also performed on low-level constructs. Common optimizations include
reordering basic blocks, inlining decisions, conditional branch
optimization, and function layout decisions. 

These low-level optimizations are important, but the low-level profile
information is useless at the meta-language level. If the profile
information is gathered by profiling basic blocks which don't exist in
the meta-language, clearly a meta-program cannot use this `block-level'
profiling information. Existing techniques that use profile information
at the level of the source language, i.e. `source-level' information,
introduce a layer of tooling support between the profile information and
the compiler@todo{Cite 1, 2 from Swahah, stuff from related work}.
These tools are essentially highly specialized meta-programs.  However,
the source-level information is unusable to the compiler and unavailable
to the meta-language. So this extra layer reproduces the profiling
effort of the compiler and does not help meta-programmers in general.
Instead, it's up to the programmer to use source-level information to
optimize code @emph{by hand} in the general case.

@; To motivate why these low level optimizations are not enough, and
@; demonstrate our framework, we consider three problems that the writer of
@; a domain-specific language (DSL) or DSL library writer might want to
@; solve. First we consider the standard technique of loop unrolling and
@; demonstrate unrolling loops and general recursive functions based on
@; profile information. Next we consider the problem of inline caching for
@; a DSL with objects and demonstrate reordering clauses of a generic
@; branching construct based on profile information. Finally we consider
@; the EDSL library writer with users that don't understand enough about
@; data structures to pick the write collection, and demonstrate datatype
@; specialization based on profile information. 
@; 
@; 
@; First we consider the standard technique of loop unrolling and
@; demonstrate unrolling loops and general recursive functions based on
@; profile information. While loops can be unrolled using traditional low
@; level profile information, we show the fine granularity of source level
@; information makes this problem trivial.
@; 
@; Next we consider the problem of inline caching for a DSL with objects
@; and demonstrate reordering clauses of a generic branching construct
@; based on profile information.  
@; 
@; Finally we consider the EDSL library writer with users that don't
@; understand enough about data structures to pick the write collection,
@; and demonstrate datatype specialization based on profile information. 

@; NB: How do we advance the state of the art?
We present a technique for collecting and using per source-expression
profile information directly in a compiler. This source-level
information is available to the meta-language so meta-programs can
perform high-level profile-directed optimizations. The profile information
is also available during run-time, enabling profile-directed run-time
decisions. Our technique also addresses combining source-level
information from multiple execution profiles, and performing both
source-level and block-level profile-directed optimizations on the same
program.

The reminder of the paper is organized as follows. @Secref{design}
presents the design of our system at a high level and discusses how
it could be implemented in other meta-programming systems. @Secref{examples}
demonstrates how to use our technique to implement several
optimizations as meta-programs. @Secref{implementation} discusses how
we implement this technique in the Chez Scheme compiler.
