# TemporalKit Demo

This directory contains a command-line demo application showcasing the basic usage of the `TemporalKit` library. It demonstrates how to define propositions, construct Linear Temporal Logic (LTL) formulas, evaluate them over a sequence of application states (a trace), and perform LTL model checking against a Kripke structure.

## Purpose

The primary goal of this demo is to provide a concrete, runnable example of:

1. **Defining Application State**: How to model the state of your application at a specific point in time (see `AppState` in `ExampleImplementations.swift`).
2. **Creating an Evaluation Context**: How to provide `TemporalKit` with access to your application state for evaluating propositions over a trace (see `AppEvaluationContext` in `ExampleImplementations.swift`).
3. **Implementing Propositions**: How to create custom `TemporalProposition` types (e.g., subclasses or using `makeProposition`) that check specific conditions within your application state or Kripke model state.
4. **Defining a Kripke Structure**: How to implement the `KripkeStructure` protocol to model a system for LTL model checking (see `DemoKripkeStructure` in `ExampleImplementations.swift`).
5. **Constructing LTL Formulas**: How to use `TemporalKit`'s Swift-idiomatic DSL to build LTL formulas representing temporal properties you want to verify for both trace evaluation and model checking.
6. **Evaluating Formulas Over a Trace**: How to use the `LTLFormulaTraceEvaluator` to check if LTL formulas hold true for a given sequence of application states.
7. **Performing LTL Model Checking**: How to use the `LTLModelChecker` to verify if LTL formulas hold true for a defined `KripkeStructure`, and how counterexamples are presented if a formula fails.

## How it Works

The `main.swift` file orchestrates the demo, which is broadly split into two parts:

### 1. LTL Trace Evaluation Demo

- **Defines Propositions for Trace Evaluation**: Instances of `ClosureTemporalProposition<AppState, Bool>` are created using `TemporalKit.makeProposition` (e.g., `isLoggedIn`, `hasMessages`).
- **Creates a Trace**: A sample trace is defined as an array of `AppState` objects.
- **Defines LTL Formulas for Trace Evaluation**: Several LTL formulas are constructed using these propositions.
- **Evaluates Formulas Over the Trace**: The `LTLFormulaTraceEvaluator` is used.
- **Prints Trace Evaluation Results**: Shows whether each formula held true or false for the trace.

### 2. LTL Model Checking Demo

- **Uses Kripke Structure and Propositions**: Leverages `DemoKripkeStructure` and its associated propositions (`p_kripke`, `q_kripke`, `r_kripke`) defined in `ExampleImplementations.swift`.
- **Defines LTL Formulas for Model Checking**: Specific LTL formulas are constructed using `KripkeDemoProposition` types.
    ```swift
    // Example Model Checking Formula Snippet from main.swift
    let formula_Gp_kripke: LTLFormula<KripkeDemoProposition> = .globally(.atomic(p_kripke)) // G p
    let formula_Fq_kripke: LTLFormula<KripkeDemoProposition> = .eventually(.atomic(q_kripke)) // F q
    ```
- **Performs Model Checking**: The `LTLModelChecker` is instantiated and used to check each formula against the `DemoKripkeStructure`.
- **Prints Model Checking Results**: Shows whether each formula `HOLDS` or `FAILS`. If it fails, a counterexample (prefix and cycle) is printed.

## Running the Demo

This demo is part of the `TemporalKit` Swift package. To run it:

1. Ensure you have Swift installed.
2. Clone the `TemporalKit` repository (if you haven't already).
3. Navigate to the root directory of the `TemporalKit` package in your terminal.
4. You can run the demo executable directly using Swift:

    ```bash
    swift run TemporalKitDemo
    ```

    Alternatively, if you are using an IDE like Xcode:
    * Open the `Package.swift` file in Xcode.
    * Select the `TemporalKitDemo` scheme.
    * Build and run the `TemporalKitDemo` target.

## Understanding the Output

The output will be divided into sections for Trace Evaluation and LTL Model Checking. 
An example snippet for model checking might look like:

```
--- LTL Model Checking Demo ---

Checking: G p_kripke (Always p) -- Formula: globally(...p_kripke...)
  Result: FAILS
    Counterexample Prefix: s0 -> s1 -> s2 -> s0 -> s1
    Counterexample Cycle:  s2 -> s0 -> s1

Checking: F q_kripke (Eventually q) -- Formula: eventually(...q_kripke...)
  Result: HOLDS

...
Model Checking Demo finished.
```

This output shows:
* Which LTL formulas were model checked against `DemoKripkeStructure`.
* Whether each formula `HOLDS` or `FAILS`.
* For failing formulas, a counterexample trace is provided.

By examining `main.swift` and `ExampleImplementations.swift` alongside this output, you can gain a practical understanding of how `TemporalKit` is used for both LTL trace evaluation and LTL model checking.
