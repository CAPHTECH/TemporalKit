// Sources/TemporalKit/ModelChecking/LTLModelChecker.swift

import Foundation
// Assuming LTLFormula, TemporalProposition, PropositionID are defined in TemporalKit core modules.
// Need to import BuchiAutomaton as well.
// E.g., import TemporalKitCore
// import TemporalKitLTL
// import TemporalKitBuchi // (if BuchiAutomaton is in its own module, or just ensure it's compiled)

/// Performs LTL (Linear Temporal Logic) model checking on a system model
/// represented by a `KripkeStructure`.
///
/// The `LTLModelChecker` determines if a given LTL formula holds for all possible
/// (infinite) behaviors of the provided system model. It employs algorithms based on
/// Büchi automata theory, a standard approach in formal verification.
///
/// The core process typically involves:
/// 1.  **Negation of the Formula**: The formula `φ` to be checked is negated to `¬φ`.
///     The checker then searches for a behavior in the model that satisfies `¬φ`.
///     If no such behavior exists, `φ` is considered to hold for the model.
/// 2.  **Automaton Construction for `¬φ`**: The LTL formula `¬φ` is translated into an
///     equivalent Büchi automaton `A¬φ`. This automaton accepts exactly those infinite
///     sequences of states that satisfy `¬φ`.
/// 3.  **Automaton Construction for the Model**: The Kripke structure `M` (the system model)
///     is also viewed as a Büchi automaton `Am`. Typically, all states in `Am` are
///     considered accepting.
/// 4.  **Product Automaton**: A product automaton `Am × A¬φ` is constructed. This
///     automaton synchronizes the behaviors of the model and the (negated) formula.
///     An accepting run in the product automaton corresponds to a behavior that is
///     possible in the model `M` AND satisfies `¬φ` (i.e., violates `φ`).
/// 5.  **Emptiness Check**: The language of the product automaton is checked for emptiness.
///     If the language is empty, no behavior in the model violates `φ`, so `φ` holds.
///     If the language is non-empty, any word (infinite run) in it is a counterexample
///     to `φ`.
///
/// **Note**: The actual implementation of steps 2, 4, and 5 (especially LTL to Büchi
/// conversion and emptiness checking for Büchi automata, often using Nested DFS) is
/// highly complex and typically relies on established algorithms from formal methods literature.
public class LTLModelChecker<Model: KripkeStructure> {

    // Define types for the states of Büchi automata involved in model checking.
    // The state of the automaton derived from the LTL formula is often distinct
    // from the states of the model.
    typealias FormulaAutomatonState = Int // Example: LTL-to-Büchi might generate integer states
    typealias ModelAutomatonState = Model.State
    // Use the new generic ProductState for the product automaton's states
    typealias ActualProductAutomatonState = ProductState<Model.State, FormulaAutomatonState>

    // The alphabet for these Büchi automata will be sets of atomic proposition identifiers
    // that are true at a given point.
    typealias BuchiAlphabetSymbol = Set<Model.AtomicPropositionIdentifier>

    public init() {
        // Initialization for the model checker.
    }

