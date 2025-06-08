import Testing
import Foundation
@testable import TemporalKit

/// Tests for complex LTL formula DSL expressions
struct LTLFormulaComplexDSLTests {
    
    final class DSLMockProposition: TemporalProposition {
        typealias Value = Bool
        let id: PropositionID
        let name: String
        
        init(id: String = UUID().uuidString, name: String) {
            self.id = PropositionID(rawValue: id)!
            self.name = name
        }
        
        func evaluate(in context: EvaluationContext) throws -> Bool {
            return false // Not used in DSL tests
        }
        
        var ltl: LTLFormula<DSLMockProposition> {
            return .atomic(self)
        }
    }
    
    @Test
    func testComplexDSLExpressions() {
        // Define some propositions
        let p = DSLMockProposition(name: "p")
        let q = DSLMockProposition(name: "q")
        let r = DSLMockProposition(name: "r")
        let s = DSLMockProposition(name: "s")
        
        // Test complex expression: (p && q) ==> (r || X(s))
        let dslExpression1 = (p.ltl && q.ltl) ==> (r.ltl || LTLFormula.next(s.ltl))
        
        // Manually build the expected formula structure
        let expected1: LTLFormula<DSLMockProposition> = .implies(
            .and(.atomic(p), .atomic(q)),
            .or(.atomic(r), .next(.atomic(s)))
        )
        
        #expect(dslExpression1 == expected1, "DSL expression (p && q) ==> (r || X s) should produce the correct LTLFormula")
        
        // Test complex expression: G(p ==> F(q && r))
        let dslExpression2 = LTLFormula.globally(p.ltl ==> LTLFormula.eventually(q.ltl && r.ltl))
        
        // Manually build the expected formula structure
        let expected2: LTLFormula<DSLMockProposition> = .globally(
            .implies(
                .atomic(p),
                .eventually(.and(.atomic(q), .atomic(r)))
            )
        )
        
        #expect(dslExpression2 == expected2, "DSL expression G(p ==> F(q && r)) should produce the correct LTLFormula")
        
        // Test expression with nested parentheses: !((p && q) || (!r && s))
        let dslExpression3 = !((p.ltl && q.ltl) || (!r.ltl && s.ltl))
        
        // Manually build the expected formula structure
        let expected3: LTLFormula<DSLMockProposition> = .not(
            .or(
                .and(.atomic(p), .atomic(q)),
                .and(.not(.atomic(r)), .atomic(s))
            )
        )
        
        #expect(dslExpression3 == expected3, "DSL expression !((p && q) || (!r && s)) should produce the correct LTLFormula")
        
        // Test expression with different temporal operators: (G(p)) U (F(q))
        let dslExpression4 = LTLFormula.until(LTLFormula.globally(p.ltl), LTLFormula.eventually(q.ltl))
        
        // Manually build the expected formula structure
        let expected4: LTLFormula<DSLMockProposition> = .until(
            .globally(.atomic(p)),
            .eventually(.atomic(q))
        )
        
        #expect(dslExpression4 == expected4, "DSL expression (G p) U (F q) should produce the correct LTLFormula")
        
        // Test expression with mixed operators and precedence: p && q || r ==> s
        let dslExpression5 = (p.ltl && q.ltl || r.ltl) ==> s.ltl
        
        // Manually build the expected formula structure (according to operator precedence)
        // &&, || have higher precedence than ==>, so this should be: ((p && q) || r) ==> s
        let expected5: LTLFormula<DSLMockProposition> = .implies(
            .or(.and(.atomic(p), .atomic(q)), .atomic(r)),
            .atomic(s)
        )
        
        #expect(dslExpression5 == expected5, "DSL expression p && q || r ==> s should follow operator precedence rules")
        
        // Test expression with weak until: p W (q U r)
        let dslExpression6 = LTLFormula.weakUntil(p.ltl, LTLFormula.until(q.ltl, r.ltl))
        
        // Manually build the expected formula structure
        let expected6: LTLFormula<DSLMockProposition> = .weakUntil(
            .atomic(p),
            .until(.atomic(q), .atomic(r))
        )
        
        #expect(dslExpression6 == expected6, "DSL expression p W (q U r) should produce the correct LTLFormula")
    }
} 
