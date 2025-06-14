import Foundation

extension LTLFormula {
    /// Evaluates the LTL formula over an entire trace of states.
    ///
    /// This method steps through the trace state by state, applying the `step` function 
    /// to evaluate at each point.
    ///
    /// - Parameters:
    ///   - trace: An array of evaluation contexts, each representing a state in the trace.
    ///   - debugHandler: Optional closure for debug output. Default is nil.
    /// - Returns: A Boolean indicating whether the formula holds for the entire trace.
    /// - Throws: `LTLTraceEvaluationError` in case of evaluation failures.
    public func evaluate(over trace: [EvaluationContext],
                         debugHandler: ((String) -> Void)? = nil) throws -> Bool {
        guard !trace.isEmpty else {
            throw LTLTraceEvaluationError.emptyTrace
        }

        var currentFormula = self
        debugHandler?("Starting evaluation of formula: \(self)")

        for (index, context) in trace.enumerated() {
            let (holdsNow, nextFormula) = try currentFormula.step(with: context)
            debugHandler?("Step \(index): Holds Now = \(holdsNow), Next Formula = \(nextFormula)")

            // Early termination for definitive results
            if case .booleanLiteral(let value) = nextFormula {
                debugHandler?("Formula evaluation completed at step \(index) with result: \(value)")
                return value
            }

            currentFormula = nextFormula
        }

        // Handle end-of-trace cases
        switch currentFormula {
        case .booleanLiteral(let value):
            return value
        case .next:
            throw LTLTraceEvaluationError.inconclusiveEvaluation("Cannot evaluate Next at the end of the trace")
        case .eventually:
            // Eventually should have been satisfied during the trace if it was going to be
            // If we reach the end with an eventually formula, it means it was never satisfied
            return false
        case .globally:
            return true // Globally satisfied in finite trace if we reach here
        case .until:
            return false // Until never satisfied in finite trace
        case .weakUntil:
            return true // Weak until satisfied if we reach here
        case .release:
            return true // Release satisfied if we reach here
        default:
            // For other formulas, the last step's holdsNow determines the result
            return true
        }
    }

    /// Convenience function to evaluate a simple proposition at a specific context.
    ///
    /// - Parameter context: The evaluation context.
    /// - Returns: Whether the formula holds in the given context.
    /// - Throws: `LTLTraceEvaluationError.propositionEvaluationFailure` if evaluation fails.
    public func evaluateAt(_ context: EvaluationContext) throws -> Bool {
        do {
            let (holdsNow, _) = try step(with: context)
            return holdsNow
        } catch {
            throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: \(error)")
        }
    }
}
