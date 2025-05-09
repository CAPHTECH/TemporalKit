# TemporalKit Demo

This directory contains a command-line demo application showcasing the basic usage of the `TemporalKit` library. It demonstrates how to define propositions, construct Linear Temporal Logic (LTL) formulas, and evaluate them over a sequence of application states (a trace).

## Purpose

The primary goal of this demo is to provide a concrete, runnable example of:

1. **Defining Application State**: How to model the state of your application at a specific point in time (see `AppState.swift`).
2. **Creating an Evaluation Context**: How to provide `TemporalKit` with access to your application state for evaluating propositions (see `AppEvaluationContext` in `ExampleImplementations.swift`).
3. **Implementing Propositions**: How to create custom `TemporalProposition` subclasses that check specific conditions within your application state (see `IsUserLoggedInProposition`, `HasUnreadMessagesProposition`, etc., in `ExampleImplementations.swift`).
4. **Constructing LTL Formulas**: How to use `TemporalKit`'s Swift-idiomatic DSL to build LTL formulas representing temporal properties you want to verify.
5. **Evaluating Formulas Over a Trace**: How to use the `LTLFormulaTraceEvaluator` to check if these LTL formulas hold true for a given sequence of application states.

## How it Works

The `main.swift` file orchestrates the demo:

1. **Defines Propositions**: Instances of `AppProposition` subclasses are created (e.g., `isLoggedIn`, `hasMessages`).
2. **Creates a Trace**: A sample trace is defined as an array of `AppState` objects. Each `AppState` represents the system's state at a discrete time step.

    ```swift
    // Example Trace Snippet from main.swift
    let trace: [AppState] = [
        AppState(isUserLoggedIn: false, hasUnreadMessages: false, cartItemCount: 0), // time 0
        AppState(isUserLoggedIn: true,  hasUnreadMessages: false, cartItemCount: 0), // time 1
        // ... more states
    ]
    ```

3. **Defines LTL Formulas**: Several LTL formulas are constructed using the defined propositions and `TemporalKit`'s formula builders.

    ```swift
    // Example Formula Snippet from main.swift
    // "Eventually, the user is logged in"
    // F (isLoggedIn)
    let eventuallyLoggedIn: LTLFormula<AppProposition> = .eventually(.atomic(isLoggedIn))

    // "Globally, if the user is logged in, they eventually have messages"
    // G (isLoggedIn -> F hasMessages)
    let loggedInImpliesEventuallyMessages: LTLFormula<AppProposition> = .globally(
        .implies(.atomic(isLoggedIn), .eventually(.atomic(hasMessages)))
    )
    ```

4. **Evaluates Formulas**: The `LTLFormulaTraceEvaluator` is used to evaluate each formula against the trace. The `contextProvider` closure maps each `AppState` in the trace to an `AppEvaluationContext`.
5. **Prints Results**: The demo prints the description of each formula and whether it evaluated to `true` or `false` over the given trace.

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

The output will look something like this:

```
TemporalKit Demo Application

--- Evaluating Formulas ---
"Eventually Logged In (F isLoggedIn)" is true
"Logged In -> F Has Messages (G (isLoggedIn -> F hasMessages))" is false
"Logged In Until Cart Full (isLoggedIn U cartHasMoreThanTwoItems)" is true
"Next Cart Has Items (X cartHasItems)" is false
"Complex Formula (G (cartHasItems -> X (cartHasItems \\/ !isLoggedIn)))" is true

--- Manual Proposition Evaluation at specific states ---
At time 0, isLoggedIn: false
At time 1, isLoggedIn: true
At time 1, cartHasItems: false

"G (isLoggedIn ~>> F hasMessages)" is false

Demo finished.
```

This output shows:
* Which LTL formulas were tested.
* Whether each formula held (`true`) or did not hold (`false`) for the predefined trace.
* Some manual evaluations of propositions at specific time steps in the trace.

By examining `main.swift` and `ExampleImplementations.swift` alongside this output, you can gain a practical understanding of how `TemporalKit` helps express and verify temporal logic.