    /// Checks if the given LTL formula holds for the provided Kripke structure (model).
    ///
    /// - Parameters:
    ///   - formula: The LTL formula to verify.
    ///   - model: The Kripke structure representing the system model.
    /// - Returns: A `ModelCheckResult` indicating whether the formula `.holds` or, if not,
    ///            `.fails` with a `Counterexample`.
    /// - Throws: An `LTLModelCheckerError` if the model checking procedure encounters
    ///           an unrecoverable issue (e.g., during internal automaton construction
    ///           if/when fully implemented).
    public func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {

        let negatedFormula = LTLFormula.not(formula)
        
        let relevantProps = self.extractPropositions(from: formula, and: model)

        // Call the static method from LTLToBuchiConverter
        let automatonForNegatedFormula: BuchiAutomaton<LTLToBuchiConverter.FormulaAutomatonState, LTLToBuchiConverter.BuchiAlphabetSymbol<Model.AtomicPropositionIdentifier>>
        do {
            automatonForNegatedFormula = try LTLToBuchiConverter.translateLTLToBuchi(
                negatedFormula, 
                relevantPropositions: relevantProps
            )
        } catch {
            throw LTLModelCheckerError.internalProcessingError("LTL to Büchi translation failed: \(error.localizedDescription)")
        }

        let automatonForModel: BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol>
        do {
            automatonForModel = try self.convertModelToBuchi(model)
        } catch {
            throw LTLModelCheckerError.internalProcessingError("Model to Büchi automaton conversion failed: \(error.localizedDescription)")
        }

        // Type alignment for constructProductAutomaton
        let castedAutomatonForNegatedFormula = BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol>(
            states: automatonForNegatedFormula.states,
            alphabet: automatonForNegatedFormula.alphabet, 
            initialStates: automatonForNegatedFormula.initialStates,
            transitions: Set(automatonForNegatedFormula.transitions.map { t in 
                BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol>.Transition(from: t.sourceState, on: t.symbol, to: t.destinationState)
            }),
            acceptingStates: automatonForNegatedFormula.acceptingStates
        )

        let productAut: BuchiAutomaton<ActualProductAutomatonState, BuchiAlphabetSymbol>
        do {
            productAut = try self.constructProductAutomaton(modelAutomaton: automatonForModel, formulaAutomaton: castedAutomatonForNegatedFormula)
        } catch {
            throw LTLModelCheckerError.internalProcessingError("Product automaton construction failed: \(error.localizedDescription)")
        }
        
        // Call the static method from NestedDFSAlgorithm
        if let acceptingRun = try NestedDFSAlgorithm.findAcceptingRun(in: productAut) {
            let (prefixModelStates, cycleModelStates) = self.projectRunToModelStates(acceptingRun,
                                                                                      model: model)
            return .fails(counterexample: Counterexample(prefix: prefixModelStates, cycle: cycleModelStates))
        } else {
            return .holds
        }
    }

    // --- Placeholder private helper methods for the core algorithms --- 
    // These would contain the actual complex logic.

    private func extractPropositions<P: TemporalProposition>(from formula: LTLFormula<P>, and model: Model) -> Set<Model.AtomicPropositionIdentifier> where P.Value == Bool {
        var propositions = Set<Model.AtomicPropositionIdentifier>()
        
        func collectProps(from f: LTLFormula<P>) {
            switch f {
            case .booleanLiteral:
                // Boolean literals do not contain propositions
                break
            case .atomic(let p):
                if let propId = p.id as? Model.AtomicPropositionIdentifier {
                     propositions.insert(propId)
                } else {
                    // This warning is important if KripkeStructure.AtomicPropositionIdentifier
                    // is not always directly compatible with P.ID (TemporalProposition.ID)
                    print("Warning: Proposition ID \(p.id) of type \(type(of: p.id)) could not be cast to Model.AtomicPropositionIdentifier")
                }
            case .not(let subFormula):
                collectProps(from: subFormula)
            case .next(let subFormula): // Corrected from .X
                collectProps(from: subFormula)
            case .eventually(let subFormula): // Corrected from .F
                collectProps(from: subFormula)
            case .globally(let subFormula): // Corrected from .G
                collectProps(from: subFormula)
            case .and(let left, let right):
                collectProps(from: left)
                collectProps(from: right)
            case .or(let left, let right):
                collectProps(from: left)
                collectProps(from: right)
            case .implies(let left, let right):
                collectProps(from: left)
                collectProps(from: right)
            case .until(let left, let right): // Added case
                collectProps(from: left)
                collectProps(from: right)
            case .weakUntil(let left, let right): // Added case
                collectProps(from: left)
                collectProps(from: right)
            case .release(let left, let right): // Added case
                collectProps(from: left)
                collectProps(from: right)
            // No default needed if all LTLFormula cases are explicitly handled.
            // If LTLFormula might have more cases in the future not covered here, 
            // a default with a warning/error would be good practice.
            }
        }
        collectProps(from: formula)
        
        print("LTLModelChecker Helper: extractPropositions - Updated with LTLFormula.swift cases.")
        return propositions
    }

