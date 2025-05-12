import Testing
import Foundation
@testable import TemporalKit

/// Tests for LTLFormula mutating normalize() method and specific normalization rules
struct LTLFormulaNormalizationTests {
    
    let p = PropertyTestMockProposition(name: "p")
    let q = PropertyTestMockProposition(name: "q")
    
    @Test
    func testMutatingNormalize() {
        // Test double negation elimination
        var formula: LTLFormula<PropertyTestMockProposition> = .not(.not(.atomic(p)))
        formula.normalize()
        #expect(formula == .atomic(p), "Double negation should normalize in-place to the atomic proposition")
        
        // Test TRUE AND p -> p
        formula = .and(.booleanLiteral(true), .atomic(p))
        formula.normalize()
        #expect(formula == .atomic(p), "TRUE AND p should normalize in-place to p")
        
        // Test FALSE OR p -> p
        formula = .or(.booleanLiteral(false), .atomic(p))
        formula.normalize()
        #expect(formula == .atomic(p), "FALSE OR p should normalize in-place to p")
        
        // Test multiple normalizations (complex formula)
        formula = .not(.and(.not(.atomic(p)), .not(.atomic(q))))
        formula.normalize()
        #expect(formula == .or(.atomic(p), .atomic(q)), "!((!p) && (!q)) should normalize in-place to p || q")
    }
    
    @Test
    func testNegateBooleansNormalization() {
        // !true -> false
        #expect(LTLFormula<PropertyTestMockProposition>.not(.booleanLiteral(true)).normalized() == .booleanLiteral(false), 
            "!true should normalize to false")
            
        // !false -> true
        #expect(LTLFormula<PropertyTestMockProposition>.not(.booleanLiteral(false)).normalized() == .booleanLiteral(true), 
            "!false should normalize to true")
    }
    
    @Test
    func testNegateImpliesNormalization() {
        // !(A -> B) -> A && !B
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        
        let notImplies = LTLFormula<PropertyTestMockProposition>.not(.implies(pForm, qForm))
        let expected = LTLFormula<PropertyTestMockProposition>.and(pForm, .not(qForm)).normalized()
        
        #expect(notImplies.normalized() == expected, "!(A -> B) should normalize to A && !B")
    }
    
    @Test
    func testSelfAndNormalization() {
        // A && A -> A
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        
        let selfAnd = LTLFormula<PropertyTestMockProposition>.and(pForm, pForm)
        
        #expect(selfAnd.normalized() == pForm, "A && A should normalize to A")
    }
    
    @Test
    func testSelfOrNormalization() {
        // A || A -> A
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        
        let selfOr = LTLFormula<PropertyTestMockProposition>.or(pForm, pForm)
        
        #expect(selfOr.normalized() == pForm, "A || A should normalize to A")
    }
    
    @Test
    func testNextWithComplexFormulaNormalization() {
        // X(p && !!q) -> X(p && q)
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        
        let complexNext = LTLFormula<PropertyTestMockProposition>.next(.and(pForm, .not(.not(qForm))))
        let expected = LTLFormula<PropertyTestMockProposition>.next(.and(pForm, qForm))
        
        #expect(complexNext.normalized() == expected, "X(p && !!q) should normalize to X(p && q)")
    }
    
    @Test
    func testUntilWithComplexFormulaNormalization() {
        // (p && !!p) U (q || false) -> p U q
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        
        let complexUntil = LTLFormula<PropertyTestMockProposition>.until(
            .and(pForm, .not(.not(pForm))), 
            .or(qForm, .booleanLiteral(false))
        )
        let expected = LTLFormula<PropertyTestMockProposition>.until(pForm, qForm)
        
        #expect(complexUntil.normalized() == expected, "(p && !!p) U (q || false) should normalize to p U q")
    }
    
    @Test
    func testWeakUntilTrueNormalization() {
        // true W B -> true W normalized(B)
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let trueLiteral: LTLFormula<PropertyTestMockProposition> = .booleanLiteral(true)
        
        let trueWeakUntil = LTLFormula<PropertyTestMockProposition>.weakUntil(trueLiteral, pForm)
        let expected = LTLFormula<PropertyTestMockProposition>.weakUntil(trueLiteral, pForm.normalized())
        
        #expect(trueWeakUntil.normalized() == expected, "true W B should normalize to true W normalized(B)")
    }
    
    @Test
    func testWeakUntilWithComplexFormulaNormalization() {
        // (p || !p) W (q && !(!q)) -> true W q
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        
        let complexWeakUntil = LTLFormula<PropertyTestMockProposition>.weakUntil(
            .or(pForm, .not(pForm)), 
            .and(qForm, .not(.not(qForm)))
        )
        let expected = LTLFormula<PropertyTestMockProposition>.weakUntil(.booleanLiteral(true), qForm)
        
        #expect(complexWeakUntil.normalized() == expected, "(p || !p) W (q && !(!q)) should normalize to true W q")
    }
    
    @Test
    func testReleaseWithComplexFormulaNormalization() {
        // (p || !(!p)) R (q && !r) -> p R (q && !r)
        let pForm: LTLFormula<PropertyTestMockProposition> = .atomic(p)
        let qForm: LTLFormula<PropertyTestMockProposition> = .atomic(q)
        let rForm: LTLFormula<PropertyTestMockProposition> = .atomic(PropertyTestMockProposition(name: "r"))
        
        let complexRelease = LTLFormula<PropertyTestMockProposition>.release(
            .or(pForm, .not(.not(pForm))), 
            .and(qForm, .not(rForm))
        )
        let expected = LTLFormula<PropertyTestMockProposition>.release(
            pForm, 
            .and(qForm, .not(rForm))
        )
        
        #expect(complexRelease.normalized() == expected.normalized(), "(p || !(!p)) R (q && !r) should normalize to p R (q && !r)")
    }
} 
