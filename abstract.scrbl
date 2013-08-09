#lang scribble/sigplan
@abstract{Profile guided optimization is a compiler technique that uses sample data
gathered at run-time to recompile and further optimize a program. The profile
data can be more accurate than heuristics normally used in a compiler and thus
can lead to more optimized code. 

Modern languages such as Haskell, C++, and Scheme provide powerful
meta-programming facilities that help programmers create generic
libraries programs, new language constructs, or even domain specific
languages. This paper presents a method for writing optimizing
metaprograms by taking advantage of profile information. The technique
is implemented and used in a high-performance implementation of Scheme.}
