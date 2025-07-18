import Foundation

extension LTLFormula {
    /// Evaluates the LTL formula in the current evaluation context and determines the formula for the next state.
    ///
    /// The `step` function is crucial for runtime verification or trace checking. It embodies the recursive
    /// definition of LTL semantics. For a given LTL formula and an `EvaluationContext` (representing the
    /// current state of the system), it returns a tuple:
    ///   - `holdsNow`: A `Bool` indicating whether the formula (or its relevant part for the current step)
    ///                 is true in the current context.
    ///   - `nextFormula`: An `LTLFormula<P>` representing the obligation that must be satisfied by the
    ///                    remainder of the trace (i.e., from the next state onwards).
    ///
    /// - Parameter context: The `EvaluationContext` for the current time step.
    /// - Returns: A tuple `(holdsNow: Bool, nextFormula: LTLFormula<P>)`.
    /// - Throws: An error if proposition evaluation fails.
    public func step(with context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        switch self {
        case .atomic(let proposition):
            return try stepAtomic(proposition: proposition, context: context)
        case .booleanLiteral(let value):
            return stepBooleanLiteral(value: value)
        case .not(let subFormula):
            return try stepNot(subFormula: subFormula, context: context)
        case .and(let lhs, let rhs):
            return try stepAnd(lhs: lhs, rhs: rhs, context: context)
        case .or(let lhs, let rhs):
            return try stepOr(lhs: lhs, rhs: rhs, context: context)
        case .implies(let lhs, let rhs):
            return try stepImplies(lhs: lhs, rhs: rhs, context: context)
        case .next(let subFormula):
            return stepNext(subFormula: subFormula)
        case .eventually(let subFormula):
            return try stepEventually(subFormula: subFormula, context: context)
        case .globally(let subFormula):
            return try stepGlobally(subFormula: subFormula, context: context)
        case .until(let lhs, let rhs):
            return try stepUntil(lhs: lhs, rhs: rhs, context: context)
        case .weakUntil(let lhs, let rhs):
            return try stepWeakUntil(lhs: lhs, rhs: rhs, context: context)
        case .release(let lhs, let rhs):
            return try stepRelease(lhs: lhs, rhs: rhs, context: context)
        }
    }

    private func stepAtomic(proposition: P, context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // The value of an atomic proposition is determined by its evaluation in the current context.
        // The 'nextFormula' for an atomic proposition is its current truth value, as it's 'consumed'.
        let holds = try proposition.evaluate(in: context)
        return (holdsNow: holds, nextFormula: .booleanLiteral(holds))
    }

