import Testing
@testable import TemporalKit // Assuming 'TemporalKit' is the module name
import Foundation // For UUID if needed by proposition, though not strictly here

// MARK: - Test Model Components for LTLModelCheckerTests

private enum LMC_TestState: String, Hashable, CaseIterable, CustomStringConvertible {
    case s0, s1, s2, s3
    var description: String { rawValue }
}

// This enum is for convenience in tests to refer to specific proposition IDs by name.
// The actual proposition objects will use the official TemporalKit.PropositionID struct.
private enum LMC_TestPropEnumID: String, Hashable, CustomStringConvertible {
    case p, q, r
    var description: String { rawValue }
    var officialID: TemporalKit.PropositionID { TemporalKit.PropositionID(rawValue: self.rawValue) }
}

private final class LMC_TestProposition: TemporalProposition {
    typealias Value = Bool
    typealias ID = TemporalKit.PropositionID // Conforms to Identifiable via TemporalProposition

    let id: TemporalKit.PropositionID
    let name: String
    var value: Bool // In LTL atomic formulas, value is implicitly true

    init(enumId: LMC_TestPropEnumID, name: String? = nil, value: Bool = true) {
        self.id = enumId.officialID
        self.name = name ?? enumId.rawValue
        self.value = value
    }
    
    // Convenience init for direct string ID if needed, though enum is preferred for tests
    init(id: TemporalKit.PropositionID, name: String? = nil, value: Bool = true) {
        self.id = id
        self.name = name ?? id.rawValue
        self.value = value
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        return self.value
    }

    // Hashable and Equatable are provided by TemporalProposition protocol extension using `id`
}

private struct LMC_SimpleKripkeModel: KripkeStructure {
    typealias State = LMC_TestState
    typealias AtomicPropositionIdentifier = TemporalKit.PropositionID // Use official PropositionID

    let states: Set<LMC_TestState>
    let initialStates: Set<LMC_TestState>
    let transitions: [LMC_TestState: Set<LMC_TestState>]
    let labeling: [LMC_TestState: Set<TemporalKit.PropositionID>] // Labeling uses official PropositionID

    init(
        states: Set<LMC_TestState> = Set(LMC_TestState.allCases),
        initialStates: Set<LMC_TestState>,
        transitions: [LMC_TestState: Set<LMC_TestState>],
        labeling: [LMC_TestState: Set<TemporalKit.PropositionID>] 
    ) {
        self.states = states
        self.initialStates = initialStates
        self.transitions = transitions
        self.labeling = labeling
    }

    var allStates: Set<LMC_TestState> { states }

    func successors(of state: LMC_TestState) -> Set<LMC_TestState> {
        return transitions[state] ?? []
    }

    func atomicPropositionsTrue(in state: LMC_TestState) -> Set<TemporalKit.PropositionID> {
        return labeling[state] ?? []
    }
}

// MARK: - LTLModelChecker Tests

@Suite("LTLModelChecker Tests")
struct LTLModelCheckerTests {
    fileprivate let checker = LTLModelChecker<LMC_SimpleKripkeModel>()

    fileprivate let model1 = LMC_SimpleKripkeModel(
        initialStates: [LMC_TestState.s0],
        transitions: [
            LMC_TestState.s0: [LMC_TestState.s1],
            LMC_TestState.s1: [LMC_TestState.s2],
            LMC_TestState.s2: [LMC_TestState.s0],
            LMC_TestState.s3: [LMC_TestState.s3]
        ],
        labeling: [
            LMC_TestState.s0: [LMC_TestPropEnumID.p.officialID],
            LMC_TestState.s1: [LMC_TestPropEnumID.q.officialID],
            LMC_TestState.s2: [LMC_TestPropEnumID.p.officialID, LMC_TestPropEnumID.q.officialID],
            LMC_TestState.s3: [LMC_TestPropEnumID.r.officialID]
        ]
    )
    
