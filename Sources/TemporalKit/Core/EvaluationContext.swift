import Foundation

/// Represents the context in which a temporal proposition is evaluated.
/// This could be a specific state in a trace, a set of variable bindings, etc.
public protocol EvaluationContext {
    /// Provides access to the current state or relevant information needed for evaluation.
    /// For example, this could return the current `AppState` in a trace-based evaluation.
    /// - Parameter type: The expected type of the state object.
    /// - Returns: The current state object cast to the specified type, or `nil` if not applicable or cast fails.
    func currentStateAs<T>(_ type: T.Type) -> T?

    /// An optional index, for contexts that are part of a sequence (e.g., a trace).
    var traceIndex: Int? { get }
}

// Provide a default for traceIndex if not applicable
public extension EvaluationContext {
    var traceIndex: Int? { return nil }
}
