import XCTest
@testable import TemporalKit

final class LTLFormulaDSLOperatorTests: XCTestCase {
    typealias Formula = LTLFormula<DSLBoolProposition>
    
    // MARK: - Test Propositions
    
    let p = Formula.atomic(DSLBoolProposition("p"))
    let q = Formula.atomic(DSLBoolProposition("q"))
    let r = Formula.atomic(DSLBoolProposition("r"))
    
    // MARK: - Operator Tests
    
    func testLogicalOperators() {
        // NOT operator
        let notP = !p
        XCTAssertEqual(notP, .not(p))
        
        // AND operator
        let pAndQ = p && q
        XCTAssertEqual(pAndQ, .and(p, q))
        
        // OR operator
        let pOrQ = p || q
        XCTAssertEqual(pOrQ, .or(p, q))
        
        // IMPLIES operator
        let pImpliesQ = p ==> q
        XCTAssertEqual(pImpliesQ, .implies(p, q))
    }
    
    func testTemporalOperators() {
        // NEXT operators
        let nextP = Formula.X(p)
        XCTAssertEqual(nextP, .next(p))
        
        // EVENTUALLY operators
        let eventuallyP = Formula.F(p)
        XCTAssertEqual(eventuallyP, .eventually(p))
        
        // GLOBALLY operators
        let globallyP = Formula.G(p)
        XCTAssertEqual(globallyP, .globally(p))
    }
    
    func testBinaryTemporalOperators() {
        // UNTIL operators
        let pUntilQ1 = p ~>> q
        let pUntilQ2 = p.until(q)
        let pUntilQ3 = LTL.U(p, q)
        
        XCTAssertEqual(pUntilQ1, .until(p, q))
        XCTAssertEqual(pUntilQ2, .until(p, q))
        XCTAssertEqual(pUntilQ3, .until(p, q))
        
        // WEAK UNTIL operators
        let pWeakUntilQ1 = p ~~> q
        let pWeakUntilQ2 = p.weakUntil(q)
        let pWeakUntilQ3 = LTL.W(p, q)
        
        XCTAssertEqual(pWeakUntilQ1, .weakUntil(p, q))
        XCTAssertEqual(pWeakUntilQ2, .weakUntil(p, q))
        XCTAssertEqual(pWeakUntilQ3, .weakUntil(p, q))
        
        // RELEASE operators
        let pReleaseQ1 = p ~< q
        let pReleaseQ2 = p.release(q)
        let pReleaseQ3 = LTL.R(p, q)
        
        XCTAssertEqual(pReleaseQ1, .release(p, q))
        XCTAssertEqual(pReleaseQ2, .release(p, q))
        XCTAssertEqual(pReleaseQ3, .release(p, q))
    }
    
    // MARK: - Operator Precedence Tests
    
    func testOperatorPrecedence() {
        // AND has higher precedence than OR
        let formula1 = p || q && r
        let expected1 = Formula.or(p, .and(q, r))
        XCTAssertEqual(formula1, expected1)
        
        // Temporal operators have higher precedence than logical operators
        let formula2 = p && q ~>> r
        let expected2 = Formula.and(p, .until(q, r))
        XCTAssertEqual(formula2, expected2)
        
        // Implication has lower precedence than OR
        let formula3 = p || q ==> r
        let expected3 = Formula.implies(.or(p, q), r)
        XCTAssertEqual(formula3, expected3)
        
        // Right associativity of implication
        let formula4 = p ==> q ==> r
        let expected4 = Formula.implies(p, .implies(q, r))
        XCTAssertEqual(formula4, expected4)
    }
    
    // MARK: - Complex Formula Tests
    
    func testComplexFormulas() {
        // Response pattern: G(p ==> F(q))
        let response = Formula.G(p ==> Formula.F(q))
        let expectedResponse = Formula.globally(.implies(p, .eventually(q)))
        XCTAssertEqual(response, expectedResponse)
        
        // Precedence pattern: !q U (p || q)
        let precedence = (!q) ~>> (p || q)
        let expectedPrecedence = Formula.until(.not(q), .or(p, q))
        XCTAssertEqual(precedence, expectedPrecedence)
        
        // Fairness pattern: G(F(p)) ==> G(F(q))
        let fairness = Formula.G(Formula.F(p)) ==> Formula.G(Formula.F(q))
        let expectedFairness = Formula.implies(
            .globally(.eventually(p)),
            .globally(.eventually(q))
        )
        XCTAssertEqual(fairness, expectedFairness)
    }
    
    // MARK: - Boolean Literal Tests
    
    func testBooleanLiterals() {
        typealias BoolFormula = LTLFormula<BooleanProposition>
        
        let alwaysTrue = BoolFormula.true
        XCTAssertEqual(alwaysTrue, .booleanLiteral(true))
        
        let alwaysFalse = BoolFormula.false
        XCTAssertEqual(alwaysFalse, .booleanLiteral(false))
    }
    
    // MARK: - Method Syntax Tests
    
    func testMethodSyntax() {
        // Test all method-based operators
        let untilFormula = p.until(q)
        XCTAssertEqual(untilFormula, .until(p, q))
        
        let weakUntilFormula = p.weakUntil(q)
        XCTAssertEqual(weakUntilFormula, .weakUntil(p, q))
        
        let releaseFormula = p.release(q)
        XCTAssertEqual(releaseFormula, .release(p, q))
        
        let impliesFormula = p.implies(q)
        XCTAssertEqual(impliesFormula, .implies(p, q))
    }
    
    // MARK: - Namespaced Operator Tests
    
    func testNamespacedOperators() {
        // Test LTL namespace operators
        let untilFormula = LTL.U(p, q)
        XCTAssertEqual(untilFormula, .until(p, q))
        
        let weakUntilFormula = LTL.W(p, q)
        XCTAssertEqual(weakUntilFormula, .weakUntil(p, q))
        
        let releaseFormula = LTL.R(p, q)
        XCTAssertEqual(releaseFormula, .release(p, q))
        
        // Complex formula with namespaced operators
        let complex = Formula.G(p ==> Formula.F(LTL.U(q, r)))
        let expected = Formula.globally(Formula.implies(p, Formula.eventually(Formula.until(q, r))))
        XCTAssertEqual(complex, expected)
    }
}

// MARK: - Test Proposition Types

class DSLBoolProposition: TemporalProposition {
    let id: PropositionID
    let name: String
    typealias Value = Bool
    
    init(_ name: String) {
        self.id = PropositionID(rawValue: name)!
        self.name = name
    }
    
    func evaluate(in context: EvaluationContext) throws -> Bool {
        // For DSL tests, we don't need actual evaluation
        return false
    }
}

class BooleanProposition: TemporalProposition {
    let id: PropositionID
    let name: String
    typealias Value = Bool
    
    init(_ name: String) {
        self.id = PropositionID(rawValue: name)!
        self.name = name
    }
    
    func evaluate(in context: EvaluationContext) throws -> Bool {
        // For DSL tests, we don't need actual evaluation
        return false
    }
}