    fileprivate let model2 = LMC_SimpleKripkeModel(
        states: [LMC_TestState.s0, LMC_TestState.s1],
        initialStates: [LMC_TestState.s0],
        transitions: [
            LMC_TestState.s0: [LMC_TestState.s1],
            LMC_TestState.s1: [LMC_TestState.s1]
        ],
        labeling: [
            LMC_TestState.s0: [LMC_TestPropEnumID.p.officialID],
            LMC_TestState.s1: [LMC_TestPropEnumID.q.officialID]
        ]
    )

    @Test("Atomic Proposition Holds")
    func testAtomicPropositionHolds() throws {
        let p_atomic = LMC_TestProposition(enumId: .p)
        let p_formula = LTLFormula<LMC_TestProposition>.atomic(p_atomic)
        let result = try checker.check(formula: p_formula, model: model1)
        #expect(result.holds)
    }

    @Test("Atomic Proposition Fails")
    func testAtomicPropositionFails() throws {
        let q_atomic = LMC_TestProposition(enumId: .q)
        let q_formula = LTLFormula<LMC_TestProposition>.atomic(q_atomic)
        let result = try checker.check(formula: q_formula, model: model1)
        #expect(!result.holds, "Formula 'q' should fail as s0 does not satisfy q.")
        if case .fails(let counterexample) = result {
            #expect(counterexample.prefix == [LMC_TestState.s0]) 
            #expect(counterexample.cycle.isEmpty || counterexample.cycle == [LMC_TestState.s0]) 
        } else {
            Issue.record("Expected a counterexample for failing atomic proposition 'q'.")
        }
    }

    @Test("Eventually Holds (F p)")
    func testEventuallyHolds() throws {
        let q_atomic = LMC_TestProposition(enumId: .q)
        let fq_formula = LTLFormula<LMC_TestProposition>.eventually(.atomic(q_atomic))
        let result = try checker.check(formula: fq_formula, model: model1)
        #expect(result.holds, "Formula 'F q' should hold.")
    }
    
    @Test("Eventually Holds (F r) - Different Initial State")
    func testEventuallyHoldsDifferentInitial() throws {
        let modelWithS3Initial = LMC_SimpleKripkeModel(
            initialStates: [LMC_TestState.s3], 
            transitions: model1.transitions,
            labeling: model1.labeling
        )
        let r_atomic = LMC_TestProposition(enumId: .r)
        let fr_formula = LTLFormula<LMC_TestProposition>.eventually(.atomic(r_atomic))
        let result = try checker.check(formula: fr_formula, model: modelWithS3Initial)
        #expect(result.holds, "Formula 'F r' should hold when starting at s3.")
    }

    @Test("Globally Fails (G p)")
    func testGloballyFails() throws {
        let p_atomic = LMC_TestProposition(enumId: .p)
        let gp_formula = LTLFormula<LMC_TestProposition>.globally(.atomic(p_atomic))
        let result = try checker.check(formula: gp_formula, model: model1)
        #expect(!result.holds, "Formula 'G p' should fail.")
        
        if case .fails(let counterexample) = result {
            let modelStatesInPrefix = counterexample.prefix
            #expect(modelStatesInPrefix.contains(LMC_TestState.s1), "Counterexample prefix should lead to a state not satisfying p (e.g. s1).")
            #expect(counterexample.prefix == [LMC_TestState.s0, LMC_TestState.s1] || counterexample.prefix.last == LMC_TestState.s1)
        } else {
            Issue.record("Expected a counterexample for failing formula 'G p'.")
        }
    }
    
