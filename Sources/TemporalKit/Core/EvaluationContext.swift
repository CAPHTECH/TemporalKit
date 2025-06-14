import Foundation

/// Result of attempting to retrieve state from an evaluation context
public enum StateRetrievalResult<T> {
    case success(T)
    case notAvailable
    case typeMismatch(actual: Any.Type)
}

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

// Provide defaults and enhanced functionality via extension
public extension EvaluationContext {
    var traceIndex: Int? { nil }

    /// Enhanced state retrieval with detailed error information
    /// This is provided as an extension method to maintain backward compatibility.
    /// - Parameter type: The expected type of the state object.
    /// - Returns: A result indicating success or the specific failure reason.
    /// - Note: Default implementation cannot distinguish between nil state and type mismatch.
    ///         Override this method in your implementation for more precise error reporting.
    func retrieveState<T>(_ type: T.Type) -> StateRetrievalResult<T> {
        if let state = currentStateAs(type) {
            return .success(state)
        } else {
            // Default implementation cannot distinguish between these cases
            return .notAvailable
        }
    }
}
