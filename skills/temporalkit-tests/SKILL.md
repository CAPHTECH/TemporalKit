---
name: temporalkit-tests
description: >-
  Write tests for the TemporalKit LTL library WITHOUT reading the source first.
  Hands over the library-specific facts the bare model gets wrong from memory:
  the exact normalized()/NNF rewrite forms, PropositionID/proposition
  construction, the per-directory test framework, and the model-checking setup.
  Use when adding or editing tests under Tests/TemporalKitTests for LTLFormula,
  normalized(), LTLModelChecker / KripkeStructure, trace evaluation, or the DSL.
---

# Writing TemporalKit tests

This skill exists so you can write **correct, compiling, passing** TemporalKit
tests fast, from the facts below, without grepping `Sources/`. It encodes only
the things a from-memory attempt measurably gets wrong (verified by running):
the `normalized()` rewrite forms, `PropositionID` construction, and the
framework-per-directory rule. Everything else (enum case names, `check`
signature, counterexample shape) the model already gets right — don't overthink it.

Full signatures and the complete rewrite table: **[references/api-and-semantics.md](references/api-and-semantics.md).** Read it before asserting any `normalized()` output.

## Required output structure

A TemporalKit test file must have, in order:

1. **Correct framework import for the directory it lives in** (see rule below).
2. A **concrete proposition type** — almost always
   `ClosureTemporalProposition<State, Bool>` built via
   `TemporalKit.makeProposition(id: "p", name: "p") { (_: State) in true }`.
   `id:` is a **`String`**, not a `PropositionID`.
3. **Exact expected values** for any `normalized()` assertion, taken from the
   rewrite table — not from textbook LTL duality.
4. For model-checking: a `KripkeStructure` whose `atomicPropositionsTrue(in:)`
   returns `Set<PropositionID>` built from **`prop.id`** (never a string literal),
   and `typealias AtomicPropositionIdentifier = PropositionID`.

## The three things to get right (each with both failure modes)

### 1. Framework: match the directory, don't globally pick one
- Tests under `ModelChecking/` (and `PerformanceTests`) use **XCTest**
  (`import XCTest`, `final class … : XCTestCase`, `XCTAssertEqual`, `func test…() throws`).
- Everything else — `Core/`, `Formulas/`, `Evaluation/`, `DSL/`, `Errors/` — uses
  **swift-testing** (`import Testing`, `struct`, `@Test`, `#expect`).
- Failure modes to avoid: (a) defaulting the whole repo to XCTest — a
  `normalized()` test belongs in the swift-testing world; (b) imposing
  swift-testing when *extending an existing XCTest file* — match the file you edit.

### 2. `normalized()`: use TemporalKit's forms, not standard duality
The single biggest from-memory error. TemporalKit's negated-temporal rewrites are
**not** the textbook `¬(A U B) ≡ ¬A R ¬B`. The actual forms (full table in the
reference):
- `¬(A U B)` → `(¬A ∧ ¬B) R ¬B`   (NOT `¬A R ¬B`)
- `¬(A R B)` → `¬B U (¬A ∧ ¬B)`   (NOT `¬A U ¬B`)
- `¬(A W B)` → `¬B U (¬A ∧ ¬B)`
- Constant collapses are specific too, e.g. `A W false` → `G A`, `false R B` → `G B`.

Don't over-claim simplification either: `normalized()` is NNF + the listed
boolean/temporal-constant rules and `F F`/`G G` idempotency — it does **not**
distribute, flatten associativity, or simplify across unrelated subformulas.
If unsure of a form, assert a structural property (e.g. "contains no `.implies`",
or idempotency `f.normalized() == f.normalized().normalized()`) instead of guessing.

### 3. `PropositionID` is `RawRepresentable`, not string-literal
- Build with `PropositionID(rawValue: "p")!` (failable init) when you need one
  directly; but prefer `prop.id`.
- `Set<PropositionID>` literals like `["p"]` **do not compile** (no
  `ExpressibleByStringLiteral`). In a labeling function return `[prop.id]`.
- `makeProposition(id:name:evaluate:)` takes `id:` as a **`String`** — pass `"p"`,
  not `PropositionID(...)`.

## Linux CI gate
Linux CI pins **Swift 6.0** (macOS uses latest). Avoid 6.1+-only syntax: no
trailing commas in argument/collection lists, no `#expect` nested inside a
`throws:` closure. (Same constraint recorded in session memory.)