    @Test("Globally Holds (G r on s3 loop)")
    func testGloballyHoldsOnLoop() throws {
         let modelS3Only = LMC_SimpleKripkeModel(
            states: [LMC_TestState.s3],
            initialStates: [LMC_TestState.s3],
            transitions: [LMC_TestState.s3: [LMC_TestState.s3]],
            labeling: [LMC_TestState.s3: [LMC_TestPropEnumID.r.officialID]]
        )
        let r_atomic = LMC_TestProposition(enumId: .r)
        let gr_formula = LTLFormula<LMC_TestProposition>.globally(.atomic(r_atomic))
        let result = try checker.check(formula: gr_formula, model: modelS3Only)
        #expect(result.holds, "Formula 'G r' should hold for the s3 self-loop model.")
    }

    @Test("Next Holds (X q)")
    func testNextHolds() throws {
        let q_atomic = LMC_TestProposition(enumId: .q)
        let xq_formula = LTLFormula<LMC_TestProposition>.next(.atomic(q_atomic))
        let result = try checker.check(formula: xq_formula, model: model1)
        #expect(result.holds, "Formula 'X q' should hold.")
    }
    
    @Test("Next Fails (X p from s1)") // Title was misleading, X r from s0 is the test
    func testNextFails() throws {
        let r_atomic = LMC_TestProposition(enumId: .r)
        let xr_from_s0_formula = LTLFormula<LMC_TestProposition>.next(.atomic(r_atomic))
        let result_s0 = try checker.check(formula: xr_from_s0_formula, model: model1)
        #expect(!result_s0.holds, "Formula 'X r' from s0 should fail.")
        if case .fails(let counterexample) = result_s0 {
            #expect(counterexample.prefix == [LMC_TestState.s0, LMC_TestState.s1] || counterexample.prefix.last == LMC_TestState.s1)
        } else {
            Issue.record("Expected counterexample for 'X r' from s0.")
        }
    }
    
    @Test("Until Holds (p U q)")
    func testUntilHolds() throws {
        let p_prop = LMC_TestProposition(enumId: .p)
        let q_prop = LMC_TestProposition(enumId: .q)
        let p_formula = LTLFormula<LMC_TestProposition>.atomic(p_prop)
        let q_formula = LTLFormula<LMC_TestProposition>.atomic(q_prop)
        let pUq_formula = LTLFormula<LMC_TestProposition>.until(p_formula, q_formula)
        let result = try checker.check(formula: pUq_formula, model: model1)
        #expect(result.holds, "Formula 'p U q' should hold for model1 from s0.")
    }

    @Test("Until Fails (q U r from s0 in model1)")
    func testUntilFails() throws {
        let q_prop = LMC_TestProposition(enumId: .q)
        let r_prop = LMC_TestProposition(enumId: .r)
        let q_formula = LTLFormula<LMC_TestProposition>.atomic(q_prop)
        let r_formula = LTLFormula<LMC_TestProposition>.atomic(r_prop)
        let qUr_formula = LTLFormula<LMC_TestProposition>.until(q_formula, r_formula)
        let result = try checker.check(formula: qUr_formula, model: model1)
        #expect(!result.holds, "Formula 'q U r' should fail for model1 from s0.")
        if case .fails(let counterexample) = result {
            #expect(counterexample.prefix.first == LMC_TestState.s0 && !(model1.atomicPropositionsTrue(in: LMC_TestState.s0).contains(LMC_TestPropEnumID.q.officialID)))
        } else {
            Issue.record("Expected counterexample for 'q U r'.")
        }
    }
    
    @Test("Formula 'true' Holds")
    func testTrueHolds() throws {
        let trueFormula = LTLFormula<LMC_TestProposition>.booleanLiteral(true)
        let result = try checker.check(formula: trueFormula, model: model2)
        #expect(result.holds, "Formula 'true' should always hold.")
    }

    @Test("Formula 'false' Fails")
    func testFalseFails() throws {
        let falseFormula = LTLFormula<LMC_TestProposition>.booleanLiteral(false)
        let result = try checker.check(formula: falseFormula, model: model2)
        #expect(!result.holds, "Formula 'false' should always fail.")
        if case .fails(let counterexample) = result {
            #expect(counterexample.prefix.first == LMC_TestState.s0)
        } else {
            Issue.record("Expected a counterexample for 'false'.")
        }
    }

