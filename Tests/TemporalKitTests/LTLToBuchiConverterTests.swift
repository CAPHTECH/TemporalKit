import Testing
@testable import TemporalKit

// Define a dummy state type for ClosureTemporalProposition in tests
fileprivate struct DummyTestState {}

// Type alias for the proposition type used in these tests
fileprivate typealias OurProposition = ClosureTemporalProposition<DummyTestState, Bool>

// Helper to create LTL formulas from common patterns for conciseness in tests
fileprivate extension LTLFormula where P == OurProposition {
    static func prop(_ id: String) -> LTLFormula<OurProposition> {
        let proposition: OurProposition = TemporalKit.makeProposition(
            id: id,
            name: id, // name can be same as id for test purposes
            evaluate: { (_: DummyTestState) -> Bool in false } // Dummy evaluation
        )
        return .atomic(proposition)
    }

    static var `true`: LTLFormula<OurProposition> { LTLFormula<OurProposition>.booleanLiteral(true) }
    static var `false`: LTLFormula<OurProposition> { LTLFormula<OurProposition>.booleanLiteral(false) }
}

// Using a struct for the test suite with Swift Testing
struct LTLToBuchiConverterTests {

    // Type aliases for convenience in tests
    fileprivate typealias Formula = LTLFormula<OurProposition>
    typealias BuchiState = Int // Assuming FormulaAutomatonState is Int as used in LTLToBuchiConverter
    typealias BuchiSymbol = Set<PropositionID> // Alphabet symbols are sets of true proposition IDs
    typealias BA = BuchiAutomaton<BuchiState, BuchiSymbol>
    typealias BATransition = BA.Transition

    // relevantPropositions will be defined locally within each test function

    // --- Test Cases ---
    @Test func atomicProposition_p() throws {
        let pIdString = "p"
        let pId = PropositionID(rawValue: pIdString)
        let pFormula: Formula = Formula.prop(pIdString)
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            pFormula,
            relevantPropositions: relevantPropositions
        )

        #expect(!buchiAutomaton.states.isEmpty, "BA should have states.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA should have initial states.")
        #expect(!buchiAutomaton.acceptingStates.isEmpty, "BA should have accepting states.")
        
        print("--- Test: Atomic Proposition 'p' ---")
        LTLToBuchiConverterTests.printBA(buchiAutomaton, testName: "atomicProposition_p", relevantPropositions: relevantPropositions)
        
        #expect(buchiAutomaton.states.count == 1, "Expected 1 state for simple 'p' based on typical minimal BA.")
        let initialState = try #require(buchiAutomaton.initialStates.first, "Should have one initial state")
        #expect(buchiAutomaton.acceptingStates.contains(initialState), "Initial state should be accepting for 'p'")

        let pSymbol: BuchiSymbol = [pId]
        let notPSymbol: BuchiSymbol = [] // Empty set for !p

        let transitionsOnP = buchiAutomaton.transitions.filter { $0.sourceState == initialState && $0.symbol == pSymbol }
        #expect(transitionsOnP.count == 1, "Should be one transition on 'p' from initial state")
        #expect(transitionsOnP.first?.destinationState == initialState, "Transition on 'p' should loop to initial state")

