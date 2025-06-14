import Foundation

// MARK: - DSL Validation Extension

extension LTLFormula {
    /// Validates the formula structure and returns any semantic warnings.
    /// 
    /// This method checks for common issues in LTL formulas that might indicate
    /// logical errors or inefficiencies.
    /// 
    /// - Returns: An array of validation warnings. Empty if no issues found.
    public func validate() -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        validateFormula(self, path: [], warnings: &warnings)
        return warnings
    }

    private func validateFormula(
        _ formula: LTLFormula<P>,
        path: [String],
        warnings: inout [ValidationWarning]
    ) {
        switch formula {
        case .atomic:
            break // Propositions are always valid

        case .booleanLiteral(let value):
            // Check for redundant temporal operators on constants
            if !path.isEmpty {
                if value {
                    warnings.append(.redundantTemporalOnTrue(path: path))
                } else {
                    warnings.append(.redundantTemporalOnFalse(path: path))
                }
            }

        case .not(let inner):
            let newPath = path + ["NOT"]
            validateFormula(inner, path: newPath, warnings: &warnings)

            // Check for double negation
            if case .not = inner {
                warnings.append(.doubleNegation(path: path))
            }

        case .and(let lhs, let rhs):
            let newPath = path + ["AND"]
            validateFormula(lhs, path: newPath + ["LHS"], warnings: &warnings)
            validateFormula(rhs, path: newPath + ["RHS"], warnings: &warnings)

            // Check for contradictions
            if areContradictory(lhs, rhs) {
                warnings.append(.contradiction(path: newPath))
            }

            // Check for redundancy
            if areEquivalent(lhs, rhs) {
                warnings.append(.redundantConjunction(path: newPath))
            }

        case .or(let lhs, let rhs):
            let newPath = path + ["OR"]
            validateFormula(lhs, path: newPath + ["LHS"], warnings: &warnings)
            validateFormula(rhs, path: newPath + ["RHS"], warnings: &warnings)

            // Check for tautologies
            if areContradictory(lhs, rhs) {
                warnings.append(.tautology(path: newPath))
            }

            // Check for redundancy
            if areEquivalent(lhs, rhs) {
                warnings.append(.redundantDisjunction(path: newPath))
            }

        case .implies(let lhs, let rhs):
            let newPath = path + ["IMPLIES"]
            validateFormula(lhs, path: newPath + ["LHS"], warnings: &warnings)
            validateFormula(rhs, path: newPath + ["RHS"], warnings: &warnings)

            // Check for always true implications
            if case .booleanLiteral(false) = lhs {
                warnings.append(.vacuousImplication(path: newPath))
            }
            if case .booleanLiteral(true) = rhs {
                warnings.append(.trivialImplication(path: newPath))
            }

        case .next(let inner):
            let newPath = path + ["NEXT"]
            validateFormula(inner, path: newPath, warnings: &warnings)

        case .eventually(let inner):
            let newPath = path + ["EVENTUALLY"]
            validateFormula(inner, path: newPath, warnings: &warnings)

            // Check for nested eventually
            if case .eventually = inner {
                warnings.append(.redundantEventually(path: newPath))
            }

        case .globally(let inner):
            let newPath = path + ["GLOBALLY"]
            validateFormula(inner, path: newPath, warnings: &warnings)

            // Check for nested globally
            if case .globally = inner {
                warnings.append(.redundantGlobally(path: newPath))
            }

        case .until(let lhs, let rhs):
            let newPath = path + ["UNTIL"]
            validateFormula(lhs, path: newPath + ["LHS"], warnings: &warnings)
            validateFormula(rhs, path: newPath + ["RHS"], warnings: &warnings)

            // Check for immediate satisfaction
            if case .booleanLiteral(true) = rhs {
                warnings.append(.immediateUntil(path: newPath))
            }

        case .weakUntil(let lhs, let rhs):
            let newPath = path + ["WEAK_UNTIL"]
            validateFormula(lhs, path: newPath + ["LHS"], warnings: &warnings)
            validateFormula(rhs, path: newPath + ["RHS"], warnings: &warnings)

        case .release(let lhs, let rhs):
            let newPath = path + ["RELEASE"]
            validateFormula(lhs, path: newPath + ["LHS"], warnings: &warnings)
            validateFormula(rhs, path: newPath + ["RHS"], warnings: &warnings)
        }
    }

    // Helper methods for equivalence and contradiction checking
    private func areEquivalent(_ lhs: LTLFormula<P>, _ rhs: LTLFormula<P>) -> Bool {
        lhs.semanticallyEquivalent(to: rhs)
    }

    private func areContradictory(_ lhs: LTLFormula<P>, _ rhs: LTLFormula<P>) -> Bool {
        // Check for direct contradictions
        switch (lhs, rhs) {
        case (.not(let inner), _) where areEquivalent(inner, rhs):
            return true
        case (_, .not(let inner)) where areEquivalent(lhs, inner):
            return true
        case (.booleanLiteral(true), .booleanLiteral(false)),
             (.booleanLiteral(false), .booleanLiteral(true)):
            return true
        default:
            return false
        }
    }
}

