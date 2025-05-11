import Foundation

// Assumes LTLFormula and TemporalProposition are defined and accessible globally or via import.

internal struct LTLFormulaNNFConverter {

    /// Converts an LTL formula to its Negation Normal Form (NNF).
    /// In NNF, negations are applied only to atomic propositions.
    internal static func convert<P: TemporalProposition>(_ formula: LTLFormula<P>) -> LTLFormula<P> where P.Value == Bool {
        // print("LTLFormulaNNFConverter.convert: Implementing NNF conversion.") // Original debug print
        switch formula {
        // Base cases for NNF:
        case .booleanLiteral(_):
            return formula
        case .atomic(_):
            return formula
        case .not(.atomic(_)): // Negation is already at an atomic proposition
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
            // The result G(¬φ) must itself be fully NNF'd to false R (¬φ)
            let gNotSub = LTLFormula.globally(convert(.not(subFormula)))
            return convert(gNotSub) // Convert the produced G formula

        case .not(.globally(let subFormula)): // ¬(G φ)    ->  F (¬φ) (NNF)
            // The result F(¬φ) must itself be fully NNF'd to true U (¬φ)
            let fNotSub = LTLFormula.eventually(convert(.not(subFormula)))
            return convert(fNotSub) // Convert the produced F formula

        case .not(.until(let lhs, let rhs)): // ¬(φ U ψ)  ->  (¬ψ R ¬φ) (NNF)
            // Note: This definition of Release (R) assumes ¬φ R ¬ψ.
            // Some texts define φ R ψ differently, e.g. as ¬(¬φ U ¬ψ).
            // Ensure consistency with the Release operator's expansion in the tableau.
            return .release(convert(.not(rhs)), convert(.not(lhs)))
        
        case .not(.weakUntil(let lhs, let rhs)):
            // φ W ψ  ≡  (φ U ψ) ∨ Gφ
            // So, ¬(φ W ψ) ≡ ¬((φ U ψ) ∨ Gφ)
            //              ≡ ¬(φ U ψ) ∧ ¬(Gφ)
            //              ≡ (¬φ R ¬ψ) ∧ (F¬φ)  (using ¬Gφ -> F¬φ)
            let term1 = LTLFormula.release(convert(.not(lhs)), convert(.not(rhs)))
            let term2 = LTLFormula.eventually(convert(.not(lhs))) // NNF of ¬Gφ is F(NNF(¬φ))
            return .and(term1, term2)

        case .not(.release(let lhs, let rhs)): // ¬(φ R ψ)  ->  (¬φ U ¬ψ) (NNF)
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
