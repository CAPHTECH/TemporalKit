import Foundation

extension LTLFormula {
    /// Returns a normalized version of the LTL formula using standard LTL normalization.
    ///
    /// Normalization converts the formula to Negation Normal Form (NNF) and applies simplifications:
    /// - Eliminates implications: A → B becomes ¬A ∨ B
    /// - Pushes negations inward using De Morgan's laws
    /// - Eliminates double negations: ¬¬A → A
    /// - Applies boolean simplifications with constants
    /// - Simplifies temporal operators where possible
    ///
    /// - Returns: A normalized LTL formula in NNF that is semantically equivalent.
    public func normalized() -> LTLFormula<P> {
        var current = self
        var previous: LTLFormula<P>
        var iterations = 0
        let maxIterations = 15 // Increased to handle newly created formulas

        // Fixed-point iteration to ensure complete normalization
        // This handles newly created formulas from simplifyConstants phase
        repeat {
            previous = current
            current = current.eliminateImplications()
                           .pushNegationsInward()
                           .simplifyConstants()
            iterations += 1
        } while current != previous && iterations < maxIterations

        // Additional safety check for convergence
        if iterations >= maxIterations {
            // Log warning but return the last valid result rather than crash
            // In practice, well-formed LTL formulas should converge within 10 iterations
            #if DEBUG
            print("Warning: LTL normalization reached maximum iterations. Formula may be complex.")
            #endif
        }

        return current
    }

    /// Eliminates all implication operators by converting A → B to ¬A ∨ B
    private func eliminateImplications() -> LTLFormula<P> {
        switch self {
        case .atomic, .booleanLiteral:
            return self

        case .not(let subFormula):
            return .not(subFormula.eliminateImplications())

        case .and(let lhs, let rhs):
            return .and(lhs.eliminateImplications(), rhs.eliminateImplications())

        case .or(let lhs, let rhs):
            return .or(lhs.eliminateImplications(), rhs.eliminateImplications())

        case .implies(let lhs, let rhs):
            // A → B becomes ¬A ∨ B
            return .or(.not(lhs.eliminateImplications()), rhs.eliminateImplications())

        case .next(let subFormula):
            return .next(subFormula.eliminateImplications())

        case .eventually(let subFormula):
            return .eventually(subFormula.eliminateImplications())

        case .globally(let subFormula):
            return .globally(subFormula.eliminateImplications())

        case .until(let lhs, let rhs):
            return .until(lhs.eliminateImplications(), rhs.eliminateImplications())

        case .weakUntil(let lhs, let rhs):
            return .weakUntil(lhs.eliminateImplications(), rhs.eliminateImplications())

        case .release(let lhs, let rhs):
            return .release(lhs.eliminateImplications(), rhs.eliminateImplications())
        }
    }