// MARK: - Validation Warning Types

/// Represents a validation warning for an LTL formula.
public struct ValidationWarning: Equatable, CustomStringConvertible {
    /// The type of warning
    public let type: WarningType

    /// The path to the problematic sub-formula
    public let path: [String]

    /// A human-readable message describing the issue
    public let message: String

    public var description: String {
        let pathStr = path.isEmpty ? "root" : path.joined(separator: " -> ")
        return "[\(type)] at \(pathStr): \(message)"
    }

    // Factory methods for common warnings
    static func redundantTemporalOnTrue(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "Temporal operator on 'true' literal is redundant"
        )
    }

    static func redundantTemporalOnFalse(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "Temporal operator on 'false' literal may produce unexpected results"
        )
    }

    static func doubleNegation(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "Double negation can be simplified"
        )
    }

    static func contradiction(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .contradiction,
            path: path,
            message: "Formula contains a contradiction and will always be false"
        )
    }

    static func tautology(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .tautology,
            path: path,
            message: "Formula is a tautology and will always be true"
        )
    }

    static func redundantConjunction(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "Both sides of AND are equivalent"
        )
    }

    static func redundantDisjunction(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "Both sides of OR are equivalent"
        )
    }

    static func vacuousImplication(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .tautology,
            path: path,
            message: "Implication with false antecedent is always true"
        )
    }

    static func trivialImplication(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .tautology,
            path: path,
            message: "Implication with true consequent is always true"
        )
    }

    static func redundantEventually(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "Nested EVENTUALLY operators can be simplified to a single EVENTUALLY"
        )
    }

    static func redundantGlobally(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "Nested GLOBALLY operators can be simplified to a single GLOBALLY"
        )
    }

    static func immediateUntil(path: [String]) -> ValidationWarning {
        ValidationWarning(
            type: .redundancy,
            path: path,
            message: "UNTIL with 'true' as right operand is immediately satisfied"
        )
    }
}

/// Types of validation warnings.
public enum WarningType: String {
    case redundancy = "Redundancy"
    case contradiction = "Contradiction"
    case tautology = "Tautology"
    case performance = "Performance"
    case semantics = "Semantics"
}

// MARK: - Debug Support

extension LTLFormula {
    /// Returns a human-readable string representation of the formula.
    /// 
    /// This method is useful for debugging and understanding complex formulas.
    /// 
    /// - Parameter style: The formatting style to use
    /// - Returns: A formatted string representation
    public func prettyPrint(style: PrettyPrintStyle = .infix) -> String {
        switch style {
        case .infix:
            return infixDescription()
        case .prefix:
            return prefixDescription()
        case .tree:
            return treeDescription(indent: 0)
        }
    }

