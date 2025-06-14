import Testing
@testable import TemporalKit
import Foundation

@Suite("EvaluationContext Tests")
struct EvaluationContextTests {

    struct MockState {
        let value: String
    }

    struct AnotherMockState {
        let count: Int
    }

    struct TestContextWithTraceIndex: EvaluationContext {
        let state: MockState
        let index: Int

        func currentStateAs<T>(_ type: T.Type) -> T? {
            if type == MockState.self {
                return state as? T
            }
            return nil
        }

        var traceIndex: Int? {
            index
        }
    }

    struct TestContextWithoutExplicitTraceIndex: EvaluationContext {
        let state: MockState

        func currentStateAs<T>(_ type: T.Type) -> T? {
            if type == MockState.self {
                return state as? T
            }
            return nil
        }
        // traceIndex will use the default implementation (returns nil)
    }

    struct TestContextEmptyState: EvaluationContext {
        // No state stored directly
        func currentStateAs<T>(_ type: T.Type) -> T? {
            nil // Always returns nil, or could have specific logic
        }
    }

    @Test("currentStateAs returns correct type")
    func testCurrentStateAsReturnsCorrectType() {
        let mockState = MockState(value: "hello")
        let context = TestContextWithTraceIndex(state: mockState, index: 0)

        let retrievedState: MockState? = context.currentStateAs(MockState.self)
        #expect(retrievedState != nil)
        #expect(retrievedState?.value == "hello")
    }

    @Test("currentStateAs returns nil for incorrect type")
    func testCurrentStateAsReturnsNilForIncorrectType() {
        let mockState = MockState(value: "hello")
        let context = TestContextWithTraceIndex(state: mockState, index: 0)

        let retrievedState: AnotherMockState? = context.currentStateAs(AnotherMockState.self)
        #expect(retrievedState == nil)
    }

    @Test("currentStateAs returns nil when context state is empty or different")
    func testCurrentStateAsReturnsNilForEmptyContextState() {
        let context = TestContextEmptyState()
        let retrievedState: MockState? = context.currentStateAs(MockState.self)
        #expect(retrievedState == nil)
    }

    @Test("traceIndex returns correct value when implemented")
    func testTraceIndexReturnsCorrectValueWhenImplemented() {
        let context = TestContextWithTraceIndex(state: MockState(value: "test"), index: 5)
        #expect(context.traceIndex == 5)
    }

    @Test("traceIndex returns nil from default implementation")
    func testTraceIndexReturnsNilFromDefaultImplementation() {
        let context = TestContextWithoutExplicitTraceIndex(state: MockState(value: "test"))
        #expect(context.traceIndex == nil)
    }
}
