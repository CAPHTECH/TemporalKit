import Foundation

public indirect enum LTLFormula<P: TemporalProposition>: Hashable where P.Value == Bool {
    case booleanLiteral(Bool)
    case atomic(P)
    case not(LTLFormula<P>)
    case and(LTLFormula<P>, LTLFormula<P>)
    case or(LTLFormula<P>, LTLFormula<P>)
    case implies(LTLFormula<P>, LTLFormula<P>)
    
    case next(LTLFormula<P>)
    case eventually(LTLFormula<P>)
    case globally(LTLFormula<P>)
    
    case until(LTLFormula<P>, LTLFormula<P>)
    case weakUntil(LTLFormula<P>, LTLFormula<P>)
    case release(LTLFormula<P>, LTLFormula<P>)

    // Discriminator values for hash computation
    private enum FormulaDiscriminator: Int, CaseIterable {
        case booleanLiteral = 0
        case atomic = 1
        case not = 2
        case and = 3
        case or = 4
        case implies = 5
        case next = 6
        case eventually = 7
        case globally = 8
        case until = 9
        case weakUntil = 10
        case release = 11
    }
    
    // Recursive Hashable conformance
    public func hash(into hasher: inout Hasher) {
        // Use discriminator values for better performance
        switch self {
        case .booleanLiteral(let value):
            hasher.combine(FormulaDiscriminator.booleanLiteral.rawValue)
            hasher.combine(value)
        case .atomic(let prop):
            hasher.combine(FormulaDiscriminator.atomic.rawValue)
            hasher.combine(prop)
        case .not(let formula):
            hasher.combine(FormulaDiscriminator.not.rawValue)
            hasher.combine(formula)
        case .and(let lhs, let rhs):
            hasher.combine(FormulaDiscriminator.and.rawValue)
            hasher.combine(lhs)
            hasher.combine(rhs)
        case .or(let lhs, let rhs):
            hasher.combine(FormulaDiscriminator.or.rawValue)
            hasher.combine(lhs)
            hasher.combine(rhs)
        case .implies(let lhs, let rhs):
            hasher.combine(FormulaDiscriminator.implies.rawValue)
            hasher.combine(lhs)
            hasher.combine(rhs)
        case .next(let formula):
            hasher.combine(FormulaDiscriminator.next.rawValue)
            hasher.combine(formula)
        case .eventually(let formula):
            hasher.combine(FormulaDiscriminator.eventually.rawValue)
            hasher.combine(formula)
        case .globally(let formula):
            hasher.combine(FormulaDiscriminator.globally.rawValue)
            hasher.combine(formula)
        case .until(let lhs, let rhs):
            hasher.combine(FormulaDiscriminator.until.rawValue)
            hasher.combine(lhs)
            hasher.combine(rhs)
        case .weakUntil(let lhs, let rhs):
            hasher.combine(FormulaDiscriminator.weakUntil.rawValue)
            hasher.combine(lhs)
            hasher.combine(rhs)
        case .release(let lhs, let rhs):
            hasher.combine(FormulaDiscriminator.release.rawValue)
            hasher.combine(lhs)
            hasher.combine(rhs)
        }
    }

    // Recursive Equatable conformance (Swift can synthesize this if P is Equatable, but explicit for clarity)
    public static func == (lhs: LTLFormula<P>, rhs: LTLFormula<P>) -> Bool {
        switch (lhs, rhs) {
        case (.booleanLiteral(let lVal), .booleanLiteral(let rVal)):
            return lVal == rVal
        case (.atomic(let lProp), .atomic(let rProp)):
            return lProp == rProp
        case (.not(let lForm), .not(let rForm)):
            return lForm == rForm
        case (.and(let lLhs, let lRhs), .and(let rLhs, let rRhs)):
            return lLhs == rLhs && lRhs == rRhs
        case (.or(let lLhs, let lRhs), .or(let rLhs, let rRhs)):
            return lLhs == rLhs && lRhs == rRhs
        case (.implies(let lLhs, let lRhs), .implies(let rLhs, let rRhs)):
            return lLhs == rLhs && lRhs == rRhs
        case (.next(let lForm), .next(let rForm)):
            return lForm == rForm
        case (.eventually(let lForm), .eventually(let rForm)):
            return lForm == rForm
        case (.globally(let lForm), .globally(let rForm)):
            return lForm == rForm
        case (.until(let lLhs, let lRhs), .until(let rLhs, let rRhs)):
            return lLhs == rLhs && lRhs == rRhs
        case (.weakUntil(let lLhs, let lRhs), .weakUntil(let rLhs, let rRhs)):
            return lLhs == rLhs && lRhs == rRhs
        case (.release(let lLhs, let lRhs), .release(let rLhs, let rRhs)):
            return lLhs == rLhs && lRhs == rRhs
        default:
            return false
        }
    }

    // MARK: - Computed Properties

    /// Returns `true` if the formula is an atomic proposition or a boolean literal.
    public var isAtomic: Bool {
        switch self {
        case .atomic, .booleanLiteral:
            return true
        default:
            return false
        }
    }
}
