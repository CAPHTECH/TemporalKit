# TemporalKit

TemporalKit is a Swift library for working with temporal logic, particularly Linear Temporal Logic (LTL). It provides a type-safe, composable, and Swift-idiomatic way to express and evaluate temporal logic formulas, and to perform LTL model checking.

## Features

- **Type-safe representation** of Linear Temporal Logic (LTL) formulas
- **Swift-idiomatic DSL** for constructing formulas with natural syntax
- **Extensible architecture** designed to support multiple temporal logic systems
- **Evaluation engine** for checking formulas against traces (sequences of states)
- **Formula normalization** to simplify and optimize expressions
- **Advanced LTL Model Checking**: Verification of LTL formulas against system models (Kripke structures) using Büchi automata. This includes:
  - Translation of LTL formulas to Büchi Automata.
  - Construction of product automata between a model and a formula automaton.
  - Optimized emptiness checking of Büchi automata using Nested DFS with improved handling of acceptance cycles.
  - Enhanced GBA (Generalized Büchi Automata) condition generation with special case handling for Release operators.
  - Robust handling of terminal states and self-loops in model structures.
- **State Space Representation**: Protocols and structures for defining system models, specifically `KripkeStructure`.
- **Büchi Automaton Implementation**: A representation for Büchi automata, used internally for model checking.
- **Comprehensive Test Suite**: Extensive testing covering:
  - Edge cases (self-loops, terminal states, multiple acceptance paths)
  - Complex LTL expressions with deeply nested operators
  - Random formula and structure generation for robustness testing
  - Performance benchmarks for key algorithms
- **Comprehensive examples** demonstrating trace evaluation and model checking.

## Documentation

For detailed information about TemporalKit, see the following documentation:

- [**Edge Case Handling**](Docs/EdgeCaseHandling.md): Explains how TemporalKit handles challenging scenarios such as self-loops, terminal states, and special cases for Release operators.
- [**Testing Guide**](Docs/TestingGuide.md): Describes the testing framework, test categories, and how to run and interpret tests.
- [**Performance Guide**](Docs/PerformanceGuide.md): Details performance characteristics, optimization strategies, and known limitations.

## Installation

### Swift Package Manager

Add TemporalKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/TemporalKit.git", from: "1.0.0") // Replace with actual URL and version
]
```

## Basic Concepts

### Temporal Logic

Temporal logic extends classical logic with operators that refer to time. Linear Temporal Logic (LTL) specifically deals with a linear path of time (a sequence of states).

Key LTL operators:

- `X p` / `.next(.atomic(p))`: Next - p holds at the next time step
- `F p` / `.eventually(.atomic(p))`: Eventually - p holds at some future time step
- `G p` / `.globally(.atomic(p))`: Always - p holds at all future time steps
- `p U q` / `.until(.atomic(p), .atomic(q))`: Until - p holds until q holds
- `p W q` / `.weakUntil(.atomic(p), .atomic(q))`: Weak Until - p holds until q holds, or p holds forever
- `p R q` / `.release(.atomic(p), .atomic(q))`: Release - q holds until and including when p holds

### Using TemporalKit

#### 1. Define Propositions

Propositions are statements about the system state that can be true or false.

```swift
// For Trace Evaluation (example from Demo)
let isLoggedIn_trace = TemporalKit.makeProposition(
    id: "isUserLoggedInFunc",
    name: "User is logged in (Functional)",
    evaluate: { (appState: AppState) in appState.isUserLoggedIn }
)

// For Model Checking (example from Demo)
public let p_kripke = TemporalKit.makeProposition(
    id: "p_kripke", 
    name: "p (for Kripke)", 
    evaluate: { (state: DemoKripkeModelState) -> Bool in state == .s0 || state == .s2 }
)
```

#### 2. Create Evaluation Contexts (for Trace Evaluation)

Define a context that provides the necessary information to evaluate propositions over a trace.

```swift
struct AppEvaluationContext: EvaluationContext { /* ... see Demo ... */ }
```

#### 3. Define a Kripke Structure (for Model Checking)

Implement the `KripkeStructure` protocol to define your system model.

```swift
public struct DemoKripkeStructure: KripkeStructure {
    public typealias State = DemoKripkeModelState
    public typealias AtomicPropositionIdentifier = PropositionID

    public let initialStates: Set<State> = [.s0]
    public let allStates: Set<State> = [.s0, .s1, .s2]

    public func successors(of state: State) -> Set<State> { /* ... transitions ... */ }
    public func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> { /* ... state labeling ... */ }
}
```

#### 4. Construct Formulas

Use the Swift-friendly DSL to construct temporal logic formulas. The proposition type in the formula must match the context or model.

```swift
// For Trace Evaluation
typealias DemoLTLProposition = TemporalKit.ClosureTemporalProposition<AppState, Bool>
let eventuallyLoggedIn: LTLFormula<DemoLTLProposition> = .eventually(.atomic(isLoggedIn_trace))

