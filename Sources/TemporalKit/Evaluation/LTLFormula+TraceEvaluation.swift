import Foundation

extension LTLFormula {
    /// Evaluates the LTL formula over an entire trace of states.
    ///
    /// This is a convenient way to check if a formula holds for a given trace. The method
    /// steps through the trace state by state, applying the `step` function to evaluate at each point.
    ///
    /// - Parameters:
    ///   - trace: An array of evaluation contexts, each representing a state in the trace.
    ///   - produceDetailedOutput: If true, returns detailed information at each step. Default is false.
    /// - Returns: A Boolean indicating whether the formula holds for the entire trace.
    /// - Throws: `LTLTraceEvaluationError` in case of evaluation failures.
    public func evaluate(over trace: [EvaluationContext], 
                         produceDetailedOutput: Bool = false) throws -> Bool {
        guard !trace.isEmpty else {
            throw LTLTraceEvaluationError.emptyTrace
        }
        
        var currentFormula = self
        var overallHolds = true
        
        if produceDetailedOutput {
            print("Starting evaluation of formula: \(self)")
        }
        
        for (index, context) in trace.enumerated() {
            let (holdsNow, nextFormula) = try currentFormula.step(with: context)
            
            if produceDetailedOutput {
                print("Step \(index): Holds Now = \(holdsNow), Next Formula = \(nextFormula)")
            }
            
            // Update the overallHolds status based on the formula type
            switch self {
            case .globally:
                // G p requires p to hold at every state.
                // If it ever doesn't hold, the entire formula fails.
                if !holdsNow {
                    if produceDetailedOutput {
                        print("G formula violated at step \(index)")
                    }
                    return false
                }
                
            case .eventually:
                // F p requires p to hold at some state.
                // If we find such a state, overallHolds becomes true and we're done.
                if holdsNow {
                    if produceDetailedOutput {
                        print("F formula satisfied at step \(index)")
                    }
                    return true
                }
                // For eventually, start with false and look for a state where it holds.
                overallHolds = false
                
            default:
                // For other formula types, the holdsNow value determines if it holds at the current step.
                // This is used directly for atomic propositions and may be combined for complex formulas.
                overallHolds = holdsNow
                
                // If the formula has a definitive result (true/false boolean literal), we can terminate early.
                if case .booleanLiteral(let value) = nextFormula {
                    if produceDetailedOutput {
                        print("Formula evaluation completed at step \(index) with result: \(value)")
                    }
                    return value
                }
            }
            
            // Update the currentFormula for the next iteration.
            currentFormula = nextFormula
        }
        
        // If we've gone through the entire trace and haven't hit a terminal case:
        // 1. For G p: If we get here, p held throughout the entire trace, so overallHolds should be true.
        // 2. For F p: If we get here, p never held in the trace, so overallHolds should be false.
        // 3. For other formulas: The final state of overallHolds reflects whether the formula holds for the trace.
        
        // Handle inconclusive cases
        if case .globally = self, !trace.isEmpty {
            // For G p, if we've gone through the entire trace and p always held (we'd have returned false otherwise),
            // then the formula is true for the finite trace.
            return true
        }
        
        if case .eventually = self, !trace.isEmpty {
            // For F p, if we've gone through the entire trace and never found a state where p holds,
            // then the formula is false for the finite trace.
            return false
        }
        
        // For formulas that involve future obligations (like X p at the end of the trace),
        // we don't have enough states to conclusively evaluate.
        if case .next = currentFormula {
            throw LTLTraceEvaluationError.inconclusiveEvaluation("Cannot evaluate Next at the end of the trace")
        }
        
        return overallHolds
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