    /// Pushes negations inward using De Morgan's laws and double negation elimination
    private func pushNegationsInward() -> LTLFormula<P> {
        switch self {
        case .atomic, .booleanLiteral:
            return self

        case .not(let subFormula):
            switch subFormula {
            case .not(let doubleNegated):
                // Double negation: ¬¬A → A
                return doubleNegated.pushNegationsInward()

            case .and(let lhs, let rhs):
                // De Morgan: ¬(A ∧ B) → ¬A ∨ ¬B
                return .or(.not(lhs).pushNegationsInward(), .not(rhs).pushNegationsInward())

            case .or(let lhs, let rhs):
                // De Morgan: ¬(A ∨ B) → ¬A ∧ ¬B
                return .and(.not(lhs).pushNegationsInward(), .not(rhs).pushNegationsInward())

            case .booleanLiteral(let value):
                return .booleanLiteral(!value)

            case .eventually(let inner):
                // ¬F(A) → G(¬A)
                return .globally(.not(inner).pushNegationsInward())

            case .globally(let inner):
                // ¬G(A) → F(¬A)
                return .eventually(.not(inner).pushNegationsInward())

            case .until(let lhs, let rhs):
                // ¬(A U B) → (¬A ∧ ¬B) R ¬B (correct duality)
                // Optimize: avoid creating intermediate formulas if possible
                let negatedLhs = LTLFormula<P>.not(lhs).pushNegationsInward()
                let negatedRhs = LTLFormula<P>.not(rhs).pushNegationsInward()
                return .release(.and(negatedLhs, negatedRhs), negatedRhs)

            case .weakUntil(let lhs, let rhs):
                // ¬(A W B) → ¬B U (¬A ∧ ¬B)
                // Optimize: reuse negated formulas
                let negatedLhs = LTLFormula<P>.not(lhs).pushNegationsInward()
                let negatedRhs = LTLFormula<P>.not(rhs).pushNegationsInward()
                return .until(negatedRhs, .and(negatedLhs, negatedRhs))

            case .release(let lhs, let rhs):
                // ¬(A R B) → ¬B U (¬A ∧ ¬B)
                // Optimize: reuse negated formulas
                let negatedLhs = LTLFormula<P>.not(lhs).pushNegationsInward()
                let negatedRhs = LTLFormula<P>.not(rhs).pushNegationsInward()
                return .until(negatedRhs, .and(negatedLhs, negatedRhs))

            case .next(let inner):
                // ¬X(A) → X(¬A)
                return .next(LTLFormula<P>.not(inner).pushNegationsInward())

            case .atomic:
                // Atomic propositions stay negated
                return .not(subFormula)

            case .implies:
                // This should not occur after eliminateImplications phase
                fatalError("Implication found in pushNegationsInward phase - normalization error")
            }

        case .and(let lhs, let rhs):
            return .and(lhs.pushNegationsInward(), rhs.pushNegationsInward())

        case .or(let lhs, let rhs):
            return .or(lhs.pushNegationsInward(), rhs.pushNegationsInward())

        case .next(let subFormula):
            return .next(subFormula.pushNegationsInward())

        case .eventually(let subFormula):
            return .eventually(subFormula.pushNegationsInward())

        case .globally(let subFormula):
            return .globally(subFormula.pushNegationsInward())

        case .until(let lhs, let rhs):
            return .until(lhs.pushNegationsInward(), rhs.pushNegationsInward())

        case .weakUntil(let lhs, let rhs):
            return .weakUntil(lhs.pushNegationsInward(), rhs.pushNegationsInward())

        case .release(let lhs, let rhs):
            return .release(lhs.pushNegationsInward(), rhs.pushNegationsInward())

        case .implies:
            // This should not occur after eliminateImplications phase
            fatalError("Implication found in pushNegationsInward phase - normalization error")
        }
    }

