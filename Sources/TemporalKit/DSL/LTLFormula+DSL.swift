import Foundation

// MARK: - Logical Connective Operator Overloads

/// Logical NOT operator for LTL formulas.
/// 
/// The NOT operator negates the truth value of a formula.
/// - Parameter formula: The formula to negate
/// - Returns: A formula that is true when the input formula is false, and vice versa
/// 
/// ## Example
/// ```swift
/// let p = LTLFormula<StringProposition>.proposition("p")
/// let notP = !p  // Represents "not p"
/// ```
/// 
/// ## Semantics
/// For a trace π and position i:
/// - (π, i) ⊨ ¬φ iff (π, i) ⊭ φ
public prefix func ! <P: TemporalProposition>(formula: LTLFormula<P>) -> LTLFormula<P> {
    .not(formula)
}

/// Logical AND operator for LTL formulas.
/// 
/// The AND operator creates a conjunction of two formulas.
/// - Parameters:
///   - lhs: The left-hand side formula
///   - rhs: The right-hand side formula
/// - Returns: A formula that is true when both input formulas are true
/// 
/// ## Example
/// ```swift
/// let p = LTLFormula<StringProposition>.proposition("p")
/// let q = LTLFormula<StringProposition>.proposition("q")
/// let pAndQ = p && q  // Represents "p and q"
/// ```
/// 
/// ## Semantics
/// For a trace π and position i:
/// - (π, i) ⊨ φ ∧ ψ iff (π, i) ⊨ φ and (π, i) ⊨ ψ
public func && <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    .and(lhs, rhs)
}

/// Logical OR operator for LTL formulas.
/// 
/// The OR operator creates a disjunction of two formulas.
/// - Parameters:
///   - lhs: The left-hand side formula
///   - rhs: The right-hand side formula
/// - Returns: A formula that is true when at least one input formula is true
/// 
/// ## Example
/// ```swift
/// let p = LTLFormula<StringProposition>.proposition("p")
/// let q = LTLFormula<StringProposition>.proposition("q")
/// let pOrQ = p || q  // Represents "p or q"
/// ```
/// 
/// ## Semantics
/// For a trace π and position i:
/// - (π, i) ⊨ φ ∨ ψ iff (π, i) ⊨ φ or (π, i) ⊨ ψ
public func || <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    .or(lhs, rhs)
}

// MARK: - Implication Operator

// Define a precedence group for implication, similar to logical conjunctions but typically lower.
precedencegroup ImplicationPrecedence {
    associativity: right // Implication is typically right-associative: a -> b -> c  === a -> (b -> c)
    higherThan: AssignmentPrecedence
    lowerThan: LogicalDisjunctionPrecedence // a || b -> c means (a || b) -> c
}

/// Logical IMPLIES operator for LTL formulas.
/// 
/// The implication operator creates a logical implication between two formulas.
/// `p ==> q` is semantically equivalent to `!p || q`.
/// 
/// - Parameters:
///   - lhs: The antecedent (premise) formula
///   - rhs: The consequent (conclusion) formula
/// - Returns: A formula representing the implication
/// 
/// ## Example
/// ```swift
/// let request = LTLFormula<StringProposition>.proposition("request")
/// let grant = LTLFormula<StringProposition>.proposition("grant")
/// let property = .G(request ==> .F(grant))  // "Globally, if request then eventually grant"
/// ```
/// 
/// ## Semantics
/// For a trace π and position i:
/// - (π, i) ⊨ φ → ψ iff (π, i) ⊭ φ or (π, i) ⊨ ψ
/// 
/// ## Common Patterns
/// - Response: `G(p ==> F(q))` - "Every p is eventually followed by q"
/// - Precedence: `!q ~>> (p || q)` - "q cannot occur before p"
infix operator ==>: ImplicationPrecedence
public func ==> <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    .implies(lhs, rhs)
}

// MARK: - Temporal Operator Static Factory Methods

extension LTLFormula {
    /// Creates a NEXT temporal formula (X φ).
    /// 
    /// The NEXT operator specifies that a formula must hold at the immediately next time step.
    /// 
    /// - Parameter formula: The sub-formula that must hold at the next time step
    /// - Returns: An LTL formula representing `X φ`
    /// 
    /// ## Example
    /// ```swift
    /// let p = LTLFormula<StringProposition>.proposition("p")
    /// let nextP = .X(p)  // "In the next state, p holds"
    /// ```
    /// 
    /// ## Semantics
    /// For a trace π and position i:
    /// - (π, i) ⊨ X φ iff (π, i+1) ⊨ φ
    /// 
    /// ## Note
    /// The NEXT operator requires at least one more state in the trace after the current position.
    public static func X(_ formula: LTLFormula<P>) -> LTLFormula<P> {
        .next(formula)
    }