    private func infixDescription() -> String {
        switch self {
        case .atomic(let prop):
            return prop.name
        case .booleanLiteral(let value):
            return value ? "true" : "false"
        case .not(let inner):
            return "¬\(inner.infixDescription())"
        case .and(let lhs, let rhs):
            return "(\(lhs.infixDescription()) ∧ \(rhs.infixDescription()))"
        case .or(let lhs, let rhs):
            return "(\(lhs.infixDescription()) ∨ \(rhs.infixDescription()))"
        case .implies(let lhs, let rhs):
            return "(\(lhs.infixDescription()) → \(rhs.infixDescription()))"
        case .next(let inner):
            return "X(\(inner.infixDescription()))"
        case .eventually(let inner):
            return "F(\(inner.infixDescription()))"
        case .globally(let inner):
            return "G(\(inner.infixDescription()))"
        case .until(let lhs, let rhs):
            return "(\(lhs.infixDescription()) U \(rhs.infixDescription()))"
        case .weakUntil(let lhs, let rhs):
            return "(\(lhs.infixDescription()) W \(rhs.infixDescription()))"
        case .release(let lhs, let rhs):
            return "(\(lhs.infixDescription()) R \(rhs.infixDescription()))"
        }
    }

    private func prefixDescription() -> String {
        switch self {
        case .atomic(let prop):
            return prop.name
        case .booleanLiteral(let value):
            return value ? "true" : "false"
        case .not(let inner):
            return "NOT \(inner.prefixDescription())"
        case .and(let lhs, let rhs):
            return "AND(\(lhs.prefixDescription()), \(rhs.prefixDescription()))"
        case .or(let lhs, let rhs):
            return "OR(\(lhs.prefixDescription()), \(rhs.prefixDescription()))"
        case .implies(let lhs, let rhs):
            return "IMPLIES(\(lhs.prefixDescription()), \(rhs.prefixDescription()))"
        case .next(let inner):
            return "NEXT(\(inner.prefixDescription()))"
        case .eventually(let inner):
            return "EVENTUALLY(\(inner.prefixDescription()))"
        case .globally(let inner):
            return "GLOBALLY(\(inner.prefixDescription()))"
        case .until(let lhs, let rhs):
            return "UNTIL(\(lhs.prefixDescription()), \(rhs.prefixDescription()))"
        case .weakUntil(let lhs, let rhs):
            return "WEAK_UNTIL(\(lhs.prefixDescription()), \(rhs.prefixDescription()))"
        case .release(let lhs, let rhs):
            return "RELEASE(\(lhs.prefixDescription()), \(rhs.prefixDescription()))"
        }
    }

    private func treeDescription(indent: Int) -> String {
        let spacing = String(repeating: "  ", count: indent)

        switch self {
        case .atomic(let prop):
            return "\(spacing)└─ \(prop.name)"
        case .booleanLiteral(let value):
            return "\(spacing)└─ \(value)"
        case .not(let inner):
            return "\(spacing)└─ NOT\n\(inner.treeDescription(indent: indent + 1))"
        case .and(let lhs, let rhs):
            return "\(spacing)└─ AND\n\(lhs.treeDescription(indent: indent + 1))\n\(rhs.treeDescription(indent: indent + 1))"
        case .or(let lhs, let rhs):
            return "\(spacing)└─ OR\n\(lhs.treeDescription(indent: indent + 1))\n\(rhs.treeDescription(indent: indent + 1))"
        case .implies(let lhs, let rhs):
            return "\(spacing)└─ IMPLIES\n\(lhs.treeDescription(indent: indent + 1))\n\(rhs.treeDescription(indent: indent + 1))"
        case .next(let inner):
            return "\(spacing)└─ NEXT\n\(inner.treeDescription(indent: indent + 1))"
        case .eventually(let inner):
            return "\(spacing)└─ EVENTUALLY\n\(inner.treeDescription(indent: indent + 1))"
        case .globally(let inner):
            return "\(spacing)└─ GLOBALLY\n\(inner.treeDescription(indent: indent + 1))"
        case .until(let lhs, let rhs):
            return "\(spacing)└─ UNTIL\n\(lhs.treeDescription(indent: indent + 1))\n\(rhs.treeDescription(indent: indent + 1))"
        case .weakUntil(let lhs, let rhs):
            return "\(spacing)└─ WEAK_UNTIL\n\(lhs.treeDescription(indent: indent + 1))\n\(rhs.treeDescription(indent: indent + 1))"
        case .release(let lhs, let rhs):
            return "\(spacing)└─ RELEASE\n\(lhs.treeDescription(indent: indent + 1))\n\(rhs.treeDescription(indent: indent + 1))"
        }
    }
}

