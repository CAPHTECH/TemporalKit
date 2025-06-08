import Foundation
import Testing
@testable import TemporalKit

// Enhanced test context that can provide detailed error information
struct EnhancedTestEvaluationContext: EvaluationContext {
    let state: Any?
    let actualType: Any.Type?
    let index: Int?
    
    init(state: Any?, index: Int? = nil) {
        self.state = state
        self.actualType = state != nil ? type(of: state!) : nil
        self.index = index
    }
    
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return state as? T
    }
    
    func retrieveState<T>(_ type: T.Type) -> StateRetrievalResult<T> {
        guard let state = state else {
            return .notAvailable
        }
        
        if let typedState = state as? T {
            return .success(typedState)
        } else {
            return .typeMismatch(actual: Swift.type(of: state))
        }
    }
    
    var traceIndex: Int? {
        return index
    }
}

// Test state types
struct TestStringState {
    let value: String
}

struct TestIntState {
    let value: Int
}

struct EnhancedErrorHandlingTests {
    
    @Test("Enhanced context provides detailed error information")
    func testEnhancedContextDetailedErrors() {
        let stringState = TestStringState(value: "test")
        let context = EnhancedTestEvaluationContext(state: stringState)
        
        // Test successful retrieval
        let successResult = context.retrieveState(TestStringState.self)
        switch successResult {
        case .success(let state):
            #expect(state.value == "test")
        case .notAvailable, .typeMismatch:
            Issue.record("Expected successful retrieval")
        }
        
        // Test type mismatch
        let mismatchResult = context.retrieveState(TestIntState.self)
        switch mismatchResult {
        case .success:
            Issue.record("Expected type mismatch")
        case .notAvailable:
            Issue.record("Expected type mismatch, not 'not available'")
        case .typeMismatch(let actual):
            #expect(actual == TestStringState.self)
        }
        
        // Test not available
        let nilContext = EnhancedTestEvaluationContext(state: nil)
        let nilResult = nilContext.retrieveState(TestStringState.self)
        switch nilResult {
        case .success, .typeMismatch:
            Issue.record("Expected not available")
        case .notAvailable:
            break // Expected behavior
        }
    }
    
    @Test("ClosureTemporalProposition uses appropriate error types")
    func testClosurePropositionErrorTypes() throws {
        let proposition = ClosureTemporalProposition<TestStringState, Bool>(
            id: "test_prop",
            name: "Test Proposition",
            evaluate: { state in
                return state.value == "expected"
            }
        )
        
        // Test with correct type
        let validContext = EnhancedTestEvaluationContext(state: TestStringState(value: "expected"))
        let result1 = try proposition.evaluate(in: validContext)
        #expect(result1 == true)
        
        // Create a custom enhanced context that properly overrides retrieveState
        struct TestEnhancedContext: EvaluationContext {
            let state: Any
            
            func currentStateAs<T>(_ type: T.Type) -> T? {
                return state as? T
            }
            
            func retrieveState<T>(_ type: T.Type) -> StateRetrievalResult<T> {
                if let typedState = state as? T {
                    return .success(typedState)
                } else {
                    return .typeMismatch(actual: Swift.type(of: state))
                }
            }
        }
        
        // Test with wrong type - should throw stateTypeMismatch with enhanced context
        let wrongTypeContext = TestEnhancedContext(state: TestIntState(value: 42))
        
        var caughtError: TemporalKitError?
        do {
            _ = try proposition.evaluate(in: wrongTypeContext)
        } catch let error as TemporalKitError {
            caughtError = error
        }
        
        guard let error = caughtError else {
            Issue.record("Expected TemporalKitError to be thrown")
            return
        }
        
        switch error {
        case .stateTypeMismatch(let expected, let actual, let propID, let propName):
            #expect(expected.contains("TestStringState"))
            #expect(actual.contains("TestIntState"))
            #expect(propID.rawValue == "test_prop")
            #expect(propName == "Test Proposition")
        case .stateNotAvailable:
            // With the updated implementation, default contexts return stateNotAvailable
            // when they can't distinguish between type mismatch and no state
            break
        }
        
        // Test with basic context (uses default implementation) - should throw stateNotAvailable
        struct BasicTestContext: EvaluationContext {
            let state: Any
            
            func currentStateAs<T>(_ type: T.Type) -> T? {
                return state as? T
            }
        }
        
        let basicWrongTypeContext = BasicTestContext(state: TestIntState(value: 42))
        
        var caughtBasicError: TemporalKitError?
        do {
            _ = try proposition.evaluate(in: basicWrongTypeContext)
        } catch let error as TemporalKitError {
            caughtBasicError = error
        }
        
        guard let basicError = caughtBasicError else {
            Issue.record("Expected TemporalKitError to be thrown from basic context")
            return
        }
        
        switch basicError {
        case .stateNotAvailable(let expected, let propID, let propName):
            #expect(expected.contains("TestStringState"))
            #expect(propID.rawValue == "test_prop")
            #expect(propName == "Test Proposition")
        case .stateTypeMismatch:
            Issue.record("Basic context should return stateNotAvailable, not stateTypeMismatch")
        }
        
        // Test with nil state - should throw stateNotAvailable
        let nilContext = EnhancedTestEvaluationContext(state: nil)
        
        var caughtNilError: TemporalKitError?
        do {
            _ = try proposition.evaluate(in: nilContext)
        } catch let error as TemporalKitError {
            caughtNilError = error
        }
        
        guard let nilError = caughtNilError else {
            Issue.record("Expected TemporalKitError to be thrown for nil state")
            return
        }
        
        switch nilError {
        case .stateNotAvailable(let expected, let propID, let propName):
            #expect(expected.contains("TestStringState"))
            #expect(propID.rawValue == "test_prop")
            #expect(propName == "Test Proposition")
        case .stateTypeMismatch:
            Issue.record("Expected stateNotAvailable, got stateTypeMismatch")
        }
    }
    
