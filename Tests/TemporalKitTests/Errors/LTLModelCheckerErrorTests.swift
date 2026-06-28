import Testing
import Foundation
@testable import TemporalKit

/// Tests for the LTLModelCheckerError error descriptions
struct LTLModelCheckerErrorTests {

    @Test
    func testInternalProcessingErrorDescription() {
        // Create an LTLModelCheckerError.internalProcessingError error
        let error = LTLModelCheckerError.internalProcessingError("Invalid automaton state")

        // Check that the error description is as expected
        let description = error.errorDescription
        #expect(description == "LTLModelChecker Error: Internal Processing Failed. Details: Invalid automaton state",
            "The error description should mention internal processing and include the details")
    }
}
