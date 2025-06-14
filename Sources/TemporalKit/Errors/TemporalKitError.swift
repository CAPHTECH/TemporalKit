import Foundation

public enum TemporalKitError: Error, LocalizedError {
    case stateTypeMismatch(expected: String, actual: String, propositionID: PropositionID, propositionName: String)
    case stateNotAvailable(expected: String, propositionID: PropositionID, propositionName: String)
    case configurationError(message: String)
    case invalidArgument(parameter: String, value: String?, reason: String)
    case unsupportedOperation(operation: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .stateTypeMismatch(let expected, let actual, let propID, let propName):
            return "State type mismatch for proposition '\(propName)' (ID: \(propID.rawValue)). Expected context to provide '\(expected)', but got '\(actual)'."
        case .stateNotAvailable(let expected, let propID, let propName):
            return "State not available for proposition '\(propName)' (ID: \(propID.rawValue)). Expected context to provide '\(expected)', but no state was available."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .invalidArgument(let parameter, let value, let reason):
            var description = "Invalid argument for parameter '\(parameter)'"
            if let value = value {
                description += " (value: \(value))"
            }
            return description + ": \(reason)"
        case .unsupportedOperation(let operation, let reason):
            return "Unsupported operation '\(operation)': \(reason)"
        }
    }
}

// MARK: - Type-safe Error Creation

extension TemporalKitError {
    /// Creates an invalidArgument error with type information preserved as a string.
    /// This method provides better debugging information by including the actual type.
    public static func invalidArgumentWithType<T>(
        parameter: String,
        value: T?,
        reason: String
    ) -> TemporalKitError {
        .invalidArgument(
            parameter: parameter,
            value: value.map { String(describing: $0) },
            reason: reason
        )
    }
}
