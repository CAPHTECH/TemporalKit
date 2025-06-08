import Foundation
import Testing
@testable import TemporalKit

// Test implementation of EvaluationContext with enhanced error handling
struct TestEvaluationContextEnhanced: EvaluationContext {
    let state: Any
    let actualType: Any.Type
    let index: Int?
    
    init(state: Any, index: Int? = nil) {
        self.state = state
        self.actualType = type(of: state)
        self.index = index
    }
    
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return state as? T
    }
    
    func retrieveState<T>(_ type: T.Type) -> StateRetrievalResult<T> {
        if let typedState = state as? T {
            return .success(typedState)
        } else {
            return .typeMismatch(actual: actualType)
        }
    }
    
    var traceIndex: Int? {
        return index
    }
}

// Test state types
struct StringState {
    let value: String
}

struct IntState {
    let value: Int
}

struct EvaluationContextEnhancedTests {
    
    @Test
    func testStateRetrievalSuccess() {
        let stringState = StringState(value: "test")
        let context = TestEvaluationContextEnhanced(state: stringState)
        
        let result = context.retrieveState(StringState.self)
        switch result {
        case .success(let state):
            #expect(state.value == "test")
        case .notAvailable, .typeMismatch:
            Issue.record("Expected successful state retrieval")
        }
    }
    
    @Test
    func testStateRetrievalTypeMismatch() {
        let stringState = StringState(value: "test")
        let context = TestEvaluationContextEnhanced(state: stringState)
        
        let result = context.retrieveState(IntState.self)
        switch result {
        case .success:
            Issue.record("Expected type mismatch")
        case .notAvailable:
            Issue.record("Expected type mismatch, not 'not available'")
        case .typeMismatch(let actual):
            #expect(actual == StringState.self)
        }
    }
    
    @Test
    func testClosurePropositionWithEnhancedContext() throws {
        let proposition = ClosureTemporalProposition<StringState, Bool>(
            id: "test",
            name: "Test Proposition",
            evaluate: { state in
                return state.value == "expected"
            }
        )
        
        // Test with correct type
        let validContext = TestEvaluationContextEnhanced(state: StringState(value: "expected"))
        let result1 = try proposition.evaluate(in: validContext)
        #expect(result1 == true)
        
        // Test with wrong type
        let invalidContext = TestEvaluationContextEnhanced(state: IntState(value: 42))
        
        #expect(throws: TemporalKitError.self) {
            _ = try proposition.evaluate(in: invalidContext)
        }
    }
    
    @Test
    func testDefaultImplementation() {
        // Test context using default implementation
        struct DefaultTestContext: EvaluationContext {
            let state: Any
            
            func currentStateAs<T>(_ type: T.Type) -> T? {
                return state as? T
            }
        }
        
        let context = DefaultTestContext(state: "test")
        let result = context.retrieveState(String.self)
        
        switch result {
        case .success(let value):
            #expect(value == "test")
        case .notAvailable, .typeMismatch:
            Issue.record("Expected successful retrieval with default implementation")
        }
        
        // Test with nil result
        let nilResult = context.retrieveState(Int.self)
        switch nilResult {
        case .success:
            Issue.record("Expected not available")
        case .notAvailable:
            break // Expected behavior
        case .typeMismatch:
            Issue.record("Default implementation should return notAvailable, not typeMismatch")
        }
    }
}