import Testing
import Foundation // For UUID in MockProposition if used directly here, or for general utilities
@testable import TemporalKit

// We can reuse MockProposition from LTLDSLTests.swift if it's accessible
// For clarity, or if it's not directly accessible due to test target organization,
// we can define it again or a similar one here.
// Assuming MockProposition is accessible or can be redefined if needed:
final class PropertyTestMockProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = PropositionID(rawValue: id)!
        self.name = name
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        false // Not used for property tests
    }
}

struct LTLFormulaPropertyTests {

    let p = PropertyTestMockProposition(name: "p")
    let q = PropertyTestMockProposition(name: "q")

    @Test
    func testIsAtomicProperty() {
        let atomicP: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let literalTrue: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let literalFalse: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        #expect(atomicP.isAtomic == true, ".atomic(p) should be atomic.")
        #expect(literalTrue.isAtomic == true, ".booleanLiteral(true) should be atomic.")
        #expect(literalFalse.isAtomic == true, ".booleanLiteral(false) should be atomic.")

        let notP: LTLFormula<PropertyTestMockProposition> = .not(atomicP)
        let pAndQ: LTLFormula<PropertyTestMockProposition> = .and(atomicP, .atomic(q))
        let nextP: LTLFormula<PropertyTestMockProposition> = .next(atomicP)
        let eventuallyP: LTLFormula<PropertyTestMockProposition> = .eventually(atomicP)
        let globallyP: LTLFormula<PropertyTestMockProposition> = .globally(atomicP)
        let pUntilQ: LTLFormula<PropertyTestMockProposition> = .until(atomicP, .atomic(q))

        #expect(notP.isAtomic == false, ".not(p) should not be atomic.")
        #expect(pAndQ.isAtomic == false, ".and(p,q) should not be atomic.")
        #expect(nextP.isAtomic == false, ".next(p) should not be atomic.")
        #expect(eventuallyP.isAtomic == false, ".eventually(p) should not be atomic.")
        #expect(globallyP.isAtomic == false, ".globally(p) should not be atomic.")
        #expect(pUntilQ.isAtomic == false, ".until(p,q) should not be atomic.")
    }

    // MARK: - Equivalence and Normalization Tests

    @Test
    func testDeMorganAnd() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)

        // ¬(p && q)
        let lhs: LTLFormula<PropertyTestMockProposition> = .not(.and(pForm, qForm))
        // (¬p) || (¬q)
        let rhs: LTLFormula<PropertyTestMockProposition> = .or(.not(pForm), .not(qForm))

        #expect(lhs.normalized() == rhs.normalized(), "De Morgan: ¬(p && q) should normalize to be equivalent to (¬p) || (¬q)")
    }

    @Test
    func testDeMorganOr() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)

        // ¬(p || q)
        let lhs: LTLFormula<PropertyTestMockProposition> = .not(.or(pForm, qForm))
        // (¬p) && (¬q)
        let rhs: LTLFormula<PropertyTestMockProposition> = .and(.not(pForm), .not(qForm))

        #expect(lhs.normalized() == rhs.normalized(), "De Morgan: ¬(p || q) should normalize to be equivalent to (¬p) && (¬q)")
    }

    @Test
    func testDoubleNegation() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)

        // ¬(¬p)
        let doubleNegP: LTLFormula<PropertyTestMockProposition> = .not(.not(pForm))

        #expect(doubleNegP.normalized() == pForm.normalized(), "Double Negation: ¬(¬p) should normalize to p")
        // Note: Also asserting against pForm directly, assuming atomic(p) is already normalized.
        #expect(doubleNegP.normalized() == pForm, "Double Negation: ¬(¬p) should normalize to p")
    }

    @Test
    func testConstantPropagationAnd() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // true && p
        let trueAndP = LTLFormula<PropertyTestMockProposition>.and(trueLiteral, pForm)
        #expect(trueAndP.normalized() == pForm.normalized(), "Constant Propagation: true && p should normalize to p")
        #expect(trueAndP.normalized() == pForm, "Constant Propagation: true && p should normalize to p")

        // p && true 
        let pAndTrue = LTLFormula<PropertyTestMockProposition>.and(pForm, trueLiteral)
        #expect(pAndTrue.normalized() == pForm.normalized(), "Constant Propagation: p && true should normalize to p")
        #expect(pAndTrue.normalized() == pForm, "Constant Propagation: p && true should normalize to p")

        // false && p
        let falseAndP = LTLFormula<PropertyTestMockProposition>.and(falseLiteral, pForm)
        #expect(falseAndP.normalized() == falseLiteral.normalized(), "Constant Propagation: false && p should normalize to false")
        #expect(falseAndP.normalized() == falseLiteral, "Constant Propagation: false && p should normalize to false")

        // p && false
        let pAndFalse = LTLFormula<PropertyTestMockProposition>.and(pForm, falseLiteral)
        #expect(pAndFalse.normalized() == falseLiteral.normalized(), "Constant Propagation: p && false should normalize to false")
        #expect(pAndFalse.normalized() == falseLiteral, "Constant Propagation: p && false should normalize to false")
    }

    @Test
    func testConstantPropagationOr() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // true || p
        let trueOrP = LTLFormula<PropertyTestMockProposition>.or(trueLiteral, pForm)
        #expect(trueOrP.normalized() == trueLiteral.normalized(), "Constant Propagation: true || p should normalize to true")
        #expect(trueOrP.normalized() == trueLiteral, "Constant Propagation: true || p should normalize to true")

        // p || true 
        let pOrTrue = LTLFormula<PropertyTestMockProposition>.or(pForm, trueLiteral)
        #expect(pOrTrue.normalized() == trueLiteral.normalized(), "Constant Propagation: p || true should normalize to true")
        #expect(pOrTrue.normalized() == trueLiteral, "Constant Propagation: p || true should normalize to true")

        // false || p
        let falseOrP = LTLFormula<PropertyTestMockProposition>.or(falseLiteral, pForm)
        #expect(falseOrP.normalized() == pForm.normalized(), "Constant Propagation: false || p should normalize to p")
        #expect(falseOrP.normalized() == pForm, "Constant Propagation: false || p should normalize to p")

        // p || false
        let pOrFalse = LTLFormula<PropertyTestMockProposition>.or(pForm, falseLiteral)
        #expect(pOrFalse.normalized() == pForm.normalized(), "Constant Propagation: p || false should normalize to p")
        #expect(pOrFalse.normalized() == pForm, "Constant Propagation: p || false should normalize to p")
    }

    @Test
    func testBooleanSimplificationOr() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let notPForm: LTLFormula<PropertyTestMockProposition> = .not(pForm)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)

        // p || !p
        let pOrNotP = LTLFormula<PropertyTestMockProposition>.or(pForm, notPForm)
        #expect(pOrNotP.normalized() == trueLiteral, "Boolean Simplification: p || !p should normalize to true")

        // !p || p
        let notPOrP = LTLFormula<PropertyTestMockProposition>.or(notPForm, pForm)
        #expect(notPOrP.normalized() == trueLiteral, "Boolean Simplification: !p || p should normalize to true")
    }

    @Test
    func testBooleanSimplificationAnd() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let notPForm: LTLFormula<PropertyTestMockProposition> = .not(pForm)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // p && !p
        let pAndNotP = LTLFormula<PropertyTestMockProposition>.and(pForm, notPForm)
        #expect(pAndNotP.normalized() == falseLiteral, "Boolean Simplification: p && !p should normalize to false")

        // !p && p
        let notPAndP = LTLFormula<PropertyTestMockProposition>.and(notPForm, pForm)
        #expect(notPAndP.normalized() == falseLiteral, "Boolean Simplification: !p && p should normalize to false")
    }

    @Test
    func testReleaseNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // false R p -> G(p)
        let falseRp = LTLFormula<PropertyTestMockProposition>.release(falseLiteral, pForm)
        let globallyP = LTLFormula<PropertyTestMockProposition>.globally(pForm)
        // Note: G(p) might normalize further, so compare normalized forms
        #expect(falseRp.normalized() == globallyP.normalized(), "Release Norm: false R p should normalize to G(p)")

        // true R p -> p
        let trueRp = LTLFormula<PropertyTestMockProposition>.release(trueLiteral, pForm)
        #expect(trueRp.normalized() == pForm.normalized(), "Release Norm: true R p should normalize to p")
        #expect(trueRp.normalized() == pForm, "Release Norm: true R p should normalize to p")

        // p R false -> false
        let pRfalse = LTLFormula<PropertyTestMockProposition>.release(pForm, falseLiteral)
        #expect(pRfalse.normalized() == falseLiteral.normalized(), "Release Norm: p R false should normalize to false")
        #expect(pRfalse.normalized() == falseLiteral, "Release Norm: p R false should normalize to false")

        // p R true -> true
        let pRtrue = LTLFormula<PropertyTestMockProposition>.release(pForm, trueLiteral)
        #expect(pRtrue.normalized() == trueLiteral.normalized(), "Release Norm: p R true should normalize to true")
        #expect(pRtrue.normalized() == trueLiteral, "Release Norm: p R true should normalize to true")
    }

    @Test
    func testImpliesNormalization() {
        // A -> B normalizes to !A || B
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        let pImpliesQ: LTLFormula<PropertyTestMockProposition> = .implies(pForm, qForm)
        let notPOrQ: LTLFormula<PropertyTestMockProposition> = .or(.not(pForm), qForm)

        #expect(pImpliesQ.normalized() == notPOrQ.normalized(), "Implies Norm: A -> B should normalize to !A || B")
    }

    @Test
    func testNextNormalization() {
        // let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p) // Removed unused variable
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // X(true) -> true
        let xTrue = LTLFormula<PropertyTestMockProposition>.next(trueLiteral)
        #expect(xTrue.normalized() == trueLiteral, "Next Norm: X(true) should normalize to true")

        // X(false) -> false
        let xFalse = LTLFormula<PropertyTestMockProposition>.next(falseLiteral)
        #expect(xFalse.normalized() == falseLiteral, "Next Norm: X(false) should normalize to false")
    }

    @Test
    func testEventuallyNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // F(true) -> true
        let fTrue = LTLFormula<PropertyTestMockProposition>.eventually(trueLiteral)
        #expect(fTrue.normalized() == trueLiteral, "Eventually Norm: F(true) should normalize to true")

        // F(false) -> false
        let fFalse = LTLFormula<PropertyTestMockProposition>.eventually(falseLiteral)
        #expect(fFalse.normalized() == falseLiteral, "Eventually Norm: F(false) should normalize to false")

        // F(F(p)) -> F(p)
        let fp = LTLFormula<PropertyTestMockProposition>.eventually(pForm)
        let ffp = LTLFormula<PropertyTestMockProposition>.eventually(fp)
        #expect(ffp.normalized() == fp.normalized(), "Eventually Norm: F(F(p)) should normalize to F(p)")
    }

    @Test
    func testGloballyNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // G(true) -> true
        let gTrue = LTLFormula<PropertyTestMockProposition>.globally(trueLiteral)
        #expect(gTrue.normalized() == trueLiteral, "Globally Norm: G(true) should normalize to true")

        // G(false) -> false
        let gFalse = LTLFormula<PropertyTestMockProposition>.globally(falseLiteral)
        #expect(gFalse.normalized() == falseLiteral, "Globally Norm: G(false) should normalize to false")

        // G(G(p)) -> G(p)
        let gp = LTLFormula<PropertyTestMockProposition>.globally(pForm)
        let ggp = LTLFormula<PropertyTestMockProposition>.globally(gp)
        #expect(ggp.normalized() == gp.normalized(), "Globally Norm: G(G(p)) should normalize to G(p)")
    }

    @Test
    func testUntilNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // p U true -> true
        let pUtrue = LTLFormula<PropertyTestMockProposition>.until(pForm, trueLiteral)
        #expect(pUtrue.normalized() == trueLiteral, "Until Norm: p U true should normalize to true")

        // p U false -> false
        let pUfalse = LTLFormula<PropertyTestMockProposition>.until(pForm, falseLiteral)
        #expect(pUfalse.normalized() == falseLiteral, "Until Norm: p U false should normalize to false")

        // false U p -> p 
        let falseUp = LTLFormula<PropertyTestMockProposition>.until(falseLiteral, pForm)
        #expect(falseUp.normalized() == pForm.normalized(), "Until Norm: false U p should normalize to p")
        #expect(falseUp.normalized() == pForm, "Until Norm: false U p should normalize to p")
    }

    @Test
    func testWeakUntilNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)
        let globallyP = LTLFormula<PropertyTestMockProposition>.globally(pForm)

        // p W true -> true
        let pWtrue = LTLFormula<PropertyTestMockProposition>.weakUntil(pForm, trueLiteral)
        #expect(pWtrue.normalized() == trueLiteral, "WeakUntil Norm: p W true should normalize to true")

        // p W false -> G(p)
        let pWfalse = LTLFormula<PropertyTestMockProposition>.weakUntil(pForm, falseLiteral)
        #expect(pWfalse.normalized() == globallyP.normalized(), "WeakUntil Norm: p W false should normalize to G(p)")

        // false W p -> p 
        let falseWp = LTLFormula<PropertyTestMockProposition>.weakUntil(falseLiteral, pForm)
        #expect(falseWp.normalized() == pForm.normalized(), "WeakUntil Norm: false W p should normalize to p")
        #expect(falseWp.normalized() == pForm, "WeakUntil Norm: false W p should normalize to p")
    }

    // MARK: - Hashable and Equatable Coverage Tests

    @Test("Cover LTLFormula.hash(into:) for all cases")
    func testHashCoverage() {
        let pAtom: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qAtom: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        var hasher = Hasher()

        // Cases previously with 0 coverage based on coverage_report.txt
        let andFormula = LTLFormula<PropertyTestMockProposition>.and(pAtom, qAtom)
        let orFormula = LTLFormula<PropertyTestMockProposition>.or(pAtom, qAtom)
        let impliesFormula = LTLFormula<PropertyTestMockProposition>.implies(pAtom, qAtom)
        let eventuallyFormula = LTLFormula<PropertyTestMockProposition>.eventually(pAtom)
        let globallyFormula = LTLFormula<PropertyTestMockProposition>.globally(pAtom)
        let weakUntilFormula = LTLFormula<PropertyTestMockProposition>.weakUntil(pAtom, qAtom)

        // Invoking hash(into:) for each. The specific hash value isn't the focus here, just coverage.
        andFormula.hash(into: &hasher)
        orFormula.hash(into: &hasher)
        impliesFormula.hash(into: &hasher)
        eventuallyFormula.hash(into: &hasher)
        globallyFormula.hash(into: &hasher)
        weakUntilFormula.hash(into: &hasher)

        // To be absolutely sure, we can add them to a Set, which also invokes hash(into:)
        let formulaSet: Set<LTLFormula<PropertyTestMockProposition>> = [
            andFormula, orFormula, impliesFormula, eventuallyFormula, globallyFormula, weakUntilFormula,
            // Include other cases to ensure the test isn't trivial if Set optimizes for few items
            .booleanLiteral(true),
            pAtom,
            .not(pAtom),
            .next(pAtom),
            .until(pAtom, qAtom),
            .release(pAtom, qAtom)
        ]
        #expect(formulaSet.count >= 6) // Check that distinct formulas are indeed added
    }

    @Test("Cover LTLFormula.== for specific unhit cases")
    func testEquatableCoverage() {
        let pAtom: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qAtom: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        let rAtom: LTLFormula<PropertyTestMockProposition> = .atomic(PropertyTestMockProposition(name: "r")) // Different proposition

        // Case: .implies(let lLhs, let lRhs), .implies(let rLhs, let rRhs)
        let implies_p_q = LTLFormula<PropertyTestMockProposition>.implies(pAtom, qAtom)
        let implies_p_q_copy = LTLFormula<PropertyTestMockProposition>.implies(pAtom, qAtom)
        let implies_q_p = LTLFormula<PropertyTestMockProposition>.implies(qAtom, pAtom)
        let implies_p_r = LTLFormula<PropertyTestMockProposition>.implies(pAtom, rAtom)
        #expect(implies_p_q == implies_p_q_copy)
        #expect(implies_p_q != implies_q_p)
        #expect(implies_p_q != implies_p_r)
        #expect(implies_p_q != pAtom) // Different type

        // Case: .next(let lForm), .next(let rForm)
        let next_p = LTLFormula<PropertyTestMockProposition>.next(pAtom)
        let next_p_copy = LTLFormula<PropertyTestMockProposition>.next(pAtom)
        let next_q = LTLFormula<PropertyTestMockProposition>.next(qAtom)
        #expect(next_p == next_p_copy)
        #expect(next_p != next_q)
        #expect(next_p != pAtom) // Different type

        // Case: .weakUntil(let lLhs, let lRhs), .weakUntil(let rLhs, let rRhs)
        let wu_p_q = LTLFormula<PropertyTestMockProposition>.weakUntil(pAtom, qAtom)
        let wu_p_q_copy = LTLFormula<PropertyTestMockProposition>.weakUntil(pAtom, qAtom)
        let wu_q_p = LTLFormula<PropertyTestMockProposition>.weakUntil(qAtom, pAtom)
        let wu_p_r = LTLFormula<PropertyTestMockProposition>.weakUntil(pAtom, rAtom)
        #expect(wu_p_q == wu_p_q_copy)
        #expect(wu_p_q != wu_q_p)
        #expect(wu_p_q != wu_p_r)
        #expect(wu_p_q != pAtom) // Different type

        // Additional equality checks for completeness, though not explicitly for unhit lines previously
        // .and
        let and_p_q = LTLFormula<PropertyTestMockProposition>.and(pAtom, qAtom)
        let and_p_q_copy = LTLFormula<PropertyTestMockProposition>.and(pAtom, qAtom)
        #expect(and_p_q == and_p_q_copy)
        #expect(and_p_q != LTLFormula<PropertyTestMockProposition>.and(qAtom, pAtom))

        // .or
        let or_p_q = LTLFormula<PropertyTestMockProposition>.or(pAtom, qAtom)
        let or_p_q_copy = LTLFormula<PropertyTestMockProposition>.or(pAtom, qAtom)
        #expect(or_p_q == or_p_q_copy)
        #expect(or_p_q != LTLFormula<PropertyTestMockProposition>.or(qAtom, pAtom))

        // .eventually
        let eventually_p = LTLFormula<PropertyTestMockProposition>.eventually(pAtom)
        let eventually_p_copy = LTLFormula<PropertyTestMockProposition>.eventually(pAtom)
        #expect(eventually_p == eventually_p_copy)
        #expect(eventually_p != LTLFormula<PropertyTestMockProposition>.eventually(qAtom))

        // .globally
        let globally_p = LTLFormula<PropertyTestMockProposition>.globally(pAtom)
        let globally_p_copy = LTLFormula<PropertyTestMockProposition>.globally(pAtom)
        #expect(globally_p == globally_p_copy)
        #expect(globally_p != LTLFormula<PropertyTestMockProposition>.globally(qAtom))
    }
}
