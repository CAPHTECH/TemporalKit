import Testing
@testable import TemporalKit

// Define a dummy state type for ClosureTemporalProposition in tests
private struct DummyTestState {}

// Type alias for the proposition type used in these tests
private typealias OurProposition = ClosureTemporalProposition<DummyTestState, Bool>

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
        let pId = PropositionID(rawValue: pIdString)!
        let pFormula = Formula.prop(pIdString)
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            pFormula,
            relevantPropositions: relevantPropositions
        )

        #expect(!buchiAutomaton.states.isEmpty, "BA should have states.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA should have initial states.")
        #expect(!buchiAutomaton.acceptingStates.isEmpty, "BA should have accepting states.")

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
        let pId = PropositionID(rawValue: pIdString)!
        let f_pFormula: Formula = .eventually(Formula.prop(pIdString))
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            f_pFormula,
            relevantPropositions: relevantPropositions
        )

        #expect(!buchiAutomaton.states.isEmpty, "BA should have states for F p.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA should have initial states for F p.")
        #expect(!buchiAutomaton.acceptingStates.isEmpty, "BA should have accepting states for F p.")

        let initialStates = buchiAutomaton.initialStates
        #expect(initialStates.count == 1, "Expected one initial state for F p")
        let s0 = try #require(initialStates.first)

        #expect(
            !(buchiAutomaton.acceptingStates).contains(s0),
            "Initial state for F p should typically not be accepting."
        )
    }

    @Test func testGlobally_p() throws {
        let pIdString = "p"
        let pId = PropositionID(rawValue: pIdString)!
        let g_pFormula: Formula = .globally(Formula.prop(pIdString))
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            g_pFormula,
            relevantPropositions: relevantPropositions
        )

        #expect(!buchiAutomaton.states.isEmpty, "BA for F(¬p) (from G p) should have states.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA for F(¬p) should have initial states.")
        _ = try #require(buchiAutomaton.initialStates.first, "Should have one initial state for F(¬p)")
    }

    @Test func testX_p() throws {
        let pIdString = "p"
        let pId = PropositionID(rawValue: pIdString)!
        let x_pFormula: Formula = .next(Formula.prop(pIdString))
        let relevantPropositions: Set<PropositionID> = [pId]

        let buchiAutomaton: BA = try LTLToBuchiConverter.translateLTLToBuchi(
            x_pFormula,
            relevantPropositions: relevantPropositions
        )

        #expect(!buchiAutomaton.states.isEmpty, "BA should have states for X p.")
        #expect(!buchiAutomaton.initialStates.isEmpty, "BA should have initial states for X p.")

        let initial_state_for_Xp_log = buchiAutomaton.initialStates.first
        let initial_state_is_present = initial_state_for_Xp_log != nil
        #expect(initial_state_is_present, "Initial state should be present for Xp automaton (A_X(¬p)).")
        if let initState = initial_state_for_Xp_log {
            let isAccepting = buchiAutomaton.acceptingStates.contains(initState)
            #expect(isAccepting, "Initial state for A_X(¬p) (from ¬(X p)) should be accepting with current k=0 GBA->BA logic.")
        } else {
            Issue.record("Initial state was nil, cannot check if it's accepting.")
        }
    }
}

// Note: More complex assertions will require comparing the generated automaton's language
// or structure to a known correct automaton. This often involves checking for specific paths
// and ensuring reachability of accepting states under certain input sequences.
// For now, basic structural checks and printing are a starting point. 
