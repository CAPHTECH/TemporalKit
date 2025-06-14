import Foundation

/// A generic, closure-based implementation of `TemporalProposition`.
///
/// This class allows defining propositions using a closure for their evaluation logic,
/// making it convenient for simpler propositions without needing to create a separate subclass.
/// It is generic over the `StateType` it expects from the `EvaluationContext` and the
/// `PropositionResultType` that the evaluation yields.
///
/// - Important: Thread Safety: This class is immutable after initialization and thus thread-safe.
///   Subclasses MUST NOT add mutable state to maintain Sendable conformance.
///   The `@unchecked Sendable` conformance is safe because all stored properties are immutable
///   and the evaluation logic closure is marked as `@Sendable`.
open class ClosureTemporalProposition<StateType, PropositionResultType: Hashable>: TemporalProposition, @unchecked Sendable {
    public typealias Value = PropositionResultType

    public let id: PropositionID
    public let name: String
    private let evaluationLogic: @Sendable (StateType) throws -> PropositionResultType

    /// Initializes a new closure-based temporal proposition.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the proposition.
    ///   - name: The human-readable name of the proposition.
    ///   - evaluate: A closure that takes an object of `StateType` and returns the `PropositionResultType`.
    ///               This closure can throw errors.
    /// - Note: If the provided ID is invalid, a fallback ID will be generated. For explicit error handling,
    ///         use `init(validatingId:name:evaluate:)` instead.
    public init(id: String, name: String, evaluate: @escaping @Sendable (StateType) throws -> PropositionResultType) {
        // Use the factory to create ID with safe fallback handling
        if let validID = PropositionIDFactory.createOrNil(from: id) {
            self.id = validID
        } else {
            // Ultimate fallback - this should rarely happen
            assertionFailure("Failed to create fallback ID for: \(id)")
            // Use a guaranteed valid ID as last resort - this is a programming error if it fails
            self.id = PropositionID(rawValue: "invalid_proposition") ?? {
                fatalError("Critical error: Unable to create any valid PropositionID. This indicates a fundamental system failure.")
            }()
        }
        self.name = name
        self.evaluationLogic = evaluate
    }

    /// Initializes a new closure-based temporal proposition with explicit ID validation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the proposition.
    ///   - name: The human-readable name of the proposition.
    ///   - evaluate: A closure that takes an object of `StateType` and returns the `PropositionResultType`.
    ///               This closure can throw errors.
    /// - Throws: `TemporalKitError` if the provided ID is invalid and no fallback ID can be created.
    public init(validatingId id: String, name: String, evaluate: @escaping @Sendable (StateType) throws -> PropositionResultType) throws {
        // Use the factory for strict validation with proper error handling
        self.id = try PropositionIDFactory.create(from: id)
        self.name = name
        self.evaluationLogic = evaluate
    }

    /// Evaluates the proposition using the stored closure against the state provided by the context.
    ///
    /// - Parameter context: The `EvaluationContext` which should provide the `StateType`.
    /// - Returns: The result of the evaluation closure.
    /// - Throws: `TemporalKitError.stateNotAvailable` if the context does not provide any state.
    ///           `TemporalKitError.stateTypeMismatch` if the context provides a state of the wrong type.
    ///           Also rethrows any errors thrown by the evaluation closure itself.
    public func evaluate(in context: EvaluationContext) throws -> PropositionResultType {
        switch context.retrieveState(StateType.self) {
        case .success(let state):
            return try evaluationLogic(state)
        case .notAvailable:
            throw TemporalKitError.stateNotAvailable(
                expected: String(describing: StateType.self),
                propositionID: self.id,
                propositionName: self.name
            )
        case .typeMismatch(let actualType):
            throw TemporalKitError.stateTypeMismatch(
                expected: String(describing: StateType.self),
                actual: String(describing: actualType),
                propositionID: self.id,
                propositionName: self.name
            )
        }
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
        evaluate: @escaping @Sendable (StateType) -> PropositionResultType
    ) -> ClosureTemporalProposition<StateType, PropositionResultType> {
        ClosureTemporalProposition(
            id: id,
            name: name,
            evaluate: { state in // Adapt the non-throwing closure to the internal throwing signature
                evaluate(state)
            }
        )
    }

    // Conformance to Hashable & Equatable is implicitly handled by the default implementations
    // in TemporalProposition protocol extension, based on `id`.
    // Conformance to Identifiable is satisfied by `id: PropositionID`.
    // Conformance to AnyObject is satisfied because this is a class.
}
