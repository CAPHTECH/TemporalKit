import Foundation

/// Evaluates an LTL formula against a trace of states.
/// 
/// Note: This class is now redundant. Use `LTLFormula.evaluate(over:debugHandler:)` instead
/// for better performance and consistency.
@available(*, deprecated, message: "Use LTLFormula.evaluate(over:debugHandler:) instead")
public class LTLFormulaTraceEvaluator<P: TemporalProposition> where P.Value == Bool {

    public init() {}

    /// Evaluates the given LTL formula against the provided trace of states.
    ///
    /// - Parameters:
    ///   - formula: The LTL formula to evaluate.
    ///   - trace: An array of states representing the trace. Each element `S` is a state.
    ///   - contextProvider: A closure that takes a state `S` from the trace and its index `Int`,
    ///     and returns an `EvaluationContext` (`C`) suitable for evaluating propositions within that state.
    /// - Returns: `true` if the formula holds on the trace, `false` otherwise.
    /// - Throws: An error if evaluation cannot be performed (e.g., empty trace for certain operators).
    public func evaluate<S, C: EvaluationContext>(formula: LTLFormula<P>, trace: [S], contextProvider: (S, Int) -> C) throws -> Bool {
        return try evaluateRecursive(formula: formula, trace: trace, currentIndex: 0, contextProvider: contextProvider)
    }

    private func evaluateRecursive<S, C: EvaluationContext>(formula: LTLFormula<P>, trace: [S], currentIndex: Int, contextProvider: (S, Int) -> C) throws -> Bool {
        switch formula {
        case .booleanLiteral(let value):
            return value

        case .atomic(let proposition):
            guard currentIndex < trace.count else {
                throw LTLTraceEvaluationError.inconclusiveEvaluation("Trace index \(currentIndex) out of bounds for trace length \(trace.count)")
            }
            let context = contextProvider(trace[currentIndex], currentIndex)
            do {
                return try proposition.evaluate(in: context)
            } catch {
                throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: \(error)")
            }

        case .not(let subformula):
            return try !evaluateRecursive(formula: subformula, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider)

        case .and(let left, let right):
            if try !evaluateRecursive(formula: left, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider) { // if left is false
                return false
            }
            return try evaluateRecursive(formula: right, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider)

        case .or(let left, let right):
            if try evaluateRecursive(formula: left, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider) { // if left is true
                return true
            }
            return try evaluateRecursive(formula: right, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider)

        case .implies(let left, let right):
            if try !evaluateRecursive(formula: left, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider) { // if A is false
                return true
            }
            return try evaluateRecursive(formula: right, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider)

        case .next(let subformula):
            let nextIndex = currentIndex + 1
            guard nextIndex < trace.count else {
                throw LTLTraceEvaluationError.inconclusiveEvaluation("Cannot evaluate Next at end of trace - next index \(nextIndex) out of bounds")
            }
            return try evaluateRecursive(formula: subformula, trace: trace, currentIndex: nextIndex, contextProvider: contextProvider)

        case .eventually(let subformula):
            if currentIndex >= trace.count { // F(phi) on empty (remaining) trace is false
                return false 
            }
            for i in currentIndex..<trace.count {
                if try evaluateRecursive(formula: subformula, trace: trace, currentIndex: i, contextProvider: contextProvider) {
                    return true
                }
            }
            return false

        case .globally(let subformula):
            if currentIndex >= trace.count { // G(phi) on empty (remaining) trace is true (vacuously)
                return true
            }
            for i in currentIndex..<trace.count {
                if try !evaluateRecursive(formula: subformula, trace: trace, currentIndex: i, contextProvider: contextProvider) {
                    return false
                }
            }
            return true

        case .until(let left, let right):
            if currentIndex >= trace.count { // p U q on empty (remaining) trace is false
                return false
            }
            for j in currentIndex..<trace.count {
                if try evaluateRecursive(formula: right, trace: trace, currentIndex: j, contextProvider: contextProvider) {
                    for k in currentIndex..<j {
                        if try !evaluateRecursive(formula: left, trace: trace, currentIndex: k, contextProvider: contextProvider) {
                            return false
                        }
                    }
                    return true
                }
            }
            return false
        
        case .weakUntil(let left, let right):
            let globallyLeftFormula = LTLFormula<P>.globally(left)
            if try evaluateRecursive(formula: globallyLeftFormula, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider) {
                return true
            }
            let untilFormula = LTLFormula<P>.until(left, right)
            return try evaluateRecursive(formula: untilFormula, trace: trace, currentIndex: currentIndex, contextProvider: contextProvider)
            
        case .release(let left, let right):
            // p R q  is equivalent to not ( (not p) U (not q) )
            let notP = LTLFormula<P>.not(left)
            let notQ = LTLFormula<P>.not(right)
            let notPUntilNotQ = LTLFormula<P>.until(notP, notQ)
            let equivalentFormula = LTLFormula<P>.not(notPUntilNotQ)
            
            return try evaluateRecursive(
                formula: equivalentFormula,
                trace: trace,
                currentIndex: currentIndex,
                contextProvider: contextProvider
            )
        }
    }
}

 
