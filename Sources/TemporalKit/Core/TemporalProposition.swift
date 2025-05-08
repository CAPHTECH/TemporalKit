import Foundation

public protocol TemporalProposition: AnyObject, Hashable, Identifiable {
    associatedtype Value: Hashable // The type of value this proposition evaluates to (e.g., Bool)
    
    var id: PropositionID { get }
    var name: String { get }
    
    /// Evaluates the proposition in the given context.
    /// - Parameter context: The context in which to evaluate the proposition.
    /// - Returns: The value of the proposition in the given context.
    /// - Throws: An error if the evaluation fails.
    func evaluate(in context: EvaluationContext) throws -> Value
}

// Default implementations for Hashable and Equatable based on 'id'
public func ==<P: TemporalProposition>(lhs: P, rhs: P) -> Bool {
    return lhs.id == rhs.id
}

extension TemporalProposition {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