        let transitionsOnNotP = buchiAutomaton.transitions.filter { $0.sourceState == initialState && $0.symbol == notPSymbol }
        #expect(transitionsOnNotP.isEmpty, "Should be no transition on '!p' from initial state for atomic(p) if path is inconsistent.")
    }
    
    @Test func eventually_p() throws {
        let pIdString = "p"
        let pId = PropositionID(rawValue: pIdString)
        let f_pFormula: Formula = .eventually(Formula.prop(pIdString))
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            f_pFormula,
            relevantPropositions: relevantPropositions
        )
        
        print("--- Test: Eventually 'p' ---")
        LTLToBuchiConverterTests.printBA(buchiAutomaton, testName: "eventually_p", relevantPropositions: relevantPropositions)

        #expect(!buchiAutomaton.states.isEmpty, "BA should have states for F p.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA should have initial states for F p.")
        #expect(!buchiAutomaton.acceptingStates.isEmpty, "BA should have accepting states for F p.")

        let initialStates = buchiAutomaton.initialStates
        #expect(initialStates.count == 1, "Expected one initial state for F p")
        let s0 = try #require(initialStates.first)
        
        #expect(!buchiAutomaton.acceptingStates.contains(s0), "Initial state for F p should typically not be accepting.")

        let pSymbol: BuchiSymbol = [pId]
        let notPSymbol: BuchiSymbol = []

        let s0_on_notP_transitions = buchiAutomaton.transitions.filter { $0.sourceState == s0 && $0.symbol == notPSymbol }
        #expect(!s0_on_notP_transitions.isEmpty, "Must have a transition from s0 on !p")
        _ = try #require(s0_on_notP_transitions.first?.destinationState)

        let s0_on_P_transitions = buchiAutomaton.transitions.filter { $0.sourceState == s0 && $0.symbol == pSymbol }
        #expect(!s0_on_P_transitions.isEmpty, "Should be at least one transition from s0 on p")
        
        // Find a transition that leads to an accepting state
        let s1_optional = s0_on_P_transitions.first(where: { buchiAutomaton.acceptingStates.contains($0.destinationState) })?.destinationState
        let s1 = try #require(s1_optional, "Should find a transition from s0 on p to an accepting state")
        #expect(buchiAutomaton.acceptingStates.contains(s1), "State s1, reached from s0 on p, must be an accepting state")

        let s1_on_P_transitions = buchiAutomaton.transitions.filter { $0.sourceState == s1 && $0.symbol == pSymbol }
        #expect(!s1_on_P_transitions.isEmpty, "Accepting state s1 should have a transition on p (could be a loop)")
        
        // DEBUG: Log transitions and symbols before filtering for s1_on_notP_transitions
        print("DEBUG eventually_p: s1 (supposedly accepting state ID) = \(s1)")
        print("DEBUG eventually_p: notPSymbol = \(notPSymbol)")
        print("DEBUG eventually_p: All BA transitions:")
        for t in buchiAutomaton.transitions {
            print("  Transition: from=\(t.sourceState), on=\(t.symbol.map{$0.rawValue}), to=\(t.destinationState)")
        }

        let s1_on_notP_transitions = buchiAutomaton.transitions.filter { $0.sourceState == s1 && $0.symbol == notPSymbol }
        #expect(!s1_on_notP_transitions.isEmpty, "Accepting state s1 should have a transition on !p (could be a loop)")
    }

    @Test func testGlobally_p() throws {
        let pIdString = "p"
        let pId = PropositionID(rawValue: pIdString)
        let g_pFormula: Formula = .globally(Formula.prop(pIdString))
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            g_pFormula,
            relevantPropositions: relevantPropositions
        )

        print("--- Test: Globally 'p' ---")
        LTLToBuchiConverterTests.printBA(buchiAutomaton, testName: "testGlobally_p", relevantPropositions: relevantPropositions)

        #expect(!buchiAutomaton.states.isEmpty, "BA should have states for G p.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA should have initial states for G p.")
        #expect(!buchiAutomaton.acceptingStates.isEmpty, "BA should have accepting states for G p.")

        let initialState = try #require(buchiAutomaton.initialStates.first, "Should have one initial state for G p")
        #expect(buchiAutomaton.acceptingStates.contains(initialState), "Initial state for G p should be accepting.")

        let pSymbol: BuchiSymbol = [pId]
        let notPSymbol: BuchiSymbol = [] // Represents !p when p is the only relevant proposition

        // From initial (accepting) state, on 'p', should loop to itself or another accepting state maintaining G p.
        let transitionsOnP = buchiAutomaton.transitions.filter { $0.sourceState == initialState && $0.symbol == pSymbol }
        #expect(transitionsOnP.count == 1, "For G p, on 'p', should be one transition from initial state (likely a loop).")
        let nextStateOnP = try #require(transitionsOnP.first?.destinationState)
        #expect(buchiAutomaton.acceptingStates.contains(nextStateOnP), "For G p, state reached on 'p' should be accepting.")
        // Ideally, nextStateOnP == initialState for a simple G p automaton.
        // #expect(nextStateOnP == initialState, "For G p, transition on 'p' should loop to the initial state.") // Temporarily commented out, as a 2-state BA is also possible and correct.

        // From initial (accepting) state, on '!p', there should be no transition to an accepting state.
        // Ideally, it goes to a non-accepting trap state, or there's no transition for '!p' at all from an accepting state.
        let transitionsOnNotP = buchiAutomaton.transitions.filter { $0.sourceState == initialState && $0.symbol == notPSymbol }
        if let trapDestination = transitionsOnNotP.first?.destinationState {
            #expect(!buchiAutomaton.acceptingStates.contains(trapDestination), "For G p, if a transition on '!p' exists from an accepting state, it must go to a non-accepting state.")
        } else {
            // No transition on !p is also acceptable, meaning the path implicitly fails.
            #expect(transitionsOnNotP.isEmpty, "For G p, ideally no transition on '!p' from an accepting state, or it goes to a trap. Here, checking for empty.")
        }
    }

    @Test func testX_p() throws {
        let pIdString = "p"
        let pId = PropositionID(rawValue: pIdString)
        let x_pFormula: Formula = .next(Formula.prop(pIdString))
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            x_pFormula,
            relevantPropositions: relevantPropositions
        )

        print("--- Test: Next 'p' (X p) ---")
        LTLToBuchiConverterTests.printBA(buchiAutomaton, testName: "testX_p", relevantPropositions: relevantPropositions)

        #expect(!buchiAutomaton.states.isEmpty, "BA should have states for X p.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA should have initial states for X p.")
        // For X p, accepting states might depend on the tableau construction details and GBA default acceptance.
        // We will verify specific path properties instead of just non-empty accepting states initially.

        let initialState = try #require(buchiAutomaton.initialStates.first, "Should have one initial state for X p")
        #expect(!buchiAutomaton.acceptingStates.contains(initialState), "Initial state for X p should generally be non-accepting.")

        let pSymbol: BuchiSymbol = [pId]
        let notPSymbol: BuchiSymbol = []

        // From initial state, on ANY symbol, should transition to a state where 'p' is expected next.
        let transitionsFromInitialOnP = buchiAutomaton.transitions.filter { $0.sourceState == initialState && $0.symbol == pSymbol }
        #expect(!transitionsFromInitialOnP.isEmpty, "Should be a transition from initial state on 'p' for X p.")
        let s1_viaP = try #require(transitionsFromInitialOnP.first?.destinationState, "Must have a successor from initial on p")

        let transitionsFromInitialOnNotP = buchiAutomaton.transitions.filter { $0.sourceState == initialState && $0.symbol == notPSymbol }
        #expect(!transitionsFromInitialOnNotP.isEmpty, "Should be a transition from initial state on '!p' for X p.")
        _ = try #require(transitionsFromInitialOnNotP.first?.destinationState, "Must have a successor from initial on !p")
        
        // For a simple X p, both paths should lead to the same intermediate state or equivalent states.
        // This intermediate state s1 is where the 'p' from Xp is actually checked.
        // We will check paths from s1_viaP (assuming s1_viaNotP behaves similarly or leads to same state if BA is minimal)

        // From s1 (reached via initial on P), on 'p', should lead to an accepting cycle/state.
        let s1_on_P_transitions = buchiAutomaton.transitions.filter { $0.sourceState == s1_viaP && $0.symbol == pSymbol }
        #expect(!s1_on_P_transitions.isEmpty, "Intermediate state s1 should have transition on 'p' for X p.")
        let s2_acceptingPath = try #require(s1_on_P_transitions.first?.destinationState, "s1 must have successor on p")
        // This s2 (or a state reachable from it forming a cycle) should be part of an accepting run.
        // This requires checking if s2 is an accepting state OR can lead to one that loops.
        // For Xp, if GBA default acceptance makes all states accepting, this will pass if a transition exists.
        // A more precise check: s2 must be an accepting state if Xp simply means "next state satisfies p and then we are done (accept)".
        #expect(buchiAutomaton.acceptingStates.contains(s2_acceptingPath), "State s2 (after X and p) should be accepting for X p, assuming default GBA acceptance or simple tableau.")

        // From s1 (reached via initial on P), on '!p', should NOT lead to an accepting state/cycle for p.
        let s1_on_NotP_transitions = buchiAutomaton.transitions.filter { $0.sourceState == s1_viaP && $0.symbol == notPSymbol }
        if let s2_nonAcceptingPath_dest = s1_on_NotP_transitions.first?.destinationState {
            #expect(!buchiAutomaton.acceptingStates.contains(s2_nonAcceptingPath_dest), "If s1 has transition on '!p', it should go to non-accepting state for X p.")
        } else {
            // No transition on !p from s1 is also fine (implicitly rejected).
            #expect(s1_on_NotP_transitions.isEmpty, "Intermediate state s1 for X p ideally has no transition on '!p', or it goes to a non-accepting state.")
        }
    }

    // --- Helper to print BA for debugging ---
    static func printBA(_ ba: BA, testName: String, relevantPropositions: Set<PropositionID>) {
        print("Büchi Automaton for test: \(testName)")
        print("  Relevant Propositions (IDs): \(relevantPropositions.map { $0.rawValue }.sorted())")
        print("  States: \(ba.states.sorted())")
        let alphabet = LTLToBuchiConverter.generatePossibleAlphabetSymbols(relevantPropositions)
        print("  Alphabet (Size: \(alphabet.count)): \(alphabet.map { innerSet in innerSet.map { $0.rawValue } })") // Map inner set to String for printing
        print("  Initial States: \(ba.initialStates.sorted())")
        print("  Accepting States: \(ba.acceptingStates.sorted())")
        print("  Transitions (")
        let sortedTransitions = ba.transitions.sorted { (t1, t2) -> Bool in
            if t1.sourceState != t2.sourceState { return t1.sourceState < t2.sourceState }
            // Need a stable way to compare Set<PropositionID> for sorting symbols
            let t1SymbolString = t1.symbol.map { $0.rawValue }.sorted().joined(separator: ",")
            let t2SymbolString = t2.symbol.map { $0.rawValue }.sorted().joined(separator: ",")
            if t1SymbolString != t2SymbolString { return t1SymbolString < t2SymbolString }
            return t1.destinationState < t2.destinationState
        }
        for t in sortedTransitions {
            print("    \(t.sourceState) --\(t.symbol.isEmpty ? "{empty}" : "\(t.symbol.map { $0.rawValue })")--> \(t.destinationState)")
        }
        print("  )")
        print("------------------------------------")
    }
}

// Note: More complex assertions will require comparing the generated automaton's language
// or structure to a known correct automaton. This often involves checking for specific paths
// and ensuring reachability of accepting states under certain input sequences.
// For now, basic structural checks and printing are a starting point. 
