import Foundation

/// A generic, closure-based implementation of `TemporalProposition`.
///
/// This class allows defining propositions using a closure for their evaluation logic,
/// making it convenient for simpler propositions without needing to create a separate subclass.
/// It is generic over the `StateType` it expects from the `EvaluationContext` and the
/// `PropositionResultType` that the evaluation yields.
open class ClosureTemporalProposition<StateType, PropositionResultType: Hashable>: TemporalProposition {
    public typealias Value = PropositionResultType

    public let id: PropositionID
    public let name: String
    private let evaluationLogic: (StateType) throws -> PropositionResultType

    /// Initializes a new closure-based temporal proposition.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the proposition.
    ///   - name: The human-readable name of the proposition.
    ///   - evaluate: A closure that takes an object of `StateType` and returns the `PropositionResultType`.
    ///               This closure can throw errors.
    public init(id: String, name: String, evaluate: @escaping (StateType) throws -> PropositionResultType) {
        self.id = PropositionID(rawValue: id)
        self.name = name
        self.evaluationLogic = evaluate
    }

    /// Evaluates the proposition using the stored closure against the state provided by the context.
    ///
    /// - Parameter context: The `EvaluationContext` which should provide the `StateType`.
    /// - Returns: The result of the evaluation closure.
    /// - Throws: `TemporalKitError.stateTypeMismatch` if the context cannot provide the expected `StateType`.
    ///           Also rethrows any errors thrown by the evaluation closure itself.
    public func evaluate(in context: EvaluationContext) throws -> PropositionResultType {
        guard let state = context.currentStateAs(StateType.self) else {
            throw TemporalKitError.stateTypeMismatch(
                expected: String(describing: StateType.self),
                actual: String(describing: type(of: context)),
                propositionID: self.id,
                propositionName: self.name
            )
        }
        return try evaluationLogic(state)
    }

    /// Creates a new proposition with a non-throwing evaluation closure.
    /// This is a convenience factory method for cases where the evaluation logic
    /// is guaranteed not to throw.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the proposition.
    ///   - name: The human-readable name of the proposition.
    ///   - evaluate: A non-throwing closure that takes an object of `StateType`
    ///               and returns the `PropositionResultType`.
    /// - Returns: A new `ClosureTemporalProposition` instance.
    public static func nonThrowing(
        id: String,
        name: String,
        evaluate: @escaping (StateType) -> PropositionResultType
    ) -> ClosureTemporalProposition<StateType, PropositionResultType> {
        return ClosureTemporalProposition(
            id: id,
            name: name,
            evaluate: { state in // Adapt the non-throwing closure to the internal throwing signature
                return evaluate(state)
            }
        )
    }
    
    // Conformance to Hashable & Equatable is implicitly handled by the default implementations
    // in TemporalProposition protocol extension, based on `id`.
    // Conformance to Identifiable is satisfied by `id: PropositionID`.
    // Conformance to AnyObject is satisfied because this is a class.
} 
