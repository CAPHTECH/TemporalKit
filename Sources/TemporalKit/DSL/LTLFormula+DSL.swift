import Foundation

// MARK: - Logical Connective Operator Overloads

/// Logical NOT operator for LTL formulas.
public prefix func ! <P: TemporalProposition>(formula: LTLFormula<P>) -> LTLFormula<P> {
    return .not(formula)
}

/// Logical AND operator for LTL formulas.
public func && <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    return .and(lhs, rhs)
}

/// Logical OR operator for LTL formulas.
/// Derived from `not` and `and`: `p || q` is equivalent to `!(!p && !q)`.
public func || <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    return .or(lhs, rhs)
}

// MARK: - Implication Operator

// Define a precedence group for implication, similar to logical conjunctions but typically lower.
precedencegroup ImplicationPrecedence {
    associativity: right // Implication is typically right-associative: a -> b -> c  === a -> (b -> c)
    higherThan: AssignmentPrecedence // Placeholder, adjust as needed relative to other custom operators
    lowerThan: LogicalDisjunctionPrecedence // a || b -> c means (a || b) -> c
}

/// Logical IMPLIES operator for LTL formulas.
/// `p ==> q` is equivalent to `!p || q`.
infix operator ==>: ImplicationPrecedence
public func ==> <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    return .implies(lhs, rhs)
}

// MARK: - Temporal Operator Static Factory Methods

extension LTLFormula {
    /// Creates a NEXT temporal formula (X p).
    /// - Parameter formula: The sub-formula `p` that must hold at the next time step.
    /// - Returns: An LTL formula representing `X p`.
    public static func X(_ formula: LTLFormula<P>) -> LTLFormula<P> {
        return .next(formula)
    }

    /// Creates an EVENTUALLY (Finally) temporal formula (F p).
    /// - Parameter formula: The sub-formula `p` that must hold at some future time step.
    /// - Returns: An LTL formula representing `F p`.
    public static func F(_ formula: LTLFormula<P>) -> LTLFormula<P> {
        return .eventually(formula)
    }

    /// Creates a GLOBALLY temporal formula (G p).
    /// - Parameter formula: The sub-formula `p` that must hold at all future time steps.
    /// - Returns: An LTL formula representing `G p`.
    public static func G(_ formula: LTLFormula<P>) -> LTLFormula<P> {
        return .globally(formula)
    }
}

// MARK: - Custom Infix Temporal Operators (Until, Weak Until, Release)

// Define a precedence group for temporal operators like Until, Weak Until, Release.
precedencegroup TemporalOperatorPrecedence {
    associativity: right // Conventionally, ~> , ~~>, ~< can be right-associative for chained expressions like p ~> q ~> r
    higherThan: ImplicationPrecedence
    lowerThan: LogicalConjunctionPrecedence // Example: p && q ~> r should be p && (q ~> r)
}

/// Temporal UNTIL operator (strong until): p ~>> q
infix operator ~>>: TemporalOperatorPrecedence
public func ~>> <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    return .until(lhs, rhs)
}

/// Temporal WEAK UNTIL operator: p ~~> q
infix operator ~~>: TemporalOperatorPrecedence
public func ~~> <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    return .weakUntil(lhs, rhs)
}

/// Temporal RELEASE operator: p ~< q
infix operator ~<: TemporalOperatorPrecedence
public func ~< <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    return .release(lhs, rhs)
}

// MARK: - Convenience Initializers for Literals

extension LTLFormula where P.Value == Bool {
    /// Creates a formula representing a boolean literal `true`.
    public static var `true`: LTLFormula<P> {
        return .booleanLiteral(true)
    }

    /// Creates a formula representing a boolean literal `false`.
    public static var `false`: LTLFormula<P> {
        return .booleanLiteral(false)
    }
}
