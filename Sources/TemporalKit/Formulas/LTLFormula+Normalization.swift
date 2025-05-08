import Foundation

extension LTLFormula {
    /// Returns a normalized version of the LTL formula.
    ///
    /// Normalization applies a series of simplification rules to the formula:
    /// - Double negation elimination: !!A → A
    /// - De Morgan's laws: !(A && B) → !A || !B, !(A || B) → !A && !B
    /// - Constant propagation: true && A → A, false && A → false, etc.
    /// - Boolean simplification: A || !A → true, A && !A → false
    /// - Temporal operator simplifications where appropriate
    ///
    /// - Returns: A normalized LTL formula that is semantically equivalent to the original.
    public func normalized() -> LTLFormula<P> {
        switch self {
        case .atomic, .booleanLiteral:
            // Atomic propositions and boolean literals are already in normal form
            return self
            
        case .not(let subFormula):
            // Apply normalization to the subformula first
            let normalizedSub = subFormula.normalized()
            
            // Apply negation simplification rules
            switch normalizedSub {
            case .not(let doubleNegatedFormula):
                // Double negation elimination: !!A → A
                return doubleNegatedFormula
                
            case .and(let lhs, let rhs):
                // De Morgan's law: !(A && B) → !A || !B
                return .or(.not(lhs.normalized()), .not(rhs.normalized())).normalized()
                
            case .or(let lhs, let rhs):
                // De Morgan's law: !(A || B) → !A && !B
                return .and(.not(lhs.normalized()), .not(rhs.normalized())).normalized()
                
            case .booleanLiteral(let value):
                // Negation of a boolean literal: !true → false, !false → true
                return .booleanLiteral(!value)
                
            case .implies(let lhs, let rhs):
                // !(A → B) is equivalent to A && !B
                return .and(lhs.normalized(), .not(rhs.normalized())).normalized()
                
            default:
                // For other cases, just wrap the normalized subformula with not
                return .not(normalizedSub)
            }
            
        case .and(let lhs, let rhs):
            // Normalize both subformulas
            let normalizedLhs = lhs.normalized()
            let normalizedRhs = rhs.normalized()
            
            // Apply AND simplification rules
            if normalizedLhs == .booleanLiteral(true) {
                // true && A → A
                return normalizedRhs
            }
            if normalizedRhs == .booleanLiteral(true) {
                // A && true → A
                return normalizedLhs
            }
            if normalizedLhs == .booleanLiteral(false) || normalizedRhs == .booleanLiteral(false) {
                // false && A → false, A && false → false
                return .booleanLiteral(false)
            }
            if normalizedLhs == normalizedRhs {
                // A && A → A
                return normalizedLhs
            }
            
            // Check for contradictions: A && !A → false
            if case .not(let notFormula) = normalizedRhs, notFormula == normalizedLhs {
                return .booleanLiteral(false)
            }
            if case .not(let notFormula) = normalizedLhs, notFormula == normalizedRhs {
                return .booleanLiteral(false)
            }
            
            // If no simplification, build the AND with normalized subformulas
            return .and(normalizedLhs, normalizedRhs)
            
        case .or(let lhs, let rhs):
            // Normalize both subformulas
            let normalizedLhs = lhs.normalized()
            let normalizedRhs = rhs.normalized()
            
            // Apply OR simplification rules
            if normalizedLhs == .booleanLiteral(false) {
                // false || A → A
                return normalizedRhs
            }
            if normalizedRhs == .booleanLiteral(false) {
                // A || false → A
                return normalizedLhs
            }
            if normalizedLhs == .booleanLiteral(true) || normalizedRhs == .booleanLiteral(true) {
                // true || A → true, A || true → true
                return .booleanLiteral(true)
            }
            if normalizedLhs == normalizedRhs {
                // A || A → A
                return normalizedLhs
            }
            
            // Check for tautologies: A || !A → true
            if case .not(let notFormula) = normalizedRhs, notFormula == normalizedLhs {
                return .booleanLiteral(true)
            }
            if case .not(let notFormula) = normalizedLhs, notFormula == normalizedRhs {
                return .booleanLiteral(true)
            }
            
            // If no simplification, build the OR with normalized subformulas
            return .or(normalizedLhs, normalizedRhs)
            
        case .implies(let lhs, let rhs):
            // A → B is equivalent to !A || B
            return .or(.not(lhs), rhs).normalized()
            
        case .next(let subFormula):
            // Normalize the subformula
            let normalizedSub = subFormula.normalized()
            
            // Simple simplification rules for next
            if case .booleanLiteral(let value) = normalizedSub {
                // X(true) → true, X(false) → false
                // Note: This assumes a model where the trace is infinite or at least one step remains.
                // For finite traces where we're at the last state, X(anything) might be undefined or false.
                return .booleanLiteral(value)
            }
            
            // No other simplification for next, just wrap the normalized subformula
            return .next(normalizedSub)
            
        case .eventually(let subFormula):
            // Normalize the subformula
            let normalizedSub = subFormula.normalized()
            
            // F(true) → true
            if case .booleanLiteral(true) = normalizedSub {
                return .booleanLiteral(true)
            }
            
            // F(false) → false
            if case .booleanLiteral(false) = normalizedSub {
                return .booleanLiteral(false)
            }
            
            // F(F(A)) → F(A) - nested eventually can be simplified
            if case .eventually(let innerFormula) = normalizedSub {
                return .eventually(innerFormula)
            }
            
            // No other simplification for eventually, just wrap the normalized subformula
            return .eventually(normalizedSub)
            
        case .globally(let subFormula):
            // Normalize the subformula
            let normalizedSub = subFormula.normalized()

            // Simplification rules for GLOBALLY
            if case .booleanLiteral(true) = normalizedSub {
                // G(true) → true
                return .booleanLiteral(true)
            }
            if case .booleanLiteral(false) = normalizedSub {
                // G(false) → false
                return .booleanLiteral(false)
            }
            // G(G(A)) → G(A) - nested globally can be simplified
            if case .globally(let innerFormula) = normalizedSub {
                return .globally(innerFormula)
            }
            
            // No other simplification for globally, just wrap the normalized subformula
            return .globally(normalizedSub)
            
        case .until(let lhs, let rhs):
            // Normalize lhs and rhs
            let normalizedLhs = lhs.normalized()
            let normalizedRhs = rhs.normalized()

            // Apply until simplification rules
            if case .booleanLiteral(true) = normalizedRhs {
                // A U true → true (because true will hold immediately)
                return .booleanLiteral(true)
            }
            
            if case .booleanLiteral(false) = normalizedRhs {
                // A U false → false (because false will never hold)
                return .booleanLiteral(false)
            }
            
            if case .booleanLiteral(false) = normalizedLhs {
                // false U B → B (because B must hold immediately for the formula to be true)
                return normalizedRhs
            }
            
            // No other simplification for until, build it with normalized subformulas
            return .until(normalizedLhs, normalizedRhs)
            
        case .weakUntil(let lhs, let rhs):
            // Normalize lhs and rhs
            let normalizedLhs = lhs.normalized()
            let normalizedRhs = rhs.normalized()

            // Apply weak until simplification rules
            if case .booleanLiteral(true) = normalizedRhs {
                // A W true → true (because true holds immediately)
                return .booleanLiteral(true)
            }
            
            if case .booleanLiteral(false) = normalizedRhs {
                // A W false → G(A) (because B will never hold, A must hold forever)
                return .globally(normalizedLhs).normalized()
            }
            
            if case .booleanLiteral(true) = normalizedLhs {
                // true W B → true W B (no simplification, as both branches are possible)
                return .weakUntil(normalizedLhs, normalizedRhs)
            }
            
            if case .booleanLiteral(false) = normalizedLhs {
                // false W B → B (because false can't hold forever, B must hold immediately)
                return normalizedRhs
            }
            
            // No other simplification for weak until, build it with normalized subformulas
            return .weakUntil(normalizedLhs, normalizedRhs)
            
        case .release(let lhs, let rhs):
            // Normalize lhs and rhs
            let normalizedLhs = lhs.normalized()
            let normalizedRhs = rhs.normalized()

            // Apply release simplification rules
            if case .booleanLiteral(false) = normalizedLhs {
                // false R B → G(B) (because A will never hold, B must hold forever)
                return .globally(normalizedRhs).normalized()
            }
            
            if case .booleanLiteral(true) = normalizedLhs {
                // true R B → B (because A holds immediately, B only needs to hold now)
                return normalizedRhs
            }
            
            if case .booleanLiteral(false) = normalizedRhs {
                // A R false → false (because B must hold until A holds, but false never holds)
                return .booleanLiteral(false)
            }
            
            if case .booleanLiteral(true) = normalizedRhs {
                // A R true → true (because true always holds regardless of A)
                return .booleanLiteral(true)
            }
            
            // No other simplification for release, build it with normalized subformulas
            return .release(normalizedLhs, normalizedRhs)
        }
    }
    
    /// Normalizes this LTL formula in place.
    public mutating func normalize() {
        self = self.normalized()
    }
}