    /// Creates an EVENTUALLY (Finally) temporal formula (F φ).
    /// 
    /// The EVENTUALLY operator specifies that a formula must hold at some point in the future (including now).
    /// 
    /// - Parameter formula: The sub-formula that must eventually hold
    /// - Returns: An LTL formula representing `F φ`
    /// 
    /// ## Example
    /// ```swift
    /// let goal = LTLFormula<StringProposition>.proposition("goal")
    /// let eventuallyGoal = .F(goal)  // "Eventually, goal will be reached"
    /// ```
    /// 
    /// ## Semantics
    /// For a trace π and position i:
    /// - (π, i) ⊨ F φ iff ∃j ≥ i: (π, j) ⊨ φ
    /// 
    /// ## Equivalence
    /// `F φ` is equivalent to `true U φ`
    public static func F(_ formula: LTLFormula<P>) -> LTLFormula<P> {
        .eventually(formula)
    }

    /// Creates a GLOBALLY temporal formula (G φ).
    /// 
    /// The GLOBALLY operator specifies that a formula must hold at all future time steps (including now).
    /// 
    /// - Parameter formula: The sub-formula that must always hold
    /// - Returns: An LTL formula representing `G φ`
    /// 
    /// ## Example
    /// ```swift
    /// let safe = LTLFormula<StringProposition>.proposition("safe")
    /// let alwaysSafe = .G(safe)  // "The system is always safe"
    /// ```
    /// 
    /// ## Semantics
    /// For a trace π and position i:
    /// - (π, i) ⊨ G φ iff ∀j ≥ i: (π, j) ⊨ φ
    /// 
    /// ## Equivalence
    /// `G φ` is equivalent to `¬F ¬φ`
    public static func G(_ formula: LTLFormula<P>) -> LTLFormula<P> {
        .globally(formula)
    }
}

// MARK: - Custom Infix Temporal Operators (Until, Weak Until, Release)

// Define a precedence group for temporal operators like Until, Weak Until, Release.
precedencegroup TemporalOperatorPrecedence {
    associativity: right // Right-associative for chained expressions
    higherThan: LogicalConjunctionPrecedence
    lowerThan: ComparisonPrecedence
}

/// Temporal UNTIL operator (strong until): φ U ψ
/// 
/// The UNTIL operator specifies that the first formula must hold until the second formula becomes true.
/// The second formula must eventually become true.
/// 
/// - Parameters:
///   - lhs: The formula that must hold until rhs becomes true
///   - rhs: The formula that must eventually become true
/// - Returns: An LTL formula representing `φ U ψ`
/// 
/// ## Example
/// ```swift
/// let busy = LTLFormula<StringProposition>.proposition("busy")
/// let done = LTLFormula<StringProposition>.proposition("done")
/// let busyUntilDone = busy ~>> done  // "Stay busy until done"
/// // Alternative: busy.until(done)
/// // Standard notation: LTL.U(busy, done)
/// ```
/// 
/// ## Semantics
/// For a trace π and position i:
/// - (π, i) ⊨ φ U ψ iff ∃j ≥ i: (π, j) ⊨ ψ and ∀k, i ≤ k < j: (π, k) ⊨ φ
/// 
/// ## Note
/// Strong until requires that ψ eventually becomes true.
infix operator ~>>: TemporalOperatorPrecedence

public func ~>> <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    .until(lhs, rhs)
}

/// Temporal WEAK UNTIL operator: φ W ψ
/// 
/// The WEAK UNTIL operator is similar to UNTIL, but doesn't require the second formula to eventually become true.
/// If the second formula never becomes true, the first formula must hold forever.
/// 
/// - Parameters:
///   - lhs: The formula that must hold until rhs becomes true (or forever)
///   - rhs: The formula that may eventually become true
/// - Returns: An LTL formula representing `φ W ψ`
/// 
/// ## Example
/// ```swift
/// let maintain = LTLFormula<StringProposition>.proposition("maintain")
/// let upgrade = LTLFormula<StringProposition>.proposition("upgrade")
/// let maintainWeakUntilUpgrade = maintain ~~> upgrade  // "Maintain until upgrade (if ever)"
/// // Alternative: maintain.weakUntil(upgrade)
/// // Standard notation: LTL.W(maintain, upgrade)
/// ```
/// 
/// ## Semantics
/// For a trace π and position i:
/// - (π, i) ⊨ φ W ψ iff (π, i) ⊨ φ U ψ or (π, i) ⊨ G φ
/// 
/// ## Equivalence
/// `φ W ψ` is equivalent to `(φ U ψ) ∨ G φ`
infix operator ~~>: TemporalOperatorPrecedence

public func ~~> <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    .weakUntil(lhs, rhs)
}

