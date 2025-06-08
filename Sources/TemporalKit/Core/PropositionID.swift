import Foundation

/// Errors that can occur when creating a PropositionID
public enum PropositionIDError: Error, LocalizedError, Equatable {
    case emptyString
    case containsWhitespace
    case invalidCharacters(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyString:
            return "PropositionID cannot be empty"
        case .containsWhitespace:
            return "PropositionID cannot contain whitespace characters"
        case .invalidCharacters(let chars):
            return "PropositionID contains invalid characters: \(chars)"
        }
    }
}

public struct PropositionID: Hashable, Equatable, RawRepresentable, Codable, Sendable {
    public let rawValue: String
    
    /// Valid characters for PropositionID: alphanumeric, underscore, hyphen, and dot
    private static let validCharacterSet = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "_-."))

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        guard rawValue.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        guard rawValue.rangeOfCharacter(from: Self.validCharacterSet.inverted) == nil else { return nil }
        self.rawValue = rawValue
    }
    
    /// Throwing initializer that provides detailed error information
    public init(validating rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw PropositionIDError.emptyString
        }
        guard rawValue.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw PropositionIDError.containsWhitespace
        }
        if let range = rawValue.rangeOfCharacter(from: Self.validCharacterSet.inverted) {
            let invalidChars = String(rawValue[range])
            throw PropositionIDError.invalidCharacters(invalidChars)
        }
        self.rawValue = rawValue
    }
    
    /// Convenience initializer for backward compatibility
    /// - Warning: This will return nil for invalid IDs. Use `init(validating:)` for detailed errors.
    public init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}
