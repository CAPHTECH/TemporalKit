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

    public init?(rawValue: String) {
        do {
            try self.init(validating: rawValue)
        } catch {
            return nil
        }
    }

    /// Throwing initializer that provides detailed error information
    public init(validating rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw PropositionIDError.emptyString
        }

        var invalidCharacters: [Character] = []

        // Single pass validation with prioritized error reporting
        for char in rawValue {
            if char.isWhitespace {
                throw PropositionIDError.containsWhitespace
            }
            if !Self.isValidCharacter(char) {
                invalidCharacters.append(char)
            }
        }

        guard invalidCharacters.isEmpty else {
            let invalidString = String(invalidCharacters)
            throw PropositionIDError.invalidCharacters(invalidString)
        }

        self.rawValue = rawValue
    }

    /// Optimized character validation using direct character property checks
    @inline(__always)
    private static func isValidCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_" || char == "-" || char == "."
    }

    /// Convenience initializer for backward compatibility
    /// - Warning: This will return nil for invalid IDs. Use `init(validating:)` for detailed errors.
    public init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}
