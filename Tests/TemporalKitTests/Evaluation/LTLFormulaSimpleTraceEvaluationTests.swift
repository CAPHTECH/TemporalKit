import Testing
import Foundation
@testable import TemporalKit

/// Tests specifically focused on covering the final return statement in LTLFormula+TraceEvaluation
struct LTLFormulaSimpleTraceEvaluationTests {
    
    struct MockContext: EvaluationContext {
        let values: [String: Any]
        
        // Added accessor method that's compatible with our proposition
        func value(for key: String) -> Any? {
            return values[key]
        }
        
        func currentStateAs<T>(_ type: T.Type) -> T? {
            return nil // Not needed for these tests
        }
        
        var traceIndex: Int? {
            return nil // Not needed for these tests
        }
    }
    
    final class MockProposition: TemporalProposition {
        typealias Value = Bool
        let id: PropositionID
        let name: String
        let key: String
        
        init(id: String = UUID().uuidString, key: String, name: String = "") {
            self.id = PropositionID(rawValue: id)!
            self.key = key
            self.name = name
        }
        
        func evaluate(in context: EvaluationContext) throws -> Bool {
            // Cast to our specific context type that has the value accessor
            guard let mockContext = context as? MockContext,
                  let value = mockContext.value(for: key) as? Bool else {
                throw LTLTraceEvaluationError.propositionEvaluationFailure("Cannot evaluate proposition with ID: \(id.rawValue)")
            }
            return value
        }
    }
    
    /// Test evaluating a simple atomic proposition over a trace where it always holds
    @Test
    func testSimpleAtomicPropositionEvaluation() throws {
        let p = MockProposition(key: "p", name: "p")
        let formula: LTLFormula<MockProposition> = .atomic(p)
        
        // Create a trace where p is always true
        let context1 = MockContext(values: ["p": true])
        let context2 = MockContext(values: ["p": true])
        let trace = [context1, context2]
        
        // This should hit the final `return overallHolds` statement
        let result = try formula.evaluate(over: trace)
        #expect(result == true, "The atomic proposition should hold over the entire trace")
    }
    
    /// Test evaluating a logical AND formula over a trace where both subformulas always hold
    @Test
    func testSimpleAndFormulaEvaluation() throws {
        let p = MockProposition(key: "p", name: "p")
        let q = MockProposition(key: "q", name: "q")
        let formula: LTLFormula<MockProposition> = .and(.atomic(p), .atomic(q))
        
        // Create a trace where p and q are always true
        let context1 = MockContext(values: ["p": true, "q": true])
        let context2 = MockContext(values: ["p": true, "q": true])
        let trace = [context1, context2]
        
        // This should hit the final `return overallHolds` statement
        let result = try formula.evaluate(over: trace)
        #expect(result == true, "The AND formula should hold over the entire trace")
    }
    
    /// Test evaluating a logical OR formula over a trace where at least one subformula always holds
    @Test
    func testSimpleOrFormulaEvaluation() throws {
        let p = MockProposition(key: "p", name: "p")
        let q = MockProposition(key: "q", name: "q")
        let formula: LTLFormula<MockProposition> = .or(.atomic(p), .atomic(q))
        
        // Create a trace where p is always true but q varies
        let context1 = MockContext(values: ["p": true, "q": false])
        let context2 = MockContext(values: ["p": true, "q": true])
        let trace = [context1, context2]
        
        // This should hit the final `return overallHolds` statement
        let result = try formula.evaluate(over: trace)
        #expect(result == true, "The OR formula should hold over the entire trace")
    }
    
    /// Test evaluating a formula that does not reduce to a boolean literal before trace end
    @Test
    func testNonReducingFormulaEvaluation() throws {
        let p = MockProposition(key: "p", name: "p")
        let q = MockProposition(key: "q", name: "q")
        
        // A formula that won't reduce to a literal: (p && q) || (!p && q)
        let formula: LTLFormula<MockProposition> = .or(
            .and(.atomic(p), .atomic(q)),
            .and(.not(.atomic(p)), .atomic(q))
        )
        
        // Create a trace where the formula evaluates to true but doesn't reduce to a literal
        let context1 = MockContext(values: ["p": true, "q": true])  // (true && true) || (!true && true) = true || false = true
        let context2 = MockContext(values: ["p": false, "q": true]) // (false && true) || (!false && true) = false || true = true
        let trace = [context1, context2]
        
        // This should hit the final `return overallHolds` statement
        let result = try formula.evaluate(over: trace)
        #expect(result == true, "The complex formula should hold over the entire trace")
    }
} 
