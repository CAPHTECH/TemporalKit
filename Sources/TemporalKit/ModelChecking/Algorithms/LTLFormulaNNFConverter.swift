import Foundation

// Assumes LTLFormula and TemporalProposition are defined and accessible globally or via import.

internal struct LTLFormulaNNFConverter {

    /// Converts an LTL formula to its Negation Normal Form (NNF).
    /// In NNF, negations are applied only to atomic propositions.
    internal static func convert<P: TemporalProposition>(_ formula: LTLFormula<P>) -> LTLFormula<P> where P.Value == Bool {
        // print("LTLFormulaNNFConverter.convert: Implementing NNF conversion.") // Original debug print
        switch formula {
        // Base cases for NNF:
        case .booleanLiteral:
            return formula
        case .atomic:
            return formula
        case .not(.atomic): // Negation is already at an atomic proposition
            return formula
        case .not(.booleanLiteral(let b)): // ¬true -> false, ¬false -> true
             return .booleanLiteral(!b)

        // Recursive cases:
        case .not(.not(let subFormula)): // ¬(¬φ)  ->  φ (NNF)
            return convert(subFormula)

        case .not(.and(let lhs, let rhs)): // ¬(φ ∧ ψ)  ->  (¬φ ∨ ¬ψ) (NNF)
            return .or(convert(.not(lhs)), convert(.not(rhs)))

        case .not(.or(let lhs, let rhs)): // ¬(φ ∨ ψ)  ->  (¬φ ∧ ¬ψ) (NNF)
            return .and(convert(.not(lhs)), convert(.not(rhs)))

        case .not(.implies(let lhs, let rhs)): // ¬(φ → ψ) is ¬(¬φ ∨ ψ) which is (φ ∧ ¬ψ) (NNF)
            return .and(convert(lhs), convert(.not(rhs)))

        case .not(.next(let subFormula)): // ¬(X φ)    ->  X (¬φ) (NNF)
            return .next(convert(.not(subFormula)))

        case .not(.eventually(let subFormula)): // ¬(F φ)    ->  G (¬φ) (NNF)
            // F φ = true U φ, so ¬(F φ) = ¬(true U φ) = false R ¬φ = G ¬φ
            let gNotSub = LTLFormula.globally(convert(.not(subFormula)))
            return convert(gNotSub) // Convert the produced G formula

        case .not(.globally(let subFormula)): // ¬(G φ)    ->  F (¬φ) (NNF)
            // G φ = false R φ, so ¬(G φ) = ¬(false R φ) = true U ¬φ = F ¬φ
            let fNotSub = LTLFormula.eventually(convert(.not(subFormula)))
            return convert(fNotSub) // Convert the produced F formula

        case .not(.until(let lhs, let rhs)):
            // ¬(φ U ψ)  ->  (¬ψ R ¬φ) (NNF)
            // This is a fundamental duality in LTL: 
            // The negation of "φ holds until ψ holds" is
            // "¬ψ holds, RELEASED only when ¬φ also holds"
            //
            // To verify: For this formula to be false, either:
            // 1. ψ never holds (¬ψ always holds), OR
            // 2. φ fails to hold before ψ (¬φ holds at some point before ψ)
            // This is exactly what (¬ψ R ¬φ) encodes.
            return .release(convert(.not(rhs)), convert(.not(lhs)))

        case .not(.weakUntil(let lhs, let rhs)):
            // φ W ψ  ≡  (φ U ψ) ∨ Gφ
            // So, ¬(φ W ψ) ≡ ¬((φ U ψ) ∨ Gφ)
            //              ≡ ¬(φ U ψ) ∧ ¬(Gφ)
            //              ≡ (¬ψ R ¬φ) ∧ (F¬φ)  (using ¬(φ U ψ) -> (¬ψ R ¬φ) and ¬Gφ -> F¬φ)
            let term1 = LTLFormula.release(convert(.not(rhs)), convert(.not(lhs)))
            let term2 = LTLFormula.eventually(convert(.not(lhs)))
            return .and(term1, term2)

        case .not(.release(let lhs, let rhs)):
            // ¬(φ R ψ)  ->  (¬φ U ¬ψ) (NNF)
            // This is the dual of the Until negation above.
            // The negation of "φ releases ψ from having to hold" is
            // "¬φ holds until both ¬φ and ¬ψ hold"
            return .until(convert(.not(lhs)), convert(.not(rhs)))

        // Operators that distribute NNF transformation:
        case .and(let lhs, let rhs):
            return .and(convert(lhs), convert(rhs))
        case .or(let lhs, let rhs):
            return .or(convert(lhs), convert(rhs))

        case .implies(let lhs, let rhs): // φ → ψ  is  ¬φ ∨ ψ. Apply NNF to this structure.
            return .or(convert(.not(lhs)), convert(rhs))

        case .next(let subFormula):
            return .next(convert(subFormula))

        case .eventually(let subFormula): // F φ  ≡  true U φ. Convert to NNF of (true U NNF(subFormula)).
            return .until(.booleanLiteral(true), convert(subFormula))

        case .globally(let subFormula): // G φ  ≡  false R φ. Convert to NNF of (false R NNF(subFormula)).
            return .release(.booleanLiteral(false), convert(subFormula))

        case .until(let lhs, let rhs):
            return .until(convert(lhs), convert(rhs))
        case .weakUntil(let lhs, let rhs): // For NNF, W(NNF(φ), NNF(ψ)) is fine.
                                        // φ W ψ ≡ (φ U ψ) ∨ Gφ. NNF is applied to children.
            return .weakUntil(convert(lhs), convert(rhs))
        case .release(let lhs, let rhs):
            return .release(convert(lhs), convert(rhs))
        }
    }
}