    private func stepBooleanLiteral(value: Bool) -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        return (value, .booleanLiteral(value))
    }

    private func stepNot(subFormula: LTLFormula<P>, context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        let (subHolds, subNext) = try subFormula.step(with: context)
        let nextStepFormula: LTLFormula<P>
        if case .booleanLiteral(let b) = subNext {
            nextStepFormula = .booleanLiteral(!b)
        } else {
            nextStepFormula = .not(subNext) // Negation propagates if subNext is not terminal
        }
        return (!subHolds, nextStepFormula)
    }

    private func stepAnd(lhs: LTLFormula<P>, rhs: LTLFormula<P>, context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        let (lhsHolds, lhsNext) = try lhs.step(with: context)
        let (rhsHolds, rhsNext) = try rhs.step(with: context)

        let currentHolds = lhsHolds && rhsHolds

        // Simplification for nextFormula for 'and': A && B
        // If A.next is false, result is false.
        // If B.next is false, result is false.
        // If A.next is true, result is B.next.
        // If B.next is true, result is A.next.
        if case .booleanLiteral(false) = lhsNext {
            return (currentHolds, .booleanLiteral(false))
        }
        if case .booleanLiteral(false) = rhsNext {
            return (currentHolds, .booleanLiteral(false))
        }
        if case .booleanLiteral(true) = lhsNext {
            return (currentHolds, rhsNext)
        }
        if case .booleanLiteral(true) = rhsNext {
            return (currentHolds, lhsNext)
        }
        return (currentHolds, .and(lhsNext, rhsNext))
    }

    private func stepOr(lhs: LTLFormula<P>, rhs: LTLFormula<P>, context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        let (lhsHolds, lhsNext) = try lhs.step(with: context)

        // Early simplification: if lhsNext is true, the OR is satisfied
        if case .booleanLiteral(true) = lhsNext {
            return (true, .booleanLiteral(true))
        }

        // If lhs doesn't hold now and its next is false, result depends entirely on rhs
        if !lhsHolds, case .booleanLiteral(false) = lhsNext {
            let (rhsHolds, rhsNext) = try rhs.step(with: context)
            return (rhsHolds, rhsNext)
        }

        // Evaluate rhs for complete next formula calculation
        let (rhsHolds, rhsNext) = try rhs.step(with: context)
        let currentHolds = lhsHolds || rhsHolds

        // Simplification for nextFormula
        if case .booleanLiteral(true) = rhsNext {
            return (currentHolds, .booleanLiteral(true))
        }
        if case .booleanLiteral(false) = lhsNext {
            return (currentHolds, rhsNext)
        }
        if case .booleanLiteral(false) = rhsNext {
            return (currentHolds, lhsNext)
        }
        return (currentHolds, .or(lhsNext, rhsNext))
    }

    private func stepImplies(lhs: LTLFormula<P>, rhs: LTLFormula<P>,
                              context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // p -> q is equivalent to !p || q
        let (lhsHoldsNow, lhsNextFormula) = try lhs.step(with: context)
        let (rhsHoldsNow, rhsNextFormula) = try rhs.step(with: context)

        let currentHolds = !lhsHoldsNow || rhsHoldsNow

        // For nextFormula: implies(lhsNextFormula, rhsNextFormula) is !lhsNextFormula || rhsNextFormula
        // Apply OR simplifications to (.not(lhsNextFormula), rhsNextFormula)
        let notLhsNext: LTLFormula<P>
        if case .booleanLiteral(let b) = lhsNextFormula {
            notLhsNext = .booleanLiteral(!b)
        } else {
            notLhsNext = .not(lhsNextFormula)
        }

        if case .booleanLiteral(true) = notLhsNext { // If !LHS.next is true, then (!LHS.next || RHS.next) is true
            return (currentHolds, .booleanLiteral(true))
        }
        if case .booleanLiteral(true) = rhsNextFormula { // If RHS.next is true, then (!LHS.next || RHS.next) is true
            return (currentHolds, .booleanLiteral(true))
        }
        // At this point, notLhsNext and rhsNextFormula are not .booleanLiteral(true)
        if case .booleanLiteral(false) = notLhsNext { // If !LHS.next is false, then result is RHS.next
            return (currentHolds, rhsNextFormula)
        }
        if case .booleanLiteral(false) = rhsNextFormula { // If RHS.next is false, then result is !LHS.next
            return (currentHolds, notLhsNext) // Which is .not(lhsNextFormula) or simplified literal
        }
        // Default if no simplification: .or(.not(lhsNextFormula), rhsNextFormula)
        // which is the definition of .implies(lhsNextFormula, rhsNextFormula)
        return (currentHolds, .implies(lhsNextFormula, rhsNextFormula))
    }

    private func stepNext(subFormula: LTLFormula<P>) -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // `X p` (Next p): holdsNow is true (vacuously), nextFormula is p.
        return (true, subFormula)
    }

    private func stepEventually(subFormula: LTLFormula<P>, context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // F p == p || X (F p)
        let (subHolds, _) = try subFormula.step(with: context)
        if subHolds {
            return (true, .booleanLiteral(true)) // p holds, so F p is satisfied
        } else {
            // p does not hold now, so F p must hold from the next state onwards
            return (false, self)
        }
    }

    private func stepGlobally(subFormula: LTLFormula<P>,
                              context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // G p == p && X (G p)
        let (subHolds, subNext) = try subFormula.step(with: context)
        if !subHolds {
            return (false, .booleanLiteral(false)) // G p fails immediately
        } else if case .booleanLiteral(true) = subNext {
            // If subNext is true, G p is satisfied
            return (true, self) // Continue checking globally
        } else if case .booleanLiteral(false) = subNext {
            // If subNext is false, G p will fail in the next step
            return (true, .booleanLiteral(false))
        } else {
            return (true, self) // Continue checking globally
        }
    }

    private func stepUntil(lhs: LTLFormula<P>, rhs: LTLFormula<P>,
                           context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // p U q == q || (p && X(p U q))
        let (rhsHolds, rhsNext) = try rhs.step(with: context)
        if rhsHolds {
            return (true, .booleanLiteral(true)) // q holds, so p U q is satisfied
        }
        // q does not hold. Now check p.
        let (lhsHolds, lhsNext) = try lhs.step(with: context)
        if lhsHolds {
            // Optimize: if either will definitely fail, fail now
            if case .booleanLiteral(false) = lhsNext {
                return (true, .booleanLiteral(false))
            }
            if case .booleanLiteral(false) = rhsNext {
                return (true, .booleanLiteral(false))
            }
            return (true, self) // Continue until obligation
        } else {
            return (false, .booleanLiteral(false)) // p must hold until q
        }
    }

    private func stepWeakUntil(lhs: LTLFormula<P>, rhs: LTLFormula<P>,
                               context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // p W q == q || (p && X(p W q))
        let (rhsHolds, _) = try rhs.step(with: context)
        if rhsHolds {
            return (true, .booleanLiteral(true)) // q holds, p W q is satisfied
        }
        let (lhsHolds, _) = try lhs.step(with: context)
        if lhsHolds {
            return (true, self) // Continue weak until obligation
        }
        return (false, .booleanLiteral(false)) // p must hold until q (or forever)
    }

    private func stepRelease(lhs: LTLFormula<P>, rhs: LTLFormula<P>,
                             context: EvaluationContext) throws -> (holdsNow: Bool, nextFormula: LTLFormula<P>) {
        // p R q == q && (p || X(p R q))
        let (rhsHolds, rhsNext) = try rhs.step(with: context)
        if !rhsHolds {
            return (false, .booleanLiteral(false)) // q must hold for p R q to hold
        }
        // q holds. Now check p.
        let (lhsHolds, _) = try lhs.step(with: context)
        if lhsHolds {
            return (true, .booleanLiteral(true)) // Both p and q hold, release satisfied
        } else {
            // q holds, but p does not. Check if release can continue
            if case .booleanLiteral(false) = rhsNext {
                return (true, .booleanLiteral(false)) // q will fail, so release fails
            }
            return (true, self) // Continue release obligation
        }
    }
}
