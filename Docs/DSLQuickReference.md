# TemporalKit DSL Quick Reference

## Basic Operators

| Operator | Syntax | Example | Description |
|----------|---------|---------|-------------|
| NOT | `!` | `!p` | Negation |
| AND | `&&` | `p && q` | Conjunction |
| OR | `\|\|` | `p \|\| q` | Disjunction |
| IMPLIES | `==>` | `p ==> q` | Implication |

## Temporal Operators

### Unary Operators
| Operator | Static Method | Example | Description |
|----------|---------------|---------|-------------|
| NEXT | `.X(_)` or `.next(_)` | `.X(p)` | Next state |
| EVENTUALLY | `.F(_)` or `.eventually(_)` | `.F(p)` | Future (eventually) |
| GLOBALLY | `.G(_)` or `.globally(_)` | `.G(p)` | Always (globally) |

### Binary Operators
| Operator | Infix | Method | Namespaced | Description |
|----------|-------|---------|------------|-------------|
| UNTIL | `~>>` | `.until(_)` | `LTL.U(_, _)` | Strong until |
| WEAK UNTIL | `~~>` | `.weakUntil(_)` | `LTL.W(_, _)` | Weak until |
| RELEASE | `~<` | `.release(_)` | `LTL.R(_, _)` | Release |

## Common Patterns

```swift
// Response: Every request is eventually granted
.G(request ==> .F(grant))

// Precedence: q cannot occur before p
!q ~>> (p || q)

// Invariance: Property always holds
.G(property)

// Absence: Error never occurs
.G(!error)

// Existence: Success occurs at least once
.F(success)
```

## Boolean Literals

```swift
// For Bool-valued propositions
let always = LTLFormula<BoolProposition>.true
let never = LTLFormula<BoolProposition>.false
```

## Operator Precedence (highest to lowest)

1. Prefix operators: `!`, `.X`, `.F`, `.G`
2. Binary temporal: `~>>`, `~~>`, `~<`
3. Logical AND: `&&`
4. Logical OR: `||`
5. Implication: `==>`

## Validation

```swift
// Basic validation
let warnings = formula.validate()

// Custom validation
let config = ValidationConfiguration(
    level: .thorough,
    checkPerformance: true,
    maxDepth: 30
)
let warnings = formula.validate(configuration: config)
```

## Pretty Printing

```swift
// Infix notation: (p ∧ q) → F(r)
formula.prettyPrint(style: .infix)

// Prefix notation: IMPLIES(AND(p, q), EVENTUALLY(r))
formula.prettyPrint(style: .prefix)

// Tree structure
formula.prettyPrint(style: .tree)
```

## Tips

- Use method syntax for complex nested formulas
- Use `LTL.U`, `LTL.W`, `LTL.R` to avoid operator conflicts
- Validate formulas to catch common mistakes
- Use pretty printing for debugging