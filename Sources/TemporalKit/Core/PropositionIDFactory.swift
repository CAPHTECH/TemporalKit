import Foundation

/// Factory for creating PropositionID instances with proper fallback handling.
/// This class follows the Single Responsibility Principle by handling only ID creation logic.
public struct PropositionIDFactory {

    /// Creates a PropositionID from a string, with fallback handling.
    /// - Parameter rawValue: The string value to convert to PropositionID
    /// - Returns: A valid PropositionID instance
    /// - Throws: `TemporalKitError` if no valid ID can be created
    public static func create(from rawValue: String) throws -> PropositionID {
        // First, try to create with the provided value
        if let validID = PropositionID(rawValue: rawValue) {
            return validID
        }

        // If that fails, try to create a fallback ID
        return try createFallbackID(original: rawValue)
    }

    /// Creates a PropositionID from a string, using a fallback if necessary.
    /// - Parameter rawValue: The string value to convert to PropositionID
    /// - Returns: A valid PropositionID instance, or nil if creation fails
    public static func createOrNil(from rawValue: String) -> PropositionID? {
        // First, try to create with the provided value
        if let validID = PropositionID(rawValue: rawValue) {
            return validID
        }

        // If that fails, try to create a fallback ID
        return try? createFallbackID(original: rawValue)
    }

    /// Creates a fallback PropositionID when the original string is invalid.
    /// - Parameter original: The original invalid string (for error reporting)
    /// - Returns: A valid fallback PropositionID
    /// - Throws: `TemporalKitError` if no fallback can be created
    private static func createFallbackID(original: String) throws -> PropositionID {
        // Try a deterministic fallback first
        let fallbackID = PropositionID(rawValue: "system_fallback_proposition")
        if let safeID = fallbackID {
            return safeID
        }

        // Generate a UUID-based ID as secondary fallback
        let generatedID = "invalid_proposition_\(UUID().uuidString)"
        if let generatedPropositionID = PropositionID(rawValue: generatedID) {
            return generatedPropositionID
        }

        // If all else fails, throw an error instead of using fatalError
        throw TemporalKitError.invalidArgumentWithType(
            parameter: "propositionID",
            value: original,
            reason: "Unable to create valid PropositionID - validation rules may have changed incompatibly"
        )
    }

    /// Creates a unique PropositionID using a hash-based approach.
    /// This is useful when you need a deterministic but unique ID.
    /// - Parameter seed: A string to use as seed for the hash
    /// - Returns: A valid PropositionID instance
    /// - Throws: `TemporalKitError` if no valid ID can be created
    public static func createUnique(seed: String) throws -> PropositionID {
        let hashValue = abs(seed.hashValue)
        let candidateID = "prop_\(hashValue)"

        if let validID = PropositionID(rawValue: candidateID) {
            return validID
        }

        // Fallback to generic approach
        return try createFallbackID(original: seed)
    }
}