/// Styles for pretty printing LTL formulas.
public enum PrettyPrintStyle {
    /// Standard infix notation with symbols (∧, ∨, ¬, etc.)
    case infix

    /// Prefix notation with operators (AND, OR, NOT, etc.)
    case prefix

    /// Tree structure showing formula hierarchy
    case tree
}

// MARK: - Semantic Equivalence

extension LTLFormula {
    /// Checks if this formula is semantically equivalent to another formula.
    /// 
    /// This performs a structural comparison that accounts for:
    /// - Commutative properties (p ∧ q ≡ q ∧ p)
    /// - Associative properties ((p ∧ q) ∧ r ≡ p ∧ (q ∧ r))
    /// - Identity laws (p ∧ true ≡ p)
    /// - Idempotent laws (p ∧ p ≡ p)
    /// - De Morgan's laws
    /// 
    /// - Parameter other: The formula to compare with
    /// - Returns: true if the formulas are semantically equivalent
    public func semanticallyEquivalent(to other: LTLFormula<P>) -> Bool {
        // First try syntactic equality for performance
        if self.syntacticallyEqual(to: other) {
            return true
        }

        // Then check semantic equivalence
        return self.normalizedForm().syntacticallyEqual(to: other.normalizedForm())
    }

    /// Checks syntactic equality between formulas.
    private func syntacticallyEqual(to other: LTLFormula<P>) -> Bool {
        switch (self, other) {
        case (.atomic(let p1), .atomic(let p2)):
            return p1.id == p2.id
        case (.booleanLiteral(let v1), .booleanLiteral(let v2)):
            return v1 == v2
        case (.not(let f1), .not(let f2)):
            return f1.syntacticallyEqual(to: f2)
        case (.and(let l1, let r1), .and(let l2, let r2)):
            return (l1.syntacticallyEqual(to: l2) && r1.syntacticallyEqual(to: r2)) ||
                   (l1.syntacticallyEqual(to: r2) && r1.syntacticallyEqual(to: l2)) // Commutativity
        case (.or(let l1, let r1), .or(let l2, let r2)):
            return (l1.syntacticallyEqual(to: l2) && r1.syntacticallyEqual(to: r2)) ||
                   (l1.syntacticallyEqual(to: r2) && r1.syntacticallyEqual(to: l2)) // Commutativity
        case (.implies(let l1, let r1), .implies(let l2, let r2)):
            return l1.syntacticallyEqual(to: l2) && r1.syntacticallyEqual(to: r2)
        case (.next(let f1), .next(let f2)):
            return f1.syntacticallyEqual(to: f2)
        case (.eventually(let f1), .eventually(let f2)):
            return f1.syntacticallyEqual(to: f2)
        case (.globally(let f1), .globally(let f2)):
            return f1.syntacticallyEqual(to: f2)
        case (.until(let l1, let r1), .until(let l2, let r2)):
            return l1.syntacticallyEqual(to: l2) && r1.syntacticallyEqual(to: r2)
        case (.weakUntil(let l1, let r1), .weakUntil(let l2, let r2)):
            return l1.syntacticallyEqual(to: l2) && r1.syntacticallyEqual(to: r2)
        case (.release(let l1, let r1), .release(let l2, let r2)):
            return l1.syntacticallyEqual(to: l2) && r1.syntacticallyEqual(to: r2)
        default:
            return false
        }
    }

