# Overview

H2Odin generates Odin bindings from C headers. It reads a header with libclang, builds its own description of what the header contains, and writes Odin source that lets you call the C library.

This document explains the *spirit* of the project. It is meant to orient you, not to constrain you.

## What we are optimizing for

**Simple code.** Not a simple tool — a simple *codebase*. H2Odin should be easy to read and easy to contribute to. Someone who has never seen the project should be able to open a stage, understand what goes in and what comes out, and submit a fix without learning a web of abstractions first. The generator itself can be capable and robust; the code that makes it so should stay plain.

**Correctness over convenience.** When H2Odin can produce a nicer-looking binding but doing so risks changing behavior or breaking the C ABI, it does not. A binding that is honest and slightly less pretty beats a binding that looks native but lies.

**Determinism.** The same headers and the same configuration should always produce the same output. This is a property we care about protecting as the project grows.

**Honesty about uncertainty.** C headers do not always contain enough information to know the right answer. When that happens, H2Odin should pick a conservative default, make it visible that this was a guess, and let the configuration correct it — rather than silently pretending it knew.

## The one rule of thumb worth internalizing

Much of the design follows from a single question:

> Can this be *proven* from the header and the target alone?

If yes, the generator can do it automatically. If it depends on what the library *means* — knowledge that lives in a human's head, not in the types — then it belongs in the configuration, where a person supplies that knowledge. The generator owns *how* things are done; the configuration only chooses *what* to do and *where*.

Keeping that line clear is what lets H2Odin be automatic where it safely can be, and configurable everywhere else, without the two blurring together.

## A data-oriented tool

Odin is a data-oriented language, and H2Odin is a data-oriented tool. The generator is a short sequence of passes that move plain data from one shape to the next. There is no hidden behavior attached to the data — the data is just data, and the code that transforms it is separate and visible. If you find yourself reaching for cleverness, it is worth asking whether a plainer data-shaped approach would read better to the next contributor.