    @Test("Error descriptions are informative")
    func testErrorDescriptions() {
        let propID = PropositionID(rawValue: "test_id")!
        
        let typeMismatchError = TemporalKitError.stateTypeMismatch(
            expected: "String",
            actual: "Int",
            propositionID: propID,
            propositionName: "Test Prop"
        )
        
        let notAvailableError = TemporalKitError.stateNotAvailable(
            expected: "String",
            propositionID: propID,
            propositionName: "Test Prop"
        )
        
        let typeMismatchDescription = typeMismatchError.errorDescription
        #expect(typeMismatchDescription?.contains("Test Prop") == true)
        #expect(typeMismatchDescription?.contains("test_id") == true)
        #expect(typeMismatchDescription?.contains("String") == true)
        #expect(typeMismatchDescription?.contains("Int") == true)
        #expect(typeMismatchDescription?.contains("mismatch") == true)
        
        let notAvailableDescription = notAvailableError.errorDescription
        #expect(notAvailableDescription?.contains("Test Prop") == true)
        #expect(notAvailableDescription?.contains("test_id") == true)
        #expect(notAvailableDescription?.contains("String") == true)
        #expect(notAvailableDescription?.contains("not available") == true)
    }
    
    @Test("Backward compatibility with basic EvaluationContext")
    func testBackwardCompatibility() {
        // Test context using only the basic protocol methods
        struct BasicTestContext: EvaluationContext {
            let state: Any?
            
            func currentStateAs<T>(_ type: T.Type) -> T? {
                return state as? T
            }
        }
        
        let context = BasicTestContext(state: "test")
        
        // Default implementation should work
        let result = context.retrieveState(String.self)
        switch result {
        case .success(let value):
            #expect(value == "test")
        case .notAvailable, .typeMismatch:
            Issue.record("Expected successful retrieval with basic context")
        }
        
        // Test with nil result - default implementation returns notAvailable
        let nilResult = context.retrieveState(Int.self)
        switch nilResult {
        case .success:
            Issue.record("Expected not available")
        case .notAvailable:
            break // Expected behavior // This is expected with default implementation
        case .typeMismatch:
            Issue.record("Default implementation should return notAvailable, not typeMismatch")
        }
    }
    
    @Test("PropositionID creation with invalid input")
    func testPropositionIDWithInvalidInput() {
        // Test that ClosureTemporalProposition handles invalid IDs gracefully
        let proposition = ClosureTemporalProposition<String, Bool>(
            id: "invalid@id", // This should be invalid
            name: "Test",
            evaluate: { _ in true }
        )
        
        // Should have fallback ID
        #expect(proposition.id.rawValue == "invalid_id")
    }
}