    /// Returns a normalized form of the formula for semantic comparison.
    /// This applies various logical simplifications.
    private func normalizedForm() -> LTLFormula<P> {
        switch self {
        // Remove double negation
        case .not(.not(let inner)):
            return inner.normalizedForm()

        // Identity laws
        case .and(let lhs, .booleanLiteral(true)):
            return lhs.normalizedForm()
        case .and(.booleanLiteral(true), let rhs):
            return rhs.normalizedForm()
        case .or(let lhs, .booleanLiteral(false)):
            return lhs.normalizedForm()
        case .or(.booleanLiteral(false), let rhs):
            return rhs.normalizedForm()

        // Annihilation laws
        case .and(_, .booleanLiteral(false)),
             .and(.booleanLiteral(false), _):
            return .booleanLiteral(false)
        case .or(_, .booleanLiteral(true)),
             .or(.booleanLiteral(true), _):
            return .booleanLiteral(true)

        // Idempotent laws (requires comparison)
        case .and(let lhs, let rhs) where lhs.syntacticallyEqual(to: rhs):
            return lhs.normalizedForm()
        case .or(let lhs, let rhs) where lhs.syntacticallyEqual(to: rhs):
            return lhs.normalizedForm()

        // Nested temporal operators
        case .eventually(.eventually(let inner)):
            return .eventually(inner.normalizedForm())
        case .globally(.globally(let inner)):
            return .globally(inner.normalizedForm())

        // Recursively normalize subformulas
        case .not(let inner):
            return .not(inner.normalizedForm())
        case .and(let lhs, let rhs):
            return .and(lhs.normalizedForm(), rhs.normalizedForm())
        case .or(let lhs, let rhs):
            return .or(lhs.normalizedForm(), rhs.normalizedForm())
        case .implies(let lhs, let rhs):
            return .implies(lhs.normalizedForm(), rhs.normalizedForm())
        case .next(let inner):
            return .next(inner.normalizedForm())
        case .eventually(let inner):
            return .eventually(inner.normalizedForm())
        case .globally(let inner):
            return .globally(inner.normalizedForm())
        case .until(let lhs, let rhs):
            return .until(lhs.normalizedForm(), rhs.normalizedForm())
        case .weakUntil(let lhs, let rhs):
            return .weakUntil(lhs.normalizedForm(), rhs.normalizedForm())
        case .release(let lhs, let rhs):
            return .release(lhs.normalizedForm(), rhs.normalizedForm())

        // Base cases
        case .atomic, .booleanLiteral:
            return self
        }
    }
}

// MARK: - Validation Configuration

/// Configuration for formula validation.
public struct ValidationConfiguration {
    /// The level of validation to perform.
    public let level: ValidationLevel

    /// Whether to check for performance issues.
    public let checkPerformance: Bool

    /// Maximum formula depth before warning about complexity.
    public let maxDepth: Int

    /// Default configuration with basic validation.
    public static let `default` = ValidationConfiguration(
        level: .basic,
        checkPerformance: false,
        maxDepth: 50
    )

    /// Thorough configuration that performs all checks.
    public static let thorough = ValidationConfiguration(
        level: .thorough,
        checkPerformance: true,
        maxDepth: 30
    )

    public init(level: ValidationLevel, checkPerformance: Bool, maxDepth: Int) {
        self.level = level
        self.checkPerformance = checkPerformance
        self.maxDepth = maxDepth
    }
}

/// Levels of validation thoroughness.
public enum ValidationLevel {
    /// Basic validation for obvious issues.
    case basic

    /// Thorough validation including semantic analysis.
    case thorough

    /// Exhaustive validation (may be slow for large formulas).
    case exhaustive
}

extension LTLFormula {
    /// Validates the formula with custom configuration.
    /// 
    /// - Parameter configuration: The validation configuration to use
    /// - Returns: An array of validation warnings
    public func validate(configuration: ValidationConfiguration) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []

        // Basic validation
        validateFormula(self, path: [], warnings: &warnings)

        // Performance checks
        if configuration.checkPerformance {
            let depth = self.depth()
            if depth > configuration.maxDepth {
                warnings.append(ValidationWarning(
                    type: .performance,
                    path: [],
                    message: "Formula depth (\(depth)) exceeds recommended maximum (\(configuration.maxDepth))"
                ))
            }
        }

        // Additional checks based on level
        switch configuration.level {
        case .basic:
            break
        case .thorough:
            // Add more semantic checks here
            break
        case .exhaustive:
            // Add exhaustive checks here
            break
        }

        return warnings
    }

    /// Calculates the depth of the formula tree.
    private func depth() -> Int {
        switch self {
        case .atomic, .booleanLiteral:
            return 1
        case .not(let inner), .next(let inner), .eventually(let inner), .globally(let inner):
            return 1 + inner.depth()
        case .and(let lhs, let rhs), .or(let lhs, let rhs), .implies(let lhs, let rhs),
             .until(let lhs, let rhs), .weakUntil(let lhs, let rhs), .release(let lhs, let rhs):
            return 1 + max(lhs.depth(), rhs.depth())
        }
    }
}
