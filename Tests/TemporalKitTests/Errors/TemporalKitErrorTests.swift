import Testing
@testable import TemporalKit // Assuming 'TemporalKit' is the module name
import Foundation

@Suite("TemporalKitError Tests")
struct TemporalKitErrorTests {

    @Test("stateTypeMismatch errorDescription is correct")
    func testStateTypeMismatchErrorDescription() {
        let propID = PropositionID(rawValue: "test-prop-id")!
        let propName = "TestProp"
        let expectedType = "ExpectedTestState"
        let actualType = "ActualTestState"

        let error = TemporalKitError.stateTypeMismatch(
            expected: expectedType,
            actual: actualType,
            propositionID: propID,
            propositionName: propName
        )

        let expectedDescription = "State type mismatch for proposition 'TestProp' (ID: test-prop-id). Expected context to provide 'ExpectedTestState', but got 'ActualTestState'."

        #expect(error.errorDescription == expectedDescription)
        // For more robust testing of LocalizedError conformance:
        #expect(error.localizedDescription == expectedDescription)
    }
}
