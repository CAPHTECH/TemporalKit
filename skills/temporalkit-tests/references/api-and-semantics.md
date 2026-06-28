# TemporalKit test-author reference

Exact, source-derived facts for writing tests without reopening `Sources/`.
All `swift-testing`/`XCTest` examples are interchangeable; pick per the
directory rule in SKILL.md.

## Core types

```swift
// Sources/TemporalKit/Core/LTLFormula.swift
public indirect enum LTLFormula<P: TemporalProposition>: Hashable where P.Value == Bool {
    case booleanLiteral(Bool)
    case atomic(P)
    case not(LTLFormula<P>)
    case and(LTLFormula<P>, LTLFormula<P>)
    case or(LTLFormula<P>, LTLFormula<P>)
    case implies(LTLFormula<P>, LTLFormula<P>)
    case next(LTLFormula<P>)
    case eventually(LTLFormula<P>)
    case globally(LTLFormula<P>)
    case until(LTLFormula<P>, LTLFormula<P>)
    case weakUntil(LTLFormula<P>, LTLFormula<P>)
    case release(LTLFormula<P>, LTLFormula<P>)
}
// Equality is STRUCTURAL. Two `.atomic` are equal iff their propositions are
// equal, and proposition equality is by `id` only — the evaluate closure is
// irrelevant to equality.
```

```swift
// TemporalProposition: AnyObject, Hashable, Identifiable
//   var id: PropositionID ; var name: String
//   func evaluate(in context: EvaluationContext) throws -> Value   (Value == Bool here)

// PropositionID: Hashable, Equatable, RawRepresentable, Codable, Sendable
//   init?(rawValue: String)          // FAILABLE — use `!` in tests: PropositionID(rawValue: "p")!
//   init(validating: String) throws
// NOT ExpressibleByStringLiteral → `let s: Set<PropositionID> = ["p"]` does NOT compile.

// Build propositions with the factory (note: id is a String):
public func makeProposition<S, R: Hashable>(
    id: String, name: String, evaluate: @escaping @Sendable (S) -> R
) -> ClosureTemporalProposition<S, R>
// e.g. let p = TemporalKit.makeProposition(id: "p", name: "p") { (_: Int) in true }
//   →  p has type ClosureTemporalProposition<Int, Bool>, p.id is PropositionID("p")
```

Typealiases that read well in a test file:
```swift
typealias Prop = ClosureTemporalProposition<Int, Bool>   // any Hashable State works
typealias F = LTLFormula<Prop>
```

## `normalized()` — the exact rewrite table

`normalized()` returns NNF via a fixed-point of three passes
(eliminate implications → push negations inward → simplify constants). It applies
ONLY the rules below; it does not distribute, reassociate, or simplify unrelated
subformulas.

**Implication**
- `A → B`  ⇒  `¬A ∨ B`   (recursively, everywhere)

**Negation push (De Morgan + dualities)**
- `¬¬A` ⇒ `A`   ·   `¬true` ⇒ `false`   ·   `¬false` ⇒ `true`
- `¬(A ∧ B)` ⇒ `¬A ∨ ¬B`   ·   `¬(A ∨ B)` ⇒ `¬A ∧ ¬B`
- `¬X A` ⇒ `X ¬A`
- `¬F A` ⇒ `G ¬A`   ·   `¬G A` ⇒ `F ¬A`
- `¬(A U B)` ⇒ **`(¬A ∧ ¬B) R ¬B`**   ← not `¬A R ¬B`
- `¬(A R B)` ⇒ **`¬B U (¬A ∧ ¬B)`**   ← not `¬A U ¬B`
- `¬(A W B)` ⇒ **`¬B U (¬A ∧ ¬B)`**
- `¬p` (p atomic) ⇒ stays `¬p`

**Constant / idempotency simplification**
- `and`: `false ∧ _` ⇒ `false`; `_ ∧ false` ⇒ `false`; `true ∧ X` ⇒ `X`; `X ∧ true` ⇒ `X`;
  `X ∧ X` ⇒ `X`; `X ∧ ¬X` ⇒ `false`
