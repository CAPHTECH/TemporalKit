import Foundation

public enum TemporalKitError: Error, LocalizedError {
    case stateTypeMismatch(expected: String, actual: String, propositionID: PropositionID, propositionName: String)
    // Add other general TemporalKit errors here if any in the future

    public var errorDescription: String? {
        switch self {
        case .stateTypeMismatch(let expected, let actual, let propID, let propName):
            return "State type mismatch for proposition '\(propName)' (ID: \(propID.rawValue)). Expected context to provide '\(expected)', but got '\(actual)'."
        }
    }
} 
