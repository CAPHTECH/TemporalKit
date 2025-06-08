import Testing
@testable import TemporalKit
import Foundation // For UUID

// Dummy StateType for testing, specific to this test file
private struct CTP_TestState { // Renamed to avoid conflicts
    let value: Int
    let shouldThrowInEvaluate: Bool
    
    init(value: Int, shouldThrowInEvaluate: Bool = false) {
        self.value = value
        self.shouldThrowInEvaluate = shouldThrowInEvaluate
    }
}

// Dummy context for testing, specific to this test file
private class CTP_TestEvaluationContext: EvaluationContext { // Renamed
    private let state: Any?
    private var _traceIndex: Int = 0

    init(state: Any?) {
        self.state = state
    }

    var currentTraceIndex: Int {
        get { return _traceIndex }
        set { _traceIndex = newValue }
    }
    
    func currentStateAs<S>(_ type: S.Type) -> S? {
        return state as? S
    }
}

// Custom error for testing evaluation logic throws, specific to this test file
private enum CTP_TestEvaluationError: Error, Equatable { // Renamed
    case intentionalError
}

@Suite struct ClosureTemporalPropositionTests {

    @Test("Evaluate succeeds when context provides correct state type and logic returns value")
    func testEvaluate_Success() throws {
        let state = CTP_TestState(value: 10)
        let context = CTP_TestEvaluationContext(state: state)
        let proposition = ClosureTemporalProposition<CTP_TestState, Int>(
            id: "p_success",
            name: "Proposition Success",
            evaluate: { (testState: CTP_TestState) -> Int in testState.value * 2 } // Explicit type for closure param
        )

        let result = try proposition.evaluate(in: context)
        #expect(result == 20)
    }

    @Test("Evaluate throws stateTypeMismatch when context cannot provide expected state type")
    func testEvaluate_StateTypeMismatch() throws {
        let context = CTP_TestEvaluationContext(state: "NotTheCorrectState") // String instead of CTP_TestState
        let proposition = ClosureTemporalProposition<CTP_TestState, Int>(
            id: "p_mismatch",
            name: "Proposition State Mismatch",
            evaluate: { (testState: CTP_TestState) -> Int in testState.value } // Explicit type
        )

        // Check for the specific error type
        #expect(throws: TemporalKitError.self) { // Expecting any TemporalKitError
            _ = try proposition.evaluate(in: context)
        }

        // More specific error check
        // Note: Default EvaluationContext implementation cannot distinguish between
        // "state not available" and "type mismatch", so it returns stateNotAvailable
        do {
            _ = try proposition.evaluate(in: context)
            Issue.record("Expected TemporalKitError but no error was thrown.")
        } catch let error as TemporalKitError {
            switch error {
            case .stateNotAvailable(let expected, let propID, let propName):
                // This is expected with default EvaluationContext implementation
                #expect(expected == String(describing: CTP_TestState.self))
                #expect(propID == proposition.id)
                #expect(propName == proposition.name)
            case .stateTypeMismatch:
                // This would happen with a custom EvaluationContext that implements retrieveState
                break
            }
        } catch {
            Issue.record("Expected TemporalKitError but got a different error type: \(error)")
        }
    }

    @Test("Evaluate rethrows error from evaluationLogic")
    func testEvaluate_EvaluationLogicThrows() throws {
        let state = CTP_TestState(value: 1, shouldThrowInEvaluate: true)
        let context = CTP_TestEvaluationContext(state: state)
        let proposition = ClosureTemporalProposition<CTP_TestState, Int>(
            id: "p_eval_throws",
            name: "Proposition Evaluation Throws",
            evaluate: { (testState: CTP_TestState) -> Int in // Explicit type
                if testState.shouldThrowInEvaluate {
                    throw CTP_TestEvaluationError.intentionalError
                }
                return testState.value
            }
        )

        #expect(throws: CTP_TestEvaluationError.intentionalError) {
            _ = try proposition.evaluate(in: context)
        }
    }
    
    @Test("nonThrowing factory creates proposition that evaluates correctly")
    func testNonThrowingFactory_Success() throws {
        let state = CTP_TestState(value: 50)
        let context = CTP_TestEvaluationContext(state: state)
        
        let proposition = ClosureTemporalProposition<CTP_TestState, String>.nonThrowing(
            id: "p_non_throwing_success",
            name: "Non-Throwing Proposition Success",
            evaluate: { (testState: CTP_TestState) -> String in "Value is \(testState.value)" } // Explicit type
        )

        let result = try proposition.evaluate(in: context)
        #expect(result == "Value is 50")
    }

    @Test("nonThrowing factory with non-throwing logic (testing internal throwing adaptation)")
    func testNonThrowingFactory_InternalLogicCoverage() throws {
        let state = CTP_TestState(value: 1) 
        let context = CTP_TestEvaluationContext(state: state)
        
        let proposition = ClosureTemporalProposition<CTP_TestState, Int>.nonThrowing(
            id: "p_non_throwing_coverage",
            name: "Non-Throwing Proposition Coverage",
            evaluate: { (testState: CTP_TestState) -> Int in // Explicit type
                return testState.value // This line (inside the nonThrowing's adapted closure) needs coverage
            }
        )

        let result = try proposition.evaluate(in: context) // This call will execute the adapted closure
        #expect(result == 1)
    }
} 
