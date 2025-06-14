import Foundation

/// LTL論理式のトレース評価時に発生する可能性のあるエラー
public enum LTLTraceEvaluationError: Error, Equatable, LocalizedError {
    /// トレースが空の場合
    case emptyTrace

    /// 命題の評価に失敗した場合
    case propositionEvaluationFailure(String)

    /// トレースが終了したが、式の真偽値を判断するために将来の状態が必要な場合
    case inconclusiveEvaluation(String)

    /// トレースのインデックスが範囲外の場合
    case traceIndexOutOfBounds(index: Int, traceLength: Int)

    public var errorDescription: String? {
        switch self {
        case .emptyTrace:
            return "Cannot evaluate formula on an empty trace. At least one state is required."
        case .propositionEvaluationFailure(let details):
            return "Failed to evaluate proposition: \(details)"
        case .inconclusiveEvaluation(let details):
            return "Cannot determine truth value: \(details)"
        case .traceIndexOutOfBounds(let index, let traceLength):
            return "Trace index \(index) is out of bounds for trace of length \(traceLength)"
        }
    }
}