    /// Applies constant simplifications and other reductions
    /// Note: Newly created formulas are marked for re-normalization via fixed-point iteration
    private func simplifyConstants() -> LTLFormula<P> {
        switch self {
        case .atomic, .booleanLiteral:
            return self

        case .not(let subFormula):
            let simplified = subFormula.simplifyConstants()
            if case .booleanLiteral(let value) = simplified {
                return .booleanLiteral(!value)
            }
            return .not(simplified)

        case .and(let lhs, let rhs):
            let simplifiedLhs = lhs.simplifyConstants()
            let simplifiedRhs = rhs.simplifyConstants()

            // Constant propagation
            if case .booleanLiteral(false) = simplifiedLhs { return .booleanLiteral(false) }
            if case .booleanLiteral(false) = simplifiedRhs { return .booleanLiteral(false) }
            if case .booleanLiteral(true) = simplifiedLhs { return simplifiedRhs }
            if case .booleanLiteral(true) = simplifiedRhs { return simplifiedLhs }

            // Idempotency and contradiction
            if simplifiedLhs == simplifiedRhs { return simplifiedLhs }
            if case .not(let inner) = simplifiedRhs, inner == simplifiedLhs { return .booleanLiteral(false) }
            if case .not(let inner) = simplifiedLhs, inner == simplifiedRhs { return .booleanLiteral(false) }

            return .and(simplifiedLhs, simplifiedRhs)

        case .or(let lhs, let rhs):
            let simplifiedLhs = lhs.simplifyConstants()
            let simplifiedRhs = rhs.simplifyConstants()

            // Constant propagation
            if case .booleanLiteral(true) = simplifiedLhs { return .booleanLiteral(true) }
            if case .booleanLiteral(true) = simplifiedRhs { return .booleanLiteral(true) }
            if case .booleanLiteral(false) = simplifiedLhs { return simplifiedRhs }
            if case .booleanLiteral(false) = simplifiedRhs { return simplifiedLhs }

            // Idempotency and tautology
            if simplifiedLhs == simplifiedRhs { return simplifiedLhs }
            if case .not(let inner) = simplifiedRhs, inner == simplifiedLhs { return .booleanLiteral(true) }
            if case .not(let inner) = simplifiedLhs, inner == simplifiedRhs { return .booleanLiteral(true) }

            return .or(simplifiedLhs, simplifiedRhs)

        case .next(let subFormula):
            return .next(subFormula.simplifyConstants())

        case .eventually(let subFormula):
            let simplified = subFormula.simplifyConstants()
            if case .booleanLiteral(true) = simplified { return .booleanLiteral(true) }
            if case .booleanLiteral(false) = simplified { return .booleanLiteral(false) }

            // F(F(A)) → F(A) - idempotency
            if case .eventually(let inner) = simplified {
                // Inner formula is already simplified, no further normalization needed
                return .eventually(inner)
            }

            return .eventually(simplified)

        case .globally(let subFormula):
            let simplified = subFormula.simplifyConstants()
            if case .booleanLiteral(true) = simplified { return .booleanLiteral(true) }
            if case .booleanLiteral(false) = simplified { return .booleanLiteral(false) }

            // G(G(A)) → G(A) - idempotency
            if case .globally(let inner) = simplified {
                // Inner formula is already simplified, no further normalization needed
                return .globally(inner)
            }

            return .globally(simplified)

        case .until(let lhs, let rhs):
            let simplifiedLhs = lhs.simplifyConstants()
            let simplifiedRhs = rhs.simplifyConstants()

            if case .booleanLiteral(true) = simplifiedRhs { return .booleanLiteral(true) }
            if case .booleanLiteral(false) = simplifiedRhs { return .booleanLiteral(false) }
            if case .booleanLiteral(false) = simplifiedLhs { return simplifiedRhs }

            return .until(simplifiedLhs, simplifiedRhs)

        case .weakUntil(let lhs, let rhs):
            let simplifiedLhs = lhs.simplifyConstants()
            let simplifiedRhs = rhs.simplifyConstants()

            if case .booleanLiteral(true) = simplifiedRhs { return .booleanLiteral(true) }
            if case .booleanLiteral(false) = simplifiedRhs {
                // A W false → G(A)
                // The globally operator will be normalized in the next iteration
                return .globally(simplifiedLhs)
            }
            if case .booleanLiteral(false) = simplifiedLhs { return simplifiedRhs }

            return .weakUntil(simplifiedLhs, simplifiedRhs)

        case .release(let lhs, let rhs):
            let simplifiedLhs = lhs.simplifyConstants()
            let simplifiedRhs = rhs.simplifyConstants()

            if case .booleanLiteral(false) = simplifiedLhs {
                // false R B → G(B)
                // The globally operator will be normalized in the next iteration
                return .globally(simplifiedRhs)
            }
            if case .booleanLiteral(true) = simplifiedLhs { return simplifiedRhs }
            if case .booleanLiteral(false) = simplifiedRhs { return .booleanLiteral(false) }
            if case .booleanLiteral(true) = simplifiedRhs { return .booleanLiteral(true) }

            return .release(simplifiedLhs, simplifiedRhs)

        case .implies:
            // This should not occur after eliminateImplications phase
            fatalError("Implication found in simplifyConstants phase - normalization error")
        }
    }

    /// Normalizes this LTL formula in place.
    public mutating func normalize() {
        self = self.normalized()
    }
}
