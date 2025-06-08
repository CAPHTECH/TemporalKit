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
        case .proposition:
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
            if areContradictory(lhs, .not(rhs)) {
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
        // Simple syntactic equality check
        // A more sophisticated implementation could use semantic equivalence
        return String(describing: lhs) == String(describing: rhs)
    }
    
    private func areContradictory(_ lhs: LTLFormula<P>, _ rhs: LTLFormula<P>) -> Bool {
        // Check for direct contradictions like p && !p
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
        case .proposition(let prop):
            return String(describing: prop)
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
        case .proposition(let prop):
            return String(describing: prop)
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
        case .proposition(let prop):
            return "\(spacing)└─ \(prop)"
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