    /// Converts a KripkeStructure (system model) into an equivalent Büchi Automaton.
    /// The resulting automaton accepts all behaviors of the Kripke structure.
    /// Typically, all states in this automaton are accepting states.
    private func convertModelToBuchi(
        _ model: Model
    ) throws -> BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol> {
        let allModelStates = model.allStates
        var transitions = Set<BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol>.Transition>()
        var alphabet = Set<BuchiAlphabetSymbol>()

        for sourceState in allModelStates {
            let successors = model.successors(of: sourceState)
            if successors.isEmpty {
                // If a state has no successors in the model, it implies a deadlock or end of a finite path.
                // For LTL model checking over infinite paths, this often means such a path cannot satisfy
                // liveness properties. How to handle this depends on the precise semantics desired.
                // One common approach for explicit model checkers is to add a self-loop on such states,
                // labeled with the propositions true in that state.
                let truePropositionsInState = model.atomicPropositionsTrue(in: sourceState)
                alphabet.insert(truePropositionsInState)
                let transition = BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol>.Transition(
                    from: sourceState, on: truePropositionsInState, to: sourceState
                )
                transitions.insert(transition)
            } else {
                for destinationState in successors {
                    // The "symbol" for this transition in the Büchi automaton is the set of atomic propositions
                    // true in the *sourceState* from which the transition originates.
                    // This is because LTL formulas are evaluated over states, and the propositions
                    // define the labeling of the source state.
                    let truePropositionsInSourceState = model.atomicPropositionsTrue(in: sourceState)
                    alphabet.insert(truePropositionsInSourceState)

                    let transition = BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol>.Transition(
                        from: sourceState, on: truePropositionsInSourceState, to: destinationState
                    )
                    transitions.insert(transition)
                }
            }
        }

        // All states of the model are considered accepting states in its Büchi automaton representation.
        let acceptingStates = allModelStates
        let initialStates = model.initialStates

        // Ensure all initial states are part of allStates (basic validation)
        guard initialStates.isSubset(of: allModelStates) else {
            throw LTLModelCheckerError.internalProcessingError("Initial states of the model are not a subset of all model states.")
        }
        // Ensure all states in transitions are known (covered by iterating allModelStates for sources)
        // and that successors are also within allModelStates (implicitly assumed by KripkeStructure design)

        return BuchiAutomaton(
            states: allModelStates,
            alphabet: alphabet, // The alphabet is formed by all unique sets of propositions encountered.
            initialStates: initialStates,
            transitions: transitions,
            acceptingStates: acceptingStates
        )
    }

