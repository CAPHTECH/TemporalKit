import Foundation

/// A sendable wrapper for invalid argument information that preserves type information as a string.
public struct InvalidArgumentInfo: Sendable {
    public let parameter: String
    public let valueDescription: String
    public let reason: String
    
    public init<T>(parameter: String, value: T?, reason: String) {
        self.parameter = parameter
        self.valueDescription = value.map { String(describing: $0) } ?? "nil"
        self.reason = reason
    }
}

public enum TemporalKitError: Error, LocalizedError {
    case stateTypeMismatch(expected: String, actual: String, propositionID: PropositionID, propositionName: String)
    case stateNotAvailable(expected: String, propositionID: PropositionID, propositionName: String)
    case configurationError(message: String)
    case invalidArgument(InvalidArgumentInfo)
    case unsupportedOperation(operation: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .stateTypeMismatch(let expected, let actual, let propID, let propName):
            return "State type mismatch for proposition '\(propName)' (ID: \(propID.rawValue)). Expected context to provide '\(expected)', but got '\(actual)'."
        case .stateNotAvailable(let expected, let propID, let propName):
            return "State not available for proposition '\(propName)' (ID: \(propID.rawValue)). Expected context to provide '\(expected)', but no state was available."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .invalidArgument(let info):
            return "Invalid argument for parameter '\(info.parameter)' (value: \(info.valueDescription)): \(info.reason)"
        case .unsupportedOperation(let operation, let reason):
            return "Unsupported operation '\(operation)': \(reason)"
        }
    }
}
