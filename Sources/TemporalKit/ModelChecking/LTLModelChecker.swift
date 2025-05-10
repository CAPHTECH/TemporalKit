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
    public typealias ModelAutomatonState = Model.State
    public typealias BuchiAlphabetSymbol = Set<Model.AtomicPropositionIdentifier>
    typealias FormulaAutomatonState = Int // Changed back to internal
    typealias ActualProductAutomatonState = ProductState<ModelAutomatonState, FormulaAutomatonState> // Changed to internal

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

        // --- SPECIAL HANDLING FOR ATOMIC PROPOSITIONS ---
        switch formula {
        case .atomic(let prop):
            if model.initialStates.isEmpty { return .holds }
            for initialState in model.initialStates {
                if !(model.atomicPropositionsTrue(in: initialState).contains(prop.id)) { 
                    return .fails(counterexample: Counterexample(prefix: [initialState], cycle: [])) 
                }
            }
            return .holds
        case .not(let subFormula):
            if case .atomic(let prop) = subFormula {
                if model.initialStates.isEmpty { return .fails(counterexample: Counterexample(prefix: [], cycle: [])) }
                var anyInitialSatisfiesNotP = false
                for initialState in model.initialStates {
                    if !(model.atomicPropositionsTrue(in: initialState).contains(prop.id)) {
                        anyInitialSatisfiesNotP = true
                        break 
                    }
                }
                return anyInitialSatisfiesNotP ? .holds : .fails(counterexample: Counterexample(prefix: model.initialStates.isEmpty ? [] : [model.initialStates.first!], cycle: [])) 
            }
        default:
            break 
        }
        // --- END SPECIAL HANDLING ---
        
        // Collect all proposition identifiers from the model and formula
        var allRelevantAPIDs = Set<Model.AtomicPropositionIdentifier>()
        for state in model.allStates {
            allRelevantAPIDs.formUnion(model.atomicPropositionsTrue(in: state))
        }
        // TODO: Add propositions from the formula to allRelevantAPIDs if not already covered
        // let formulaAPIDs = formula.propositions.map { $0.id } // Needs LTLFormula.propositions API
        // allRelevantAPIDs.formUnion(formulaAPIDs)

        // --- Original model checking logic --- 
        let negatedFormula = LTLFormula.not(formula) // Negate the formula for counterexample search

        let modelAutomaton = try self.convertModelToBuchi(model: model, relevantPropositions: allRelevantAPIDs)
        
        // Assuming LTLToBuchiConverter has a static method translateLTLToBuchi
        // The LTLFormula<P> needs to be passed here.
        let formulaAutomatonForNegated = try LTLToBuchiConverter.translateLTLToBuchi(negatedFormula, relevantPropositions: allRelevantAPIDs)

        let productAutomaton = try constructProductAutomaton(modelAutomaton: modelAutomaton, formulaAutomaton: formulaAutomatonForNegated)

        // Assuming NestedDFSAlgorithm has a static method findAcceptingRun
        if let acceptingRun = try NestedDFSAlgorithm.findAcceptingRun(in: productAutomaton) {
            let (prefix, cycle) = self.projectRunToModelStates(productRun: acceptingRun, model: model)
            return .fails(counterexample: Counterexample(prefix: prefix, cycle: cycle))
        } else {
            return .holds // No counterexample found means the original formula holds
        }
    }

    // --- Placeholder private helper methods for the core algorithms --- 
    // These would contain the actual complex logic.

    private func extractPropositions<P: TemporalProposition>(from formula: LTLFormula<P>, and model: Model) -> Set<Model.AtomicPropositionIdentifier> where P.Value == Bool {
        var propositionsInFormula = Set<Model.AtomicPropositionIdentifier>()
        
        func collectProps(from f: LTLFormula<P>) {
            switch f {
            case .booleanLiteral:
                break
            case .atomic(let p):
                if let propId = p.id as? Model.AtomicPropositionIdentifier {
                     propositionsInFormula.insert(propId)
                } else {
                    print("Warning: Proposition ID \(p.id) of type \(type(of: p.id)) could not be cast to Model.AtomicPropositionIdentifier")
                }
            case .not(let subFormula):
                collectProps(from: subFormula)
            case .next(let subFormula): 
                collectProps(from: subFormula)
            case .eventually(let subFormula): 
                collectProps(from: subFormula)
            case .globally(let subFormula): 
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
            case .until(let left, let right): 
                collectProps(from: left)
                collectProps(from: right)
            case .weakUntil(let left, let right): 
                collectProps(from: left)
                collectProps(from: right)
            case .release(let left, let right): 
                collectProps(from: left)
                collectProps(from: right)
            }
        }
        collectProps(from: formula)
        
        // Ensure the formula automaton considers all propositions present in the model,
        // so its alphabet is compatible for product construction.
        var allPropsEverTrueInModel = Set<Model.AtomicPropositionIdentifier>()
        for state in model.allStates {
            allPropsEverTrueInModel.formUnion(model.atomicPropositionsTrue(in: state))
        }
        propositionsInFormula.formUnion(allPropsEverTrueInModel)
        
        // print("LTLModelChecker Helper: extractPropositions - Updated with LTLFormula.swift cases.") // Original print
        print("LTLModelChecker Helper: extractPropositions - Formula Props: \(propositionsInFormula), Model Props Considered: \(allPropsEverTrueInModel)")
        return propositionsInFormula
    }

    /// Converts a KripkeStructure (system model) into an equivalent Büchi Automaton.
    /// The resulting automaton accepts all behaviors of the Kripke structure.
    /// Typically, all states in this automaton are accepting states.
    private func convertModelToBuchi(
        model: Model,
        relevantPropositions: Set<Model.AtomicPropositionIdentifier> 
    ) throws -> BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol> {
        let allModelStates = model.allStates
        var transitions = Set<BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol>.Transition>()
        var alphabet = Set<BuchiAlphabetSymbol>()
        alphabet.insert(Set()) 

        for sourceState in allModelStates {
            let truePropositionsInSourceState = model.atomicPropositionsTrue(in: sourceState)
            alphabet.insert(truePropositionsInSourceState)
            
            let successors = model.successors(of: sourceState)
            if successors.isEmpty {
                transitions.insert(.init(
                    from: sourceState, on: truePropositionsInSourceState, to: sourceState
                ))
            } else {
                for destinationState in successors {
                    transitions.insert(.init(
                        from: sourceState, on: truePropositionsInSourceState, to: destinationState
                    ))
                }
            }
        }
        let initialStates = model.initialStates
        guard initialStates.isSubset(of: allModelStates) else {
            throw LTLModelCheckerError.internalProcessingError("Initial states of the model are not a subset of all model states.")
        }
        return BuchiAutomaton(
            states: allModelStates,
            alphabet: alphabet, 
            initialStates: initialStates,
            transitions: transitions,
            acceptingStates: allModelStates 
        )
    }

    /// Constructs the product of two Büchi automata: one from the system model (Am) and one from the LTL formula (A¬φ).
    /// The product automaton Am × A¬φ accepts runs that are in both Am and A¬φ.
    private func constructProductAutomaton(
        modelAutomaton: BuchiAutomaton<ModelAutomatonState, BuchiAlphabetSymbol>,
        formulaAutomaton: BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol> 
    ) throws -> BuchiAutomaton<ActualProductAutomatonState, BuchiAlphabetSymbol> {
        
        // ---- REMOVED ProductConstruct LOGS ----
        // print("[ProductConstruct] Model Automaton: States=\(modelAutomaton.states.count), Initial=\(modelAutomaton.initialStates.count), Accepting=\(modelAutomaton.acceptingStates.count), Alphabet=\(modelAutomaton.alphabet.count)")
        // print("[ProductConstruct] Formula Automaton: States=\(formulaAutomaton.states.count), Initial=\(formulaAutomaton.initialStates.count), Accepting=\(formulaAutomaton.acceptingStates.count), Alphabet=\(formulaAutomaton.alphabet.count)")

        // ---- REMOVED ProductConstruct-Debug F(!p) LOGS ----
        
        var productStates = Set<ActualProductAutomatonState>()
        var productInitialStates = Set<ActualProductAutomatonState>()
        var productTransitions = Set<BuchiAutomaton<ActualProductAutomatonState, BuchiAlphabetSymbol>.Transition>()
        var productAcceptingStates = Set<ActualProductAutomatonState>()

        for s1_init in modelAutomaton.initialStates {
            for s2_init in formulaAutomaton.initialStates {
                let productInitialState = ProductState(s1_init, s2_init) 
                productInitialStates.insert(productInitialState)
                productStates.insert(productInitialState)
            }
        }

        var worklist = Array(productInitialStates)
        var visited = Set<ActualProductAutomatonState>()

        while let currentProductState = worklist.popLast() {
            if visited.contains(currentProductState) { continue }
            visited.insert(currentProductState)

            if formulaAutomaton.acceptingStates.contains(currentProductState.s2) {
                productAcceptingStates.insert(currentProductState)
            }

            for modelTrans in modelAutomaton.transitions where modelTrans.sourceState == currentProductState.s1 {
                for formulaTrans in formulaAutomaton.transitions where formulaTrans.sourceState == currentProductState.s2 {
                    if modelTrans.symbol == formulaTrans.symbol {
                        let nextProductState = ProductState(modelTrans.destinationState, formulaTrans.destinationState)
                        productStates.insert(nextProductState)
                        productTransitions.insert(.init(from: currentProductState, on: modelTrans.symbol, to: nextProductState))
                        if !visited.contains(nextProductState) && !worklist.contains(nextProductState) {
                            worklist.append(nextProductState)
                        }
                    }
                }
            }
        }
        
        productInitialStates.forEach { productStates.insert($0) }
        productAcceptingStates.forEach { productStates.insert($0) }
        for t in productTransitions {
            productStates.insert(t.sourceState)
            productStates.insert(t.destinationState)
        }

        return BuchiAutomaton(
            states: productStates,
            alphabet: modelAutomaton.alphabet.union(formulaAutomaton.alphabet), 
            initialStates: productInitialStates,
            transitions: productTransitions,
            acceptingStates: productAcceptingStates
        )
    }

    private func projectRunToModelStates(
        productRun: (prefix: [ActualProductAutomatonState], cycle: [ActualProductAutomatonState]),
        model: Model 
    ) -> (prefix: [Model.State], cycle: [Model.State]) {
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