    /// Constructs the product of two Büchi automata: one from the system model (Am) and one from the LTL formula (A¬φ).
    /// The product automaton Am × A¬φ accepts runs that are in both Am and A¬φ.
    private func constructProductAutomaton(
        modelAutomaton: BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol>,
        formulaAutomaton: BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol>
    ) throws -> BuchiAutomaton<ActualProductAutomatonState, BuchiAlphabetSymbol> {
        
        var productStates = Set<ActualProductAutomatonState>()
        var productInitialStates = Set<ActualProductAutomatonState>()
        var productTransitions = Set<BuchiAutomaton<ActualProductAutomatonState, BuchiAlphabetSymbol>.Transition>()
        var productAcceptingStates = Set<ActualProductAutomatonState>()
        
        // The alphabet of the product automaton is the intersection of the alphabets of the two input automata.
        // However, in LTL model checking, they are typically constructed over the same effective alphabet
        // derived from all relevant atomic propositions. If not, an error or refinement is needed.
        // For simplicity, we assume they operate on compatible alphabets, and the symbols in transitions
        // will guide the product. The productAutomaton's alphabet will be built from symbols found in valid product transitions.
        var productAlphabet = Set<BuchiAlphabetSymbol>()

        // 1. Generate all product states and identify initial product states
        for mState in modelAutomaton.states {
            for fState in formulaAutomaton.states {
                let pState = ActualProductAutomatonState(mState, fState)
                productStates.insert(pState)
                
                if modelAutomaton.initialStates.contains(mState) && formulaAutomaton.initialStates.contains(fState) {
                    productInitialStates.insert(pState)
                }
            }
        }
        
        // 2. Construct product transitions and determine product accepting states
        // This requires iterating through all combinations of transitions.
        // For better performance, pre-processing transitions into a lookup (e.g., [SourceState: [Symbol: Set<DestState>]]) is advisable.
        for pSourceState in productStates {
            // Find transitions from modelAutomaton originating from pSourceState.s1
            for mTrans in modelAutomaton.transitions where mTrans.sourceState == pSourceState.s1 {
                // Find transitions from formulaAutomaton originating from pSourceState.s2 and on the same symbol
                for fTrans in formulaAutomaton.transitions where fTrans.sourceState == pSourceState.s2 && fTrans.symbol == mTrans.symbol {
                    
                    let pDestinationState = ActualProductAutomatonState(mTrans.destinationState, fTrans.destinationState)
                    
                    // Ensure the destination state is actually part of our generated productStates
                    // (it should be, if model/formula automata states are comprehensive)
                    guard productStates.contains(pDestinationState) else {
                        // This might indicate an issue if states were not exhaustively pre-calculated, or if a state referenced in a transition isn't in the automaton's state set.
                        print("Warning: Product destination state \(pDestinationState) not found in pre-calculated product states. This could indicate incomplete state space exploration or an invalid automaton.")
                        // Depending on strictness, one might throw an error here or simply not add the transition.
                        // For now, we assume valid input automata where all referenced states exist.
                        continue
                    }

                    let productTransition = BuchiAutomaton<ActualProductAutomatonState, BuchiAlphabetSymbol>.Transition(
                        from: pSourceState,
                        on: mTrans.symbol, // Symbol is the same for both
                        to: pDestinationState
                    )
                    productTransitions.insert(productTransition)
                    productAlphabet.insert(mTrans.symbol) // Add symbol to product alphabet
                }
            }
        }

        // 3. Determine product accepting states
        // A product state (s_m, s_f) is accepting if s_f is an accepting state in the formulaAutomaton (A¬φ).
        // This assumes the modelAutomaton (Am) has all its states as accepting, which is standard.
        for pState in productStates {
            if formulaAutomaton.acceptingStates.contains(pState.s2) {
                productAcceptingStates.insert(pState)
            }
        }
        
        // Basic validation for the constructed automaton
        if productInitialStates.isEmpty && !productStates.isEmpty {
           print("Warning: Product automaton has states but no initial states. This might be correct if one of the input automata had no initial states or no overlapping initial behavior.")
           // Depending on the LTL to Büchi tool, an LTL formula might result in an automaton with no initial states if it's a contradiction like (false).
        }

        return BuchiAutomaton(
            states: productStates,
            alphabet: productAlphabet,
            initialStates: productInitialStates,
            transitions: productTransitions,
            acceptingStates: productAcceptingStates
        )
    }

    private func projectRunToModelStates(
        _ productRun: (prefix: [ActualProductAutomatonState], cycle: [ActualProductAutomatonState]),
        model: Model
    ) -> (prefix: [Model.State], cycle: [Model.State]) {
        print("LTLModelChecker Helper: projectRunToModelStates - Structure correct.")
        let prefixModelStates = productRun.prefix.map { $0.s1 }
        let cycleModelStates = productRun.cycle.map { $0.s1 }
        return (prefixModelStates, cycleModelStates)
    }
}

/// Defines errors that can be thrown by the `LTLModelChecker`.
public enum LTLModelCheckerError: Error, LocalizedError {
    /// Indicates that one or more core model checking algorithms are not yet implemented.
    case algorithmsNotImplemented(String)
    
    /// Placeholder for other potential errors, e.g., issues during automaton construction,
    /// inconsistencies in the model, or unsupported LTL formula constructs.
    case internalProcessingError(String)

    public var errorDescription: String? {
        switch self {
        case .algorithmsNotImplemented(let message):
            return "LTLModelChecker Error: Algorithms Not Implemented. Culprit: \(message)"
        case .internalProcessingError(let message):
            return "LTLModelChecker Error: Internal Processing Failed. Details: \(message)"
        }
    }
} 