// For Model Checking
typealias KripkeDemoProposition = TemporalKit.ClosureTemporalProposition<DemoKripkeModelState, Bool>
let formula_Gp_kripke: LTLFormula<KripkeDemoProposition> = .globally(.atomic(p_kripke))
```

#### 5. Evaluate Formulas or Perform Model Checking

**Trace Evaluation:**

```swift
let trace: [AppState] = [/* ... sequence of AppStates ... */]
let evaluator = LTLFormulaTraceEvaluator<DemoLTLProposition>()
let result = try evaluator.evaluate(formula: eventuallyLoggedIn, trace: trace, contextProvider: contextFor)
print("Formula holds on trace: \(result)")
```

**Model Checking:**

```swift
let modelChecker = LTLModelChecker<DemoKripkeStructure>()
let kripkeModel = DemoKripkeStructure()
let checkResult = try modelChecker.check(formula: formula_Gp_kripke, model: kripkeModel)

switch checkResult {
case .holds:
    print("Formula HOLDS for the model.")
case .fails(let counterexample):
    print("Formula FAILS. Counterexample: \(counterexample.infinitePathDescription)")
}
```

## Examples

See the `Sources/TemporalKitDemo` directory for complete examples of using the library, including both trace evaluation and LTL model checking.

## Performance Characteristics

TemporalKit is designed for good performance on practical model checking problems. Based on benchmarks:

- **NestedDFS Algorithm**: Handles 100-state structures in ~73ms
- **GBAConditionGenerator**: Processes complex nested formulas in sub-millisecond time (~0.2ms)
- **Scaling**: Performance scales roughly linearly with state space size for practical models

See the [Performance Guide](Docs/PerformanceGuide.md) for detailed benchmark results and optimization strategies.

## Architecture

TemporalKit is designed with the following key components:

- **Core protocols**: `EvaluationContext`, `TemporalProposition`, `KripkeStructure`.
- **Formula representation**: `LTLFormula` enum.
- **DSL**: Operator overloads and helper methods.
- **Evaluation**: Step-wise and trace-based evaluation of formulas.
- **Normalization**: Simplification and standardization of formulas.
- **Model Checking Engine**:
  - `LTLToBuchiConverter`: Translates LTL to Büchi automata.
  - `GBAConditionGenerator`: Generates acceptance conditions for GBA with optimized handling for Release operators.
  - `GBAToBAConverter`: Supports conversion from Generalized Büchi Automata to standard BA.
  - `TableauGraphConstructor`: Core of the LTL to GBA tableau construction.
  - `NestedDFSAlgorithm`: Checks Büchi automaton emptiness with improved acceptance cycle detection.
  - `LTLModelChecker`: Orchestrates the model checking process.
  - `BuchiAutomaton`: Represents Büchi automata.
  - `ProductState`: Used in product automaton construction.

## Recent Improvements

This version includes significant algorithm improvements:

1. **NestedDFS Algorithm Enhancement**:
   - Improved acceptance cycle detection accuracy
   - Optimized handling of "p U r" formula evaluation
   - Enhanced debugging capabilities

2. **GBAConditionGenerator Optimization**:
   - Special case handling for Release operators (R)
   - Efficient acceptance condition generation
   - Fixed handling of empty liveness subformulas

3. **Expanded Test Suite**:
   - Edge case tests for self-loops, terminal states, and multiple acceptance paths
   - Complex LTL formula tests with deeply nested operators
   - Random generation tests for formula and structure robustness validation
   - Performance benchmarks for key algorithms

## License

TemporalKit is available under the MIT license. See the LICENSE file for more info.

## Future Enhancements

We are considering the following enhancements for the TemporalKit project:

- **Expansion of Supported Logics**:
  - **CTL (Computation Tree Logic) Support**: Introduce CTL for branching-time properties.
  - **Past LTL Operators**: Add past-time operators (e.g., Yesterday (Y)).
  - **Metric/Timed Temporal Logics (MTL/TPTL)**: Explore support for precise time constraints.

- **Further Enhancements to Model Checking Features**:
  - **Advanced Algorithms**: Investigate on-the-fly model checking, symbolic model checking (e.g., using BDDs/SMT solvers) for improved performance and scalability with larger state spaces.
  - **Richer Model Representations**: Support for more complex or specialized system model representations beyond basic Kripke structures (e.g., timed automata, Petri nets interface).
  - **Counterexample Refinement & Analysis**: Provide more detailed, potentially interactive, analysis tools for counterexamples.
  - **Abstraction Techniques**: Implement abstraction methods (e.g., predicate abstraction) to handle larger systems.

- **Enhancement of Usability and DSL**:
  - **Property Specification Patterns**: Introduce high-level patterns and macros for common properties (e.g., Dwyer's patterns: Absence, Existence, Universality, Precedence, Response).
  - **Improved Diagnostic Information**: Enhance error messages and presentation of counterexamples.
  - **Visualization Tools**: Consider tools for visualizing Kripke structures, Büchi automata, and counterexample paths.
  - **Expansion of Documentation and Tutorials**: Provide comprehensive documentation, tutorials, and diverse usage examples.

- **Performance and Extensibility**:
  - **Ongoing Optimization**: Continuously optimize existing algorithms.
  - **Modular Architecture**: Maintain and improve architectural flexibility for integrating new logics and algorithms.

- **Expansion of Application Scope**:
  - **Runtime Verification**: Develop capabilities for monitoring LTL formulas during system execution.
  - **Integration with Swift Concurrency**: Explore utilities for verifying temporal properties in Swift's Actor model and structured concurrency.
