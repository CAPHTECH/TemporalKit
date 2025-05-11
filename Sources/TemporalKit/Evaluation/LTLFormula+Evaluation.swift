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
            // The value of an atomic proposition is determined by its evaluation in the current context.
            // The 'nextFormula' for an atomic proposition is its current truth value, as it's 'consumed'.
            let holds = try proposition.evaluate(in: context)
            return (holdsNow: holds, nextFormula: .booleanLiteral(holds))
            
        case .booleanLiteral(let value):
            return (value, .booleanLiteral(value))

        case .not(let subFormula):
            let (subHolds, subNext) = try subFormula.step(with: context)
            let nextStepFormula: LTLFormula<P>
            if case .booleanLiteral(let b) = subNext {
                nextStepFormula = .booleanLiteral(!b)
            } else {
                nextStepFormula = .not(subNext) // Negation propagates if subNext is not terminal
            }
            return (!subHolds, nextStepFormula)

        case .and(let lhs, let rhs):
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

        case .or(let lhs, let rhs):
            let (lhsHolds, lhsNext) = try lhs.step(with: context)
            // For OR, if lhsHolds is true, we know currentHolds is true.
            // However, to determine the correct nextFormula (lhsNext || rhsNext),
            // we generally need to evaluate rhs as well, unless lhsNext itself implies true for the OR.

            // Short-circuit for holdsNow: if lhsHolds is true, currentHolds is true.
            // The evaluation of rhs is still needed for nextFormula calculation.
            // If rhs.step() throws, the error propagates, as nextFormula cannot be determined.
            let (rhsHolds, rhsNext) : (Bool, LTLFormula<P>) // Declare explicitly for clarity
            if lhsHolds {
                // If lhsHolds is true, currentHolds is true.
                // We still need to evaluate rhs.step() for its nextFormula, but its holdsNow value doesn't affect currentHolds.
                // If an error occurs in rhs.step(), it should propagate as we can't form the complete next state.
                // The test `testStepOr_LhsTrue_RhsThrows_ShortCircuit` might need adjustment if it expects error suppression here.
                (rhsHolds, rhsNext) = try rhs.step(with: context) 
                // rhsHolds is effectively ignored for currentHolds if lhsHolds is true.
            } else {
                // lhsHolds is false, so currentHolds and nextFormula depend on rhs.
                (rhsHolds, rhsNext) = try rhs.step(with: context)
            }

            let currentHolds = lhsHolds || rhsHolds

            // Simplification for nextFormula for 'or': A || B
            // If A.next is true, result is true.
            // If B.next is true, result is true.
            // If A.next is false, result is B.next.
            // If B.next is false, result is A.next.
            if case .booleanLiteral(true) = lhsNext { 
                return (currentHolds, .booleanLiteral(true))
            }
            if case .booleanLiteral(true) = rhsNext { 
                return (currentHolds, .booleanLiteral(true))
            }
            if case .booleanLiteral(false) = lhsNext { // Applies if lhsHolds was false and its next is false
                return (currentHolds, rhsNext)
            }
            if case .booleanLiteral(false) = rhsNext { 
                return (currentHolds, lhsNext)
            }
            return (currentHolds, .or(lhsNext, rhsNext))

        case .implies(let lhs, let rhs):
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

        case .next(let subFormula):
            // `X p` (Next p): holdsNow is true (vacuously), nextFormula is p.
            return (true, subFormula)
        
        case .eventually(let subFormula):
            // F p == p || X (F p)
            let (subHolds, _) = try subFormula.step(with: context) // Evaluate p for holdsNow
            if subHolds {
                return (true, .booleanLiteral(true)) // p holds, so F p is satisfied, next is True (nothing more needed)
            } else {
                // p does not hold now, so F p must hold from the next state onwards.
                // The 'self' refers to the original F p formula for the next state.
                return (false, self) 
            }

        case .globally(let subFormula):
            // G p == p && X (G p)
            let (subHolds, _) = try subFormula.step(with: context) // Evaluate p for holdsNow
            // The 'nextFormula' for G p is G p itself.
            // If subHolds is false, then G p is false now. The overall holdsNow will be false.
            // If subHolds is true, then G p *could* be true, depending on X(G p).
            // The obligation passed to the next step is still G p.
            return (holdsNow: subHolds, nextFormula: self)

        case .until(let lhs, let rhs):
            // p U q == q || (p && X(p U q))
            let (rhsHolds, _) = try rhs.step(with: context) // Evaluate q for holdsNow
            if rhsHolds {
                return (true, .booleanLiteral(true)) // q holds, so p U q is satisfied, next is True
            }
            // q does not hold. Now check p.
            let (lhsHolds, _) = try lhs.step(with: context) // Evaluate p for holdsNow
            if lhsHolds {
                // p holds, and q does not. Obligation p U q carries to the next state.
                return (true, self) 
            } else {
                // Neither q nor p holds in the current state. p U q fails, next is False.
                return (false, .booleanLiteral(false))
            }

        case .weakUntil(let lhs, let rhs):
            // p W q == q || (p && X(p W q))  (similar to Until but doesn't require q to eventually be true if p always is)
            let (rhsHolds, _) = try rhs.step(with: context)
            if rhsHolds {
                return (true, .booleanLiteral(true)) // q holds, p W q is satisfied
            }
            let (lhsHolds, _) = try lhs.step(with: context)
            if lhsHolds {
                // p holds, and q does not. Obligation p W q carries to the next state.
                return (true, self)
            }
            // Neither q nor p holds. p W q fails for this step (unless G p semantic kicks in for finite trace, which step doesn't know)
            return (false, .booleanLiteral(false))

        case .release(let lhs, let rhs):
            // p R q == q && (p || X(p R q))
            let (rhsHolds, _) = try rhs.step(with: context) // Evaluate q for holdsNow
            if !rhsHolds {
                return (false, .booleanLiteral(false)) // q must hold for p R q to hold
            }
            // q holds. Now check p.
            let (lhsHolds, _) = try lhs.step(with: context) // Evaluate p for holdsNow
            if lhsHolds {
                // Both q and p hold. p R q is satisfied for current step.
                // The X(p R q) part isn't strictly needed if p is true now, so next is True.
                return (true, .booleanLiteral(true)) 
            } else {
                // q holds, but p does not. Obligation p R q (specifically X(p R q) part, while q continues to hold)
                // carries to the next state. So current holds true, next is self.
                return (true, self) 
            }
        }
    }
}
