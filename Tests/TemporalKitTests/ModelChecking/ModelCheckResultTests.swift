import Testing
@testable import TemporalKit // Assuming 'TemporalKit' is the module name

// Using a simple state type for these tests, like an Int or a String,
// as the actual state content doesn't affect Counterexample's description logic.
private enum TestState: String, CustomStringConvertible, Hashable {
    case s0, s1, s2, s3
    var description: String { rawValue }
}

@Suite("ModelCheckResult & Counterexample Tests")
struct ModelCheckResultTests {

    @Test("Counterexample - infinitePathDescription - Prefix Only")
    func testCounterexampleDescription_PrefixOnly() throws {
        let ce = Counterexample(prefix: [TestState.s0, TestState.s1], cycle: [])
        #expect(ce.infinitePathDescription == "s0 -> s1")
    }

    @Test("Counterexample - infinitePathDescription - Cycle Only")
    func testCounterexampleDescription_CycleOnly() throws {
        let ce = Counterexample(prefix: [], cycle: [TestState.s2, TestState.s3])
        #expect(ce.infinitePathDescription == "(s2 -> s3)∞")
    }

    @Test("Counterexample - infinitePathDescription - Prefix and Cycle")
    func testCounterexampleDescription_PrefixAndCycle() throws {
        let ce = Counterexample(prefix: [TestState.s0], cycle: [TestState.s1, TestState.s2])
        #expect(ce.infinitePathDescription == "s0 -> (s1 -> s2)∞")
    }

    @Test("Counterexample - infinitePathDescription - Empty Prefix and Empty Cycle")
    func testCounterexampleDescription_EmptyPrefixEmptyCycle() throws {
        let ce = Counterexample<TestState>(prefix: [], cycle: [])
        #expect(ce.infinitePathDescription.isEmpty)
    }

    @Test("Counterexample - infinitePathDescription - Single State Prefix, Empty Cycle")
    func testCounterexampleDescription_SingleStatePrefixEmptyCycle() throws {
        let ce = Counterexample(prefix: [TestState.s0], cycle: [])
        #expect(ce.infinitePathDescription == "s0")
    }

    @Test("Counterexample - infinitePathDescription - Empty Prefix, Single State Cycle")
    func testCounterexampleDescription_EmptyPrefixSingleStateCycle() throws {
        let ce = Counterexample(prefix: [], cycle: [TestState.s0])
        #expect(ce.infinitePathDescription == "(s0)∞")
    }

    // Test ModelCheckResult enum itself - just for completeness, likely covered by LTLModelCheckerTests
    @Test("ModelCheckResult - Holds")
    func testModelCheckResultHolds() throws {
        let result: ModelCheckResult<TestState> = .holds
        if case .holds = result {
            #expect(true)
        } else {
            Issue.record("Expected .holds")
        }
    }

    @Test("ModelCheckResult - Fails")
    func testModelCheckResultFails() throws {
        let counterExample = Counterexample(prefix: [TestState.s0], cycle: [TestState.s1])
        let result: ModelCheckResult<TestState> = .fails(counterexample: counterExample)
        if case .fails(let ce) = result {
            #expect(ce.prefix == [TestState.s0])
            #expect(ce.cycle == [TestState.s1])
        } else {
            Issue.record("Expected .fails")
        }
    }
}