/// Temporal RELEASE operator: φ R ψ
/// 
/// The RELEASE operator is the dual of UNTIL. It specifies that the second formula must hold
/// until and including the point where the first formula becomes true.
/// If the first formula never becomes true, the second formula must hold forever.
/// 
/// - Parameters:
///   - lhs: The formula that releases the rhs obligation
///   - rhs: The formula that must hold until released by lhs
/// - Returns: An LTL formula representing `φ R ψ`
/// 
/// ## Example
/// ```swift
/// let reset = LTLFormula<StringProposition>.proposition("reset")
/// let locked = LTLFormula<StringProposition>.proposition("locked")
/// let lockedUntilReset = reset ~< locked  // "Stay locked until reset"
/// // Alternative: reset.release(locked)
/// // Standard notation: LTL.R(reset, locked)
/// ```
/// 
/// ## Semantics
/// For a trace π and position i:
/// - (π, i) ⊨ φ R ψ iff ∀j ≥ i: (π, j) ⊨ ψ or ∃k, i ≤ k < j: (π, k) ⊨ φ
/// 
/// ## Equivalence
/// `φ R ψ` is equivalent to `¬(¬φ U ¬ψ)`
infix operator ~<: TemporalOperatorPrecedence

public func ~< <P: TemporalProposition>(lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> LTLFormula<P> {
    .release(lhs, rhs)
}

// MARK: - Convenience Initializers for Literals

extension LTLFormula where P.Value == Bool {
    /// Creates a formula representing a boolean literal `true`.
    /// 
    /// This formula is always satisfied at any position in any trace.
    /// 
    /// ## Example
    /// ```swift
    /// let alwaysTrue = LTLFormula<BooleanProposition>.true
    /// let tautology = .G(.true)  // Always true
    /// ```
    public static var `true`: LTLFormula<P> {
        .booleanLiteral(true)
    }

    /// Creates a formula representing a boolean literal `false`.
    /// 
    /// This formula is never satisfied at any position in any trace.
    /// 
    /// ## Example
    /// ```swift
    /// let alwaysFalse = LTLFormula<BooleanProposition>.false
    /// let contradiction = .F(.false)  // Never satisfied
    /// ```
    public static var `false`: LTLFormula<P> {
        .booleanLiteral(false)
    }
}

// MARK: - Method-based Temporal Operators

extension LTLFormula {
    /// Creates an UNTIL formula using method syntax.
    /// 
    /// ## Example
    /// ```swift
    /// let result = busy.until(done)  // Equivalent to: busy ~>> done
    /// ```
    public func until(_ other: LTLFormula<P>) -> LTLFormula<P> {
        .until(self, other)
    }

    /// Creates a WEAK UNTIL formula using method syntax.
    /// 
    /// ## Example
    /// ```swift
    /// let result = maintain.weakUntil(upgrade)  // Equivalent to: maintain ~~> upgrade
    /// ```
    public func weakUntil(_ other: LTLFormula<P>) -> LTLFormula<P> {
        .weakUntil(self, other)
    }

    /// Creates a RELEASE formula using method syntax.
    /// 
    /// ## Example
    /// ```swift
    /// let result = reset.release(locked)  // Equivalent to: reset ~< locked
    /// ```
    public func release(_ other: LTLFormula<P>) -> LTLFormula<P> {
        .release(self, other)
    }

    /// Creates an IMPLIES formula using method syntax.
    /// 
    /// ## Example
    /// ```swift
    /// let result = request.implies(grant)  // Equivalent to: request ==> grant
    /// ```
    public func implies(_ other: LTLFormula<P>) -> LTLFormula<P> {
        .implies(self, other)
    }
}

// MARK: - Namespaced Standard LTL Operators

/// Namespace for standard LTL operators to avoid global namespace pollution.
/// 
/// Use these operators when you prefer standard LTL notation:
/// ```swift
/// let formula = LTL.U(p, q)  // Instead of: p U q
/// ```
public enum LTL {
    /// Standard UNTIL operator.
    /// 
    /// ## Example
    /// ```swift
    /// let formula = LTL.U(busy, done)
    /// ```
    public static func U<P: TemporalProposition>(
        _ lhs: LTLFormula<P>,
        _ rhs: LTLFormula<P>
    ) -> LTLFormula<P> {
        .until(lhs, rhs)
    }

    /// Standard WEAK UNTIL operator.
    /// 
    /// ## Example
    /// ```swift
    /// let formula = LTL.W(maintain, upgrade)
    /// ```
    public static func W<P: TemporalProposition>(
        _ lhs: LTLFormula<P>,
        _ rhs: LTLFormula<P>
    ) -> LTLFormula<P> {
        .weakUntil(lhs, rhs)
    }

    /// Standard RELEASE operator.
    /// 
    /// ## Example
    /// ```swift
    /// let formula = LTL.R(reset, locked)
    /// ```
    public static func R<P: TemporalProposition>(
        _ lhs: LTLFormula<P>,
        _ rhs: LTLFormula<P>
    ) -> LTLFormula<P> {
        .release(lhs, rhs)
    }
}
