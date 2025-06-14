import Foundation

/// Creates a new `ClosureTemporalProposition` with a non-throwing evaluation closure.
///
/// This global factory function infers the `StateType` and `PropositionResultType`
/// from the provided evaluation closure.
///
/// - Parameters:
///   - id: The unique identifier for the proposition.
///   - name: The human-readable name of the proposition.
///   - evaluate: A non-throwing closure that takes an object of `StateType`
///               and returns the `PropositionResultType`.
/// - Returns: A new `ClosureTemporalProposition` instance.
public func makeProposition<StateType, PropositionResultType: Hashable>(
    id: String,
    name: String,
    evaluate: @escaping (StateType) -> PropositionResultType
) -> ClosureTemporalProposition<StateType, PropositionResultType> {
    // Internally, it calls the static 'nonThrowing' factory method we already defined.
    ClosureTemporalProposition<StateType, PropositionResultType>.nonThrowing(
        id: id,
        name: name,
        evaluate: evaluate
    )
}
