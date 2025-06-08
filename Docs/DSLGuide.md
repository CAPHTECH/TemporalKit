# TemporalKit DSL Guide

TemporalKit provides a powerful Domain-Specific Language (DSL) for writing Linear Temporal Logic (LTL) formulas in a natural, Swift-like syntax.

## Table of Contents
- [Introduction](#introduction)
- [Basic Operators](#basic-operators)
- [Temporal Operators](#temporal-operators)
- [Operator Precedence](#operator-precedence)
- [Common Patterns](#common-patterns)
- [Best Practices](#best-practices)
- [Examples](#examples)

## Introduction

The TemporalKit DSL allows you to express temporal properties using familiar Swift operators and intuitive method syntax. This guide covers all available operators and common usage patterns.

## Basic Operators

### Logical Operators

#### NOT (¬)
```swift
let p = LTLFormula<StringProposition>.proposition("p")
let notP = !p  // Negation
```

#### AND (∧)
```swift
let p = LTLFormula<StringProposition>.proposition("p")
let q = LTLFormula<StringProposition>.proposition("q")
let pAndQ = p && q  // Conjunction
```

#### OR (∨)
```swift
let pOrQ = p || q  // Disjunction
```

#### IMPLIES (→)
```swift
let pImpliesQ = p ==> q  // Implication
// Equivalent to: !p || q
```

### Boolean Literals
```swift
let alwaysTrue = LTLFormula<BooleanProposition>.true
let alwaysFalse = LTLFormula<BooleanProposition>.false
```

## Temporal Operators

### Unary Temporal Operators

#### NEXT (X)
Specifies that a formula must hold at the next time step.

```swift
// Using static method
let nextP = .X(p)
let nextP2 = .next(p)  // Alias

// Example: "In the next state, the system is idle"
let nextIdle = .X(idle)
```

#### EVENTUALLY (F)
Specifies that a formula must hold at some point in the future.

```swift
// Using static method
let eventuallyP = .F(p)
let eventuallyP2 = .eventually(p)  // Alias

// Example: "The goal will eventually be reached"
let eventuallyGoal = .F(goal)
```

#### GLOBALLY (G)
Specifies that a formula must hold at all future time steps.

```swift
// Using static method
let alwaysP = .G(p)
let alwaysP2 = .globally(p)  // Alias

// Example: "The system is always safe"
let alwaysSafe = .G(safe)
```

### Binary Temporal Operators

#### UNTIL (U)
Specifies that the first formula must hold until the second formula becomes true.

```swift
// Using infix operators
let pUntilQ = p ~>> q  // Custom operator
let pUntilQ2 = p U q   // Standard LTL notation

// Using method syntax
let pUntilQ3 = p.until(q)

// Example: "Stay busy until done"
let busyUntilDone = busy ~>> done
```

#### WEAK UNTIL (W)
Like UNTIL, but doesn't require the second formula to eventually become true.

```swift
// Using infix operators
let pWeakUntilQ = p ~~> q  // Custom operator
let pWeakUntilQ2 = p W q   // Standard LTL notation

// Using method syntax
let pWeakUntilQ3 = p.weakUntil(q)

// Example: "Maintain status until upgrade (if ever)"
let maintainUntilUpgrade = maintain ~~> upgrade
```

#### RELEASE (R)
The dual of UNTIL. The second formula must hold until released by the first.

```swift
// Using infix operators
let pReleaseQ = p ~< q   // Custom operator
let pReleaseQ2 = p R q   // Standard LTL notation

// Using method syntax
let pReleaseQ3 = p.release(q)

// Example: "Stay locked until reset"
let lockedUntilReset = reset ~< locked
```

## Operator Precedence

The DSL follows these precedence rules (from highest to lowest):
1. Prefix operators (`!`, `.X`, `.F`, `.G`)
2. Binary temporal operators (`~>>`, `U`, `~~>`, `W`, `~<`, `R`)
3. Logical AND (`&&`)
4. Logical OR (`||`)
5. Implication (`==>`)

Examples:
```swift
// Parentheses added for clarity
p && q ~>> r    // Parsed as: p && (q ~>> r)
p || q ==> r    // Parsed as: (p || q) ==> r
!p U q          // Parsed as: (!p) U q
```

## Common Patterns

### Response Pattern
"Every request is eventually followed by a grant"
```swift
let response = .G(request ==> .F(grant))
```

### Precedence Pattern
"Event A must happen before event B"
```swift
let precedence = !eventB ~>> (eventA || eventB)
```

### Invariance Pattern
"Property P always holds"
```swift
let invariant = .G(property)
```

### Absence Pattern
"Error never occurs"
```swift
let absence = .G(!error)
```

### Existence Pattern
"Success occurs at least once"
```swift
let existence = .F(success)
```

### Universality Pattern
"Property holds after trigger until release"
```swift
let universality = .G(trigger ==> (property ~>> release))
```

### Fairness Pattern
"Infinitely often enabled implies infinitely often taken"
```swift
let fairness = .G(.F(enabled)) ==> .G(.F(taken))
```

## Best Practices

### 1. Use Descriptive Proposition Names
```swift
// Good
let userLoggedIn = LTLFormula<StringProposition>.proposition("userLoggedIn")
let dataLoaded = LTLFormula<StringProposition>.proposition("dataLoaded")

// Avoid
let p = LTLFormula<StringProposition>.proposition("p")
let q = LTLFormula<StringProposition>.proposition("q")
```

### 2. Choose Appropriate Operators
- Use standard notation (`U`, `W`, `R`) for formal specifications
- Use custom operators (`~>>`, `~~>`, `~<`) for more readable code
- Use method syntax for complex nested formulas

### 3. Build Complex Formulas Incrementally
```swift
// Define basic propositions
let request = LTLFormula<StringProposition>.proposition("request")
let processing = LTLFormula<StringProposition>.proposition("processing")
let complete = LTLFormula<StringProposition>.proposition("complete")

// Build sub-formulas
let requestHandling = request ==> .X(processing)
let processingCompletes = processing ==> .F(complete)

// Combine into final property
let systemProperty = .G(requestHandling && processingCompletes)
```

### 4. Use Type Aliases for Complex Formulas
```swift
typealias SystemFormula = LTLFormula<StringProposition>

let idle = SystemFormula.proposition("idle")
let active = SystemFormula.proposition("active")
```

### 5. Document Complex Properties
```swift
// Property: "No two processes can be in critical section simultaneously"
let mutualExclusion = .G(!(inCritical1 && inCritical2))

// Property: "Every request is acknowledged within 3 steps"
let boundedResponse = .G(request ==> (.X(ack) || .X(.X(ack)) || .X(.X(.X(ack)))))
```

## Examples

### Traffic Light Controller
```swift
typealias LightFormula = LTLFormula<StringProposition>

let red = LightFormula.proposition("red")
let yellow = LightFormula.proposition("yellow")
let green = LightFormula.proposition("green")

// Safety: Only one light is on at a time
let safety = .G(
    (red && !yellow && !green) ||
    (!red && yellow && !green) ||
    (!red && !yellow && green)
)

// Liveness: Each light eventually turns on
let liveness = .G(.F(red)) && .G(.F(yellow)) && .G(.F(green))

// Order: Green -> Yellow -> Red
let ordering = .G(
    (green ==> .X(yellow ~>> red)) &&
    (yellow ==> .X(red ~>> green)) &&
    (red ==> .X(green))
)
```

### Request-Response System
```swift
typealias SysFormula = LTLFormula<StringProposition>

let request = SysFormula.proposition("request")
let busy = SysFormula.proposition("busy")
let response = SysFormula.proposition("response")
let error = SysFormula.proposition("error")

// Every request gets a response unless error occurs
let responseProperty = .G(request ==> (busy ~>> (response || error)))

// System doesn't stay busy forever
let progress = .G(busy ==> .F(!busy))

// No response without request
let noSpuriousResponse = .G(response ==> .F(request))
```

### State Machine Verification
```swift
typealias StateFormula = LTLFormula<StringProposition>

let initial = StateFormula.proposition("initial")
let running = StateFormula.proposition("running")
let paused = StateFormula.proposition("paused")
let terminated = StateFormula.proposition("terminated")

// Must start in initial state
let startCondition = initial

// Can't be in multiple states
let uniqueState = .G(
    [initial, running, paused, terminated]
        .map { state in state ==> !otherStates(except: state) }
        .reduce(.true) { $0 && $1 }
)

// Terminal state is final
let terminalIsFinal = .G(terminated ==> .G(terminated))
```

## Advanced Usage

### Nested Temporal Operators
```swift
// "Whenever p becomes true, q remains true until r"
let complex = .G(p ==> .X(q ~>> r))

// "Infinitely often p implies infinitely often q"
let fairness = .G(.F(p)) ==> .G(.F(q))
```

### Combining Multiple Properties
```swift
let safety = .G(!hazard)
let liveness = .G(request ==> .F(response))
let fairness = .G(.F(enabled)) ==> .G(.F(executed))

let systemSpec = safety && liveness && fairness
```

### Pattern Libraries
```swift
// Create reusable pattern functions
func response<P: TemporalProposition>(
    from trigger: LTLFormula<P>,
    to response: LTLFormula<P>
) -> LTLFormula<P> {
    return .G(trigger ==> .F(response))
}

func absence<P: TemporalProposition>(
    of event: LTLFormula<P>
) -> LTLFormula<P> {
    return .G(!event)
}

// Use patterns
let spec1 = response(from: request, to: grant)
let spec2 = absence(of: error)
```