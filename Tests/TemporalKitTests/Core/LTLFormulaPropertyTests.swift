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
        self.id = PropositionID(rawValue: id)
        self.name = name
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        return false // Not used for property tests
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
        let trueAndP = LTLFormula.and(trueLiteral, pForm)
        #expect(trueAndP.normalized() == pForm.normalized(), "Constant Propagation: true && p should normalize to p")
        #expect(trueAndP.normalized() == pForm, "Constant Propagation: true && p should normalize to p")

        // p && true 
        let pAndTrue = LTLFormula.and(pForm, trueLiteral)
        #expect(pAndTrue.normalized() == pForm.normalized(), "Constant Propagation: p && true should normalize to p")
        #expect(pAndTrue.normalized() == pForm, "Constant Propagation: p && true should normalize to p")

        // false && p
        let falseAndP = LTLFormula.and(falseLiteral, pForm)
        #expect(falseAndP.normalized() == falseLiteral.normalized(), "Constant Propagation: false && p should normalize to false")
        #expect(falseAndP.normalized() == falseLiteral, "Constant Propagation: false && p should normalize to false")

        // p && false
        let pAndFalse = LTLFormula.and(pForm, falseLiteral)
        #expect(pAndFalse.normalized() == falseLiteral.normalized(), "Constant Propagation: p && false should normalize to false")
        #expect(pAndFalse.normalized() == falseLiteral, "Constant Propagation: p && false should normalize to false")
    }

    @Test
    func testConstantPropagationOr() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // true || p
        let trueOrP = LTLFormula.or(trueLiteral, pForm)
        #expect(trueOrP.normalized() == trueLiteral.normalized(), "Constant Propagation: true || p should normalize to true")
        #expect(trueOrP.normalized() == trueLiteral, "Constant Propagation: true || p should normalize to true")

        // p || true 
        let pOrTrue = LTLFormula.or(pForm, trueLiteral)
        #expect(pOrTrue.normalized() == trueLiteral.normalized(), "Constant Propagation: p || true should normalize to true")
        #expect(pOrTrue.normalized() == trueLiteral, "Constant Propagation: p || true should normalize to true")

        // false || p
        let falseOrP = LTLFormula.or(falseLiteral, pForm)
        #expect(falseOrP.normalized() == pForm.normalized(), "Constant Propagation: false || p should normalize to p")
        #expect(falseOrP.normalized() == pForm, "Constant Propagation: false || p should normalize to p")

        // p || false
        let pOrFalse = LTLFormula.or(pForm, falseLiteral)
        #expect(pOrFalse.normalized() == pForm.normalized(), "Constant Propagation: p || false should normalize to p")
        #expect(pOrFalse.normalized() == pForm, "Constant Propagation: p || false should normalize to p")
    }

    @Test
    func testBooleanSimplificationOr() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let notPForm: LTLFormula<PropertyTestMockProposition> = .not(pForm)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        
        // p || !p
        let pOrNotP = LTLFormula.or(pForm, notPForm)
        #expect(pOrNotP.normalized() == trueLiteral, "Boolean Simplification: p || !p should normalize to true")
        
        // !p || p
        let notPOrP = LTLFormula.or(notPForm, pForm)
        #expect(notPOrP.normalized() == trueLiteral, "Boolean Simplification: !p || p should normalize to true")
    }

    @Test
    func testBooleanSimplificationAnd() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let notPForm: LTLFormula<PropertyTestMockProposition> = .not(pForm)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)
        
        // p && !p
        let pAndNotP = LTLFormula.and(pForm, notPForm)
        #expect(pAndNotP.normalized() == falseLiteral, "Boolean Simplification: p && !p should normalize to false")
        
        // !p && p
        let notPAndP = LTLFormula.and(notPForm, pForm)
        #expect(notPAndP.normalized() == falseLiteral, "Boolean Simplification: !p && p should normalize to false")
    }

    @Test
    func testReleaseNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // false R p -> G(p)
        let falseRp = LTLFormula.release(falseLiteral, pForm)
        let globallyP = LTLFormula.globally(pForm)
        // Note: G(p) might normalize further, so compare normalized forms
        #expect(falseRp.normalized() == globallyP.normalized(), "Release Norm: false R p should normalize to G(p)")

        // true R p -> p
        let trueRp = LTLFormula.release(trueLiteral, pForm)
        #expect(trueRp.normalized() == pForm.normalized(), "Release Norm: true R p should normalize to p")
        #expect(trueRp.normalized() == pForm, "Release Norm: true R p should normalize to p")

        // p R false -> false
        let pRfalse = LTLFormula.release(pForm, falseLiteral)
        #expect(pRfalse.normalized() == falseLiteral.normalized(), "Release Norm: p R false should normalize to false")
        #expect(pRfalse.normalized() == falseLiteral, "Release Norm: p R false should normalize to false")

        // p R true -> true
        let pRtrue = LTLFormula.release(pForm, trueLiteral)
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
        let xTrue = LTLFormula.next(trueLiteral)
        #expect(xTrue.normalized() == trueLiteral, "Next Norm: X(true) should normalize to true")
        
        // X(false) -> false
        let xFalse = LTLFormula.next(falseLiteral)
        #expect(xFalse.normalized() == falseLiteral, "Next Norm: X(false) should normalize to false")
    }

    @Test
    func testEventuallyNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // F(true) -> true
        let fTrue = LTLFormula.eventually(trueLiteral)
        #expect(fTrue.normalized() == trueLiteral, "Eventually Norm: F(true) should normalize to true")

        // F(false) -> false
        let fFalse = LTLFormula.eventually(falseLiteral)
        #expect(fFalse.normalized() == falseLiteral, "Eventually Norm: F(false) should normalize to false")

        // F(F(p)) -> F(p)
        let fp = LTLFormula.eventually(pForm)
        let ffp = LTLFormula.eventually(fp)
        #expect(ffp.normalized() == fp.normalized(), "Eventually Norm: F(F(p)) should normalize to F(p)")
    }

    @Test
    func testGloballyNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // G(true) -> true
        let gTrue = LTLFormula.globally(trueLiteral)
        #expect(gTrue.normalized() == trueLiteral, "Globally Norm: G(true) should normalize to true")

        // G(false) -> false
        let gFalse = LTLFormula.globally(falseLiteral)
        #expect(gFalse.normalized() == falseLiteral, "Globally Norm: G(false) should normalize to false")

        // G(G(p)) -> G(p)
        let gp = LTLFormula.globally(pForm)
        let ggp = LTLFormula.globally(gp)
        #expect(ggp.normalized() == gp.normalized(), "Globally Norm: G(G(p)) should normalize to G(p)")
    }

    @Test
    func testUntilNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)

        // p U true -> true
        let pUtrue = LTLFormula.until(pForm, trueLiteral)
        #expect(pUtrue.normalized() == trueLiteral, "Until Norm: p U true should normalize to true")

        // p U false -> false
        let pUfalse = LTLFormula.until(pForm, falseLiteral)
        #expect(pUfalse.normalized() == falseLiteral, "Until Norm: p U false should normalize to false")

        // false U p -> p 
        let falseUp = LTLFormula.until(falseLiteral, pForm)
        #expect(falseUp.normalized() == pForm.normalized(), "Until Norm: false U p should normalize to p")
        #expect(falseUp.normalized() == pForm, "Until Norm: false U p should normalize to p")
    }
    
    @Test
    func testWeakUntilNormalization() {
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        let falseLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(false)
        let globallyP = LTLFormula.globally(pForm)

        // p W true -> true
        let pWtrue = LTLFormula.weakUntil(pForm, trueLiteral)
        #expect(pWtrue.normalized() == trueLiteral, "WeakUntil Norm: p W true should normalize to true")

        // p W false -> G(p)
        let pWfalse = LTLFormula.weakUntil(pForm, falseLiteral)
        #expect(pWfalse.normalized() == globallyP.normalized(), "WeakUntil Norm: p W false should normalize to G(p)")

        // false W p -> p 
        let falseWp = LTLFormula.weakUntil(falseLiteral, pForm)
        #expect(falseWp.normalized() == pForm.normalized(), "WeakUntil Norm: false W p should normalize to p")
        #expect(falseWp.normalized() == pForm, "WeakUntil Norm: false W p should normalize to p")
    }
} 