- `or`: `true ∨ _` ⇒ `true`; `_ ∨ true` ⇒ `true`; `false ∨ X` ⇒ `X`; `X ∨ false` ⇒ `X`;
  `X ∨ X` ⇒ `X`; `X ∨ ¬X` ⇒ `true`
- `next`: `X(true)` ⇒ `true`; `X(false)` ⇒ `false`
- `eventually`: `F(true)` ⇒ `true`; `F(false)` ⇒ `false`; `F(F A)` ⇒ `F A`
- `globally`: `G(true)` ⇒ `true`; `G(false)` ⇒ `false`; `G(G A)` ⇒ `G A`
- `until`: `A U true` ⇒ `true`; `A U false` ⇒ `false`; `false U B` ⇒ `B`
- `weakUntil`: `A W true` ⇒ `true`; `A W false` ⇒ `G A`; `false W B` ⇒ `B`
- `release`: `false R B` ⇒ `G B`; `true R B` ⇒ `B`; `A R false` ⇒ `false`; `A R true` ⇒ `true`

Worked examples (all verified to pass):
```swift
F.not(.until(p, q)).normalized()  == .release(.and(.not(p), .not(q)), .not(q))
F.not(.release(p, q)).normalized() == .until(.not(q), .and(.not(p), .not(q)))
F.weakUntil(p, .booleanLiteral(false)).normalized() == .globally(p)
F.not(.implies(p, q)).normalized() == .and(p, .not(q))
```

When the exact form is uncertain, assert a **property** instead of an equality:
```swift
#expect(once.normalized() == once)                 // idempotent
#expect(!containsImplication(f.normalized()))      // implications eliminated
```

## Model checking

```swift
public final class LTLModelChecker<Model: KripkeStructure> {
    public init()
    public func check<P: TemporalProposition>(formula: LTLFormula<P>, model: Model)
        throws -> ModelCheckResult<Model.State>
        where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool
}

public protocol KripkeStructure {
    associatedtype State: Hashable
    associatedtype AtomicPropositionIdentifier: Hashable     // use PropositionID
    var allStates: Set<State> { get }
    var initialStates: Set<State> { get }
    func successors(of state: State) -> Set<State>
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier>
}

public enum ModelCheckResult<State: Hashable> {
    case holds
    case fails(counterexample: Counterexample<State>)   // .holds is a CASE, do not add a `var holds`
}
public struct Counterexample<State: Hashable> {
    public let prefix: [State]   // lasso prefix
    public let cycle: [State]    // repeating cycle
}
```

**Key semantic fact:** for *model checking*, whether an atom holds in a state is
decided by `model.atomicPropositionsTrue(in:)` (the labeling), matched against
`prop.id`. The proposition's `evaluate` closure is ignored here — make it a dummy
`{ _ in true }`. (In contrast, *trace evaluation* via `LTLFormula.evaluate`/
`LTLFormulaTraceEvaluator` DOES use the closure.)

Minimal model-checking test skeleton:
```swift
struct M: KripkeStructure {
    typealias State = Int
    typealias AtomicPropositionIdentifier = PropositionID
    let allStates: Set<Int>; let initialStates: Set<Int>
    let edges: [Int: Set<Int>]; let pTrue: Set<Int>; let pID: PropositionID
    func successors(of s: Int) -> Set<Int> { edges[s] ?? [] }
    func atomicPropositionsTrue(in s: Int) -> Set<PropositionID> { pTrue.contains(s) ? [pID] : [] }
}
let p = TemporalKit.makeProposition(id: "p", name: "p") { (_: Int) in true }
let gp: LTLFormula<ClosureTemporalProposition<Int, Bool>> = .globally(.atomic(p))
let result = try LTLModelChecker<M>().check(formula: gp, model: m)
// switch on result { case .holds / case .fails(let cex): cex.prefix, cex.cycle }
```

## DSL operators (optional, for readability)
`!` (not) · `&&` (and) · `||` (or) · `==>` (implies) · `~>>` (until) ·
`~~>` (weakUntil) · `~<` (release) · `LTLFormula.X/.F/.G(_)` ·
methods `.until/.weakUntil/.release/.implies(_)`.
