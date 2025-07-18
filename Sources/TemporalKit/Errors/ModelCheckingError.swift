import Foundation

/// モデルチェッキング処理中に発生するエラー
public enum ModelCheckingError<State: Sendable>: Error, LocalizedError {
    /// 無効なKripke構造
    case invalidKripkeStructure(reason: String)

    /// Büchiオートマトンへの変換エラー
    case buchiConversionError(formula: String, reason: String)

    /// 反例が見つかった場合
    case counterexampleFound(path: [State], loopStart: Int?, formula: String)

    /// 状態空間が大きすぎる場合
    case stateSpaceExhausted(statesExplored: Int, limit: Int)

    /// タイムアウト
    case timeout(elapsed: TimeInterval, limit: TimeInterval)

    /// メモリ不足
    case outOfMemory(used: Int, limit: Int)

    /// 循環検出エラー
    case cycleDetectionError(reason: String)

    /// オートマトン構築エラー
    case automatonConstructionError(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidKripkeStructure(let reason):
            return "Invalid Kripke structure: \(reason)"

        case .buchiConversionError(let formula, let reason):
            return "Failed to convert formula '\(formula)' to Büchi automaton: \(reason)"

        case .counterexampleFound(let path, let loopStart, let formula):
            var description = "Counterexample found for formula '\(formula)'. Path length: \(path.count)"
            if let loopStart = loopStart {
                description += ", Loop starts at index \(loopStart)"
            }
            return description

        case .stateSpaceExhausted(let explored, let limit):
            return "State space exhausted. Explored \(explored) states (limit: \(limit))."

        case .timeout(let elapsed, let limit):
            return "Model checking timed out after \(String(format: "%.2f", elapsed))s (limit: \(String(format: "%.2f", limit))s)."

        case .outOfMemory(let used, let limit):
            return "Out of memory. Used \(used) MB (limit: \(limit) MB)."

        case .cycleDetectionError(let reason):
            return "Cycle detection error: \(reason)"

        case .automatonConstructionError(let reason):
            return "Automaton construction error: \(reason)"
        }
    }
}

/// モデルチェッキングの統計情報
public struct ModelCheckingStatistics: Sendable {
    public let statesExplored: Int
    public let transitionsExplored: Int
    public let timeElapsed: TimeInterval
    public let peakMemoryUsage: Int? // MB, optional since it might not be available

    public init(
        statesExplored: Int,
        transitionsExplored: Int,
        timeElapsed: TimeInterval,
        peakMemoryUsage: Int? = nil
    ) {
        self.statesExplored = statesExplored
        self.transitionsExplored = transitionsExplored
        self.timeElapsed = timeElapsed
        self.peakMemoryUsage = peakMemoryUsage
    }
}

// MARK: - Migration Support

/// A wrapper for state types that conditionally conforms to Sendable.
/// When T is Sendable, this wrapper is also Sendable.
/// When T is not Sendable, you must use UnsafeSendableStateBox instead.
public struct SendableStateBox<T> {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }
}

// Conditional Sendable conformance - only when T is Sendable
extension SendableStateBox: Sendable where T: Sendable {}

/// An unsafe wrapper for non-sendable state types during migration.
/// - Warning: This type bypasses Swift concurrency checks. You must ensure thread safety manually.
@available(*, deprecated, message: "Only for migration. Ensure thread safety manually when using non-Sendable state types.")
public struct UnsafeSendableStateBox<T>: @unchecked Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
        #if DEBUG
        print("⚠️ Warning: Using UnsafeSendableStateBox with \(type(of: value)). Ensure thread safety manually.")
        #endif
    }
}

/// Type alias for backward compatibility with non-Sendable state types.
/// - Warning: This is deprecated and will be removed in a future version.
///   Please ensure your state types conform to Sendable.
@available(*, deprecated, message: "Use ModelCheckingError with Sendable state types. For non-Sendable types, explicitly use UnsafeSendableStateBox.")
public typealias LegacyModelCheckingError<State> = ModelCheckingError<UnsafeSendableStateBox<State>>
