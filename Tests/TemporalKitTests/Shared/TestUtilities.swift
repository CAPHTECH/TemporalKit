import Foundation
import Testing
@testable import TemporalKit

// MARK: - Shared Test Helper Structures

public struct TestState { 
    public let index: Int 
    public init(index: Int) {
        self.index = index
    }
}

public struct TestEvalContext: EvaluationContext {
    public let state: TestState
    public let _traceIndex: Int
    
    public init(state: TestState, traceIndex: Int) {
        self.state = state
        self._traceIndex = traceIndex
    }
    
    public func currentStateAs<T>(_ type: T.Type) -> T? { 
        state as? T 
    }
    
    public var traceIndex: Int? { 
        _traceIndex 
    }
}

// MARK: - Common Helper Functions

public func createTestTrace(length: Int) -> [TestEvalContext] {
    (0..<length).map { TestEvalContext(state: TestState(index: $0), traceIndex: $0) }
}

public func createTrace(length: Int) -> [TestEvalContext] {
    createTestTrace(length: length)
}

public func createTrace(from bools: [Bool]) -> [TestEvalContext] {
    bools.enumerated().map { TestEvalContext(state: TestState(index: $1 ? 1 : 0), traceIndex: $0) }
}

// MARK: - Common Test Propositions

public struct TestPropositions {
    public static let p_true = ClosureTemporalProposition<TestState, Bool>(id: "p_true", name: "Always True") { _ in true }
    public static let p_false = ClosureTemporalProposition<TestState, Bool>(id: "p_false", name: "Always False") { _ in false }
    public static let q_true = ClosureTemporalProposition<TestState, Bool>(id: "q_true", name: "Q Always True") { _ in true }
    public static let q_false = ClosureTemporalProposition<TestState, Bool>(id: "q_false", name: "Q Always False") { _ in false }
}

// Common propositions for convenience
public let p_true_prop = TestPropositions.p_true
public let p_false_prop = TestPropositions.p_false
public let q_true_prop = TestPropositions.q_true
public let q_false_prop = TestPropositions.q_false

// MARK: - Type Aliases

public typealias TestFormula = LTLFormula<ClosureTemporalProposition<TestState, Bool>>

// Common formulas for convenience
public let ltl_true: TestFormula = .atomic(p_true_prop)
public let ltl_false: TestFormula = .atomic(p_false_prop)
public let ltl_q_true: TestFormula = .atomic(q_true_prop)
public let ltl_q_false: TestFormula = .atomic(q_false_prop)