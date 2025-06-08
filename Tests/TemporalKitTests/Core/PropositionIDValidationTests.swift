import Foundation
import Testing
@testable import TemporalKit

struct PropositionIDValidationTests {
    
    @Test("Valid PropositionID creation")
    func testValidPropositionID() {
        let validIDs = [
            "validID",
            "test_proposition",
            "prop-123",
            "component.subcomponent",
            "ABC123",
            "a1b2c3"
        ]
        
        for id in validIDs {
            let propositionID = PropositionID(rawValue: id)
            #expect(propositionID != nil, "Should create valid PropositionID for: \(id)")
            #expect(propositionID?.rawValue == id)
        }
    }
    
    @Test("Invalid PropositionID creation returns nil")
    func testInvalidPropositionIDReturnsNil() {
        let invalidIDs = [
            "",                    // Empty string
            " ",                   // Space
            "test ID",             // Contains space
            "test\nID",            // Contains newline
            "test\tID",            // Contains tab
            "test@ID",             // Contains @
            "test#ID",             // Contains #
            "test$ID",             // Contains $
            "test%ID",             // Contains %
            "test&ID",             // Contains &
            "test*ID",             // Contains *
            "test+ID",             // Contains +
            "test=ID",             // Contains =
            "test/ID",             // Contains /
            "test\\ID",            // Contains backslash
            "test|ID",             // Contains pipe
            "test<ID",             // Contains <
            "test>ID",             // Contains >
            "test?ID",             // Contains ?
            "test:ID",             // Contains :
            "test;ID",             // Contains ;
            "test'ID",             // Contains '
            "test\"ID",            // Contains "
            "test[ID",             // Contains [
            "test]ID",             // Contains ]
            "test{ID",             // Contains {
            "test}ID",             // Contains }
            "test(ID",             // Contains (
            "test)ID",             // Contains )
            "test,ID",             // Contains ,
            "test!ID"              // Contains !
        ]
        
        for id in invalidIDs {
            let propositionID = PropositionID(rawValue: id)
            #expect(propositionID == nil, "Should return nil for invalid ID: '\(id)'")
        }
    }
    
    @Test("Validating initializer with detailed errors")
    func testValidatingInitializer() throws {
        // Test valid ID
        let validID = try PropositionID(validating: "valid_id")
        #expect(validID.rawValue == "valid_id")
        
        // Test empty string
        #expect(throws: PropositionIDError.emptyString) {
            _ = try PropositionID(validating: "")
        }
        
        // Test whitespace
        #expect(throws: PropositionIDError.containsWhitespace) {
            _ = try PropositionID(validating: "test ID")
        }
        
        #expect(throws: PropositionIDError.containsWhitespace) {
            _ = try PropositionID(validating: "test\nID")
        }
        
        // Test invalid characters
        #expect(throws: (any Error).self) {
            _ = try PropositionID(validating: "test@ID")
        }
        
        #expect(throws: (any Error).self) {
            _ = try PropositionID(validating: "test#ID")
        }
    }
    
    @Test("Error descriptions are meaningful")
    func testErrorDescriptions() {
        let emptyError = PropositionIDError.emptyString
        #expect(emptyError.errorDescription?.contains("empty") == true)
        
        let whitespaceError = PropositionIDError.containsWhitespace
        #expect(whitespaceError.errorDescription?.contains("whitespace") == true)
        
        let invalidCharsError = PropositionIDError.invalidCharacters("@#$")
        #expect(invalidCharsError.errorDescription?.contains("@#$") == true)
    }
    
    @Test("Convenience initializer backward compatibility")
    func testConvenienceInitializer() {
        let validID = PropositionID("valid_id")
        #expect(validID != nil)
        #expect(validID?.rawValue == "valid_id")
        
        let invalidID = PropositionID("invalid@id")
        #expect(invalidID == nil)
    }
    
    @Test("PropositionID with Unicode characters")
    func testUnicodeCharacters() {
        // These should be valid as alphanumerics include Unicode letters
        let validUnicodeIDs = [
            "テスト",              // Japanese
            "测试",                // Chinese
            "тест",               // Russian
            "café"                // Accented characters
        ]
        
        for id in validUnicodeIDs {
            let propositionID = PropositionID(rawValue: id)
            #expect(propositionID != nil, "Unicode letter ID should be valid: '\(id)'")
            #expect(propositionID?.rawValue == id)
        }
        
        // These should be invalid (emojis and symbols)
        let invalidUnicodeIDs = [
            "test_🚀",            // Emoji
            "test@test",          // Symbol
            "test#test"           // Symbol
        ]
        
        for id in invalidUnicodeIDs {
            let propositionID = PropositionID(rawValue: id)
            #expect(propositionID == nil, "Unicode symbol/emoji ID should be invalid: '\(id)'")
        }
    }
    
    @Test("Long PropositionID handling")
    func testLongPropositionID() {
        // Test very long ID (should be valid if contains only valid characters)
        let longValidID = String(repeating: "a", count: 1000)
        let propositionID = PropositionID(rawValue: longValidID)
        #expect(propositionID != nil, "Long valid ID should be accepted")
        
        // Test extremely long ID
        let extremelyLongID = String(repeating: "b", count: 10000)
        let extremePropositionID = PropositionID(rawValue: extremelyLongID)
        #expect(extremePropositionID != nil, "Extremely long valid ID should be accepted")
    }
    
    @Test("Edge cases with valid characters")
    func testEdgeCasesWithValidCharacters() {
        let edgeCases = [
            "123",                 // Numbers only
            "___",                 // Underscores only
            "---",                 // Hyphens only
            "...",                 // Dots only
            "a",                   // Single character
            "A",                   // Single uppercase
            "1",                   // Single digit
            "_",                   // Single underscore
            "-",                   // Single hyphen
            ".",                   // Single dot
            "a.b.c.d.e",          // Multiple dots
            "a_b_c_d_e",          // Multiple underscores
            "a-b-c-d-e"           // Multiple hyphens
        ]
        
        for id in edgeCases {
            let propositionID = PropositionID(rawValue: id)
            #expect(propositionID != nil, "Should accept edge case: '\(id)'")
            #expect(propositionID?.rawValue == id)
        }
    }
}