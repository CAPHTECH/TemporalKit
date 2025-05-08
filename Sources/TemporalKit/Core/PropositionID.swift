import Foundation

public struct PropositionID: Hashable, Equatable, RawRepresentable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