    // MARK: - Test Model Components for G p_kripke like scenario

    private enum DemoLikeTestKripkeModelState: Hashable, CustomStringConvertible {
        case s0, s1, s2
        public var description: String {
            switch self {
            case .s0: return "s0"
            case .s1: return "s1"
            case .s2: return "s2"
            }
        }
    }

    // Using LMC_TestProposition for simplicity, but ensuring its ID is distinct if used alongside others.
    // Or, define a new Proposition type if LMC_TestProposition's evaluation is not suitable.
    // For this case, we can reuse LMC_TestProposition with a specific ID.
    // Let's define a new proposition type to exactly match how ClosureTemporalProposition works.
    private typealias DemoLikeTestProposition = TemporalKit.ClosureTemporalProposition<DemoLikeTestKripkeModelState, Bool>

    // Made p_demo_like static so DemoLikeTestKripkeStructure can access it if it were nested non-privately
    // or if it were defined outside. For this structure, it will be captured by the closure if defined before the struct.
    // Keeping it as a property of LTLModelCheckerTests and passing it to DemoLikeTestKripkeStructure or using it directly
    // in atomicPropositionsTrue seems cleaner. For now, let's define it such that it's accessible.
    // To ensure DemoLikeTestKripkeStructure can access p_demo_like.id, we pass it or make it globally/statically visible.
    // Let's define it as a static constant within LTLModelCheckerTests for clarity.
    private static let static_p_demo_like = TemporalKit.makeProposition(
        id: "p_demo_like",
        name: "p (for demo-like test)",
        evaluate: { (state: DemoLikeTestKripkeModelState) -> Bool in state == .s0 || state == .s2 }
    )

    private struct DemoLikeTestKripkeStructure: KripkeStructure {
        typealias State = DemoLikeTestKripkeModelState
        typealias AtomicPropositionIdentifier = PropositionID

        let initialStates: Set<State> = [.s0]
        let allStates: Set<State> = [.s0, .s1, .s2]

        func successors(of state: State) -> Set<State> {
            switch state {
            case .s0: return [.s1]
            case .s1: return [.s2]
            case .s2: return [.s0, .s2]
            }
        }

        func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
            var trueProps = Set<AtomicPropositionIdentifier>()
            if state == .s0 || state == .s2 { trueProps.insert(LTLModelCheckerTests.static_p_demo_like.id) } // Use static member
            return trueProps
        }
    }

    @Test("Model Check G p on Demo-like Structure (Should Fail)")
    func testModelCheck_Gp_OnDemoLikeStructure_ShouldFail() throws {
        let modelChecker = LTLModelChecker<DemoLikeTestKripkeStructure>()
        let model = DemoLikeTestKripkeStructure()

        // Use the static proposition in the formula
        let formula_Gp: LTLFormula<DemoLikeTestProposition> = .globally(.atomic(LTLModelCheckerTests.static_p_demo_like))

        let result = try modelChecker.check(formula: formula_Gp, model: model)

        switch result {
        case .holds:
            Issue.record("Error: G p_demo_like should FAIL on this model, but it HOLDS.")
        case .fails(let counterexample):
            // Expected to fail. For now, don't validate counterexample structure, just that it fails.
            print("Test testModelCheck_Gp_OnDemoLikeStructure_ShouldFail: Correctly FAILED.")
            // Add more detailed counterexample checks later if needed.
            #expect(!counterexample.prefix.isEmpty || !counterexample.cycle.isEmpty, "Counterexample should not be completely empty.")
        }
    }
}

// Extension for ModelCheckResult to easily check for .holds
extension ModelCheckResult {
    var holds: Bool {
        if case .holds = self {
            return true
        }
        return false
    }
} 
