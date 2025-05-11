import Foundation

/// LTL論理式のトレース評価時に発生する可能性のあるエラー
public enum LTLTraceEvaluationError: Error, Equatable {
    /// トレースが空の場合
    case emptyTrace
    
    /// 命題の評価に失敗した場合
    case propositionEvaluationFailure(String)
    
    /// トレースが終了したが、式の真偽値を判断するために将来の状態が必要な場合
    case inconclusiveEvaluation(String)
}
