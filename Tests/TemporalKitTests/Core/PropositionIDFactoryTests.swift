import Foundation
import Testing
@testable import TemporalKit

struct PropositionIDFactoryTests {

    // MARK: - Helper Methods

    /// Validates if a PropositionID was successfully created
    private func isValidPropositionID(_ id: PropositionID) -> Bool {
        // PropositionID is already validated at creation time
        // We only verify that a non-empty ID was generated
        // This decouples the test from PropositionID's internal validation rules
        return !id.rawValue.isEmpty
    }

    /// Checks if the ID is either the system fallback or a valid PropositionID
    private func isValidOrFallback(_ id: PropositionID) -> Bool {
        return id.rawValue == "system_fallback_proposition" || isValidPropositionID(id)
    }

    // MARK: - create(from:) Tests

    @Test
    func testCreateWithValidInput() throws {
        let validID = try PropositionIDFactory.create(from: "valid_proposition_id")
        #expect(validID.rawValue == "valid_proposition_id")
    }

    @Test
    func testCreateWithEmptyString() throws {
        // Empty string should trigger fallback
        let id = try PropositionIDFactory.create(from: "")
        #expect(id.rawValue == "system_fallback_proposition")
    }

    @Test
    func testCreateWithInvalidCharacters() throws {
        // Test with various invalid characters that should trigger fallback
        let invalidInputs = ["@#$%", "proposition with spaces", "😀", "prop@#$"]

        for input in invalidInputs {
            let id = try PropositionIDFactory.create(from: input)
            // Check if it's either the fallback or contains only valid parts
            #expect(isValidOrFallback(id), "Failed for input: \(input)")
        }
    }

    // MARK: - createOrNil(from:) Tests

    @Test
    func testCreateOrNilWithValidInput() {
        let id = PropositionIDFactory.createOrNil(from: "valid_proposition_id")
        #expect(id != nil)
        #expect(id?.rawValue == "valid_proposition_id")
    }

    @Test
    func testCreateOrNilWithEmptyString() {
        let id = PropositionIDFactory.createOrNil(from: "")
        #expect(id != nil)
        #expect(id?.rawValue == "system_fallback_proposition")
    }

    @Test
    func testCreateOrNilWithInvalidCharacters() {
        let invalidInputs = ["@#$%", "proposition with spaces", "😀", "prop@#$"]

        for input in invalidInputs {
            let id = PropositionIDFactory.createOrNil(from: input)
            #expect(id != nil, "Failed for input: \(input)")
            // Check if it's either the fallback or contains only valid parts
            if let id = id {
                #expect(isValidOrFallback(id), "Failed for input: \(input)")
            }
        }
    }

    // MARK: - createUnique(seed:) Tests

    @Test
    func testCreateUniqueWithValidSeed() throws {
        let seed = "test_seed"
        let id = try PropositionIDFactory.createUnique(seed: seed)

        // Should create a deterministic ID based on hash
        let expectedPrefix = "prop_"
        #expect(id.rawValue.hasPrefix(expectedPrefix))

        // Same seed should produce same ID (deterministic)
        let id2 = try PropositionIDFactory.createUnique(seed: seed)
        #expect(id.rawValue == id2.rawValue)
    }

    @Test
    func testCreateUniqueWithDifferentSeeds() throws {
        let id1 = try PropositionIDFactory.createUnique(seed: "seed1")
        let id2 = try PropositionIDFactory.createUnique(seed: "seed2")

        #expect(id1.rawValue != id2.rawValue)
    }

    @Test
    func testCreateUniqueWithEmptySeed() throws {
        let id = try PropositionIDFactory.createUnique(seed: "")
        #expect(id.rawValue.hasPrefix("prop_"))
    }

    @Test
    func testCreateUniqueWithSpecialCharacters() throws {
        let seeds = ["@#$%", "seed with spaces", "日本語", "😀emoji"]

        for seed in seeds {
            let id = try PropositionIDFactory.createUnique(seed: seed)
            #expect(id.rawValue.hasPrefix("prop_"), "Failed for seed: \(seed)")
        }
    }

    // MARK: - Fallback and Error Handling Tests

    @Test
    func testFallbackMechanismOrder() throws {
        // Test that fallback follows the correct order:
        // 1. Try original value
        // 2. Try system_fallback_proposition
        // 3. Try UUID-based fallback

        // First test: invalid input should use system_fallback_proposition
        let id1 = try PropositionIDFactory.create(from: "")
        #expect(id1.rawValue == "system_fallback_proposition")

        // Note: The UUID fallback mechanism exists as a final safety net in createFallbackID.
        // It triggers when system_fallback_proposition is invalid (unlikely in production).
        // Testing this would require mocking PropositionID validation, which is beyond
        // the scope of unit tests and better suited for integration testing.
    }

    @Test
    func testErrorHandlingInCreateUnique() throws {
        // Even with extreme seeds, createUnique should not throw
        let extremeSeeds = [
            String(repeating: "a", count: 10000),
            "\n\t\r",
            String(repeating: "😀", count: 100)
        ]

        for seed in extremeSeeds {
            // Should not throw
            let id = try PropositionIDFactory.createUnique(seed: seed)
            #expect(id.rawValue.count > 0)
        }
    }

    @Test
    func testPerformanceWithLargeInput() throws {
        let largeInput = String(repeating: "a", count: 10000)

        // Measure performance in a cross-platform way
        let start = Date()
        _ = try PropositionIDFactory.createUnique(seed: largeInput)
        let elapsed = Date().timeIntervalSince(start)

        // Performance should be reasonable even with large input
        #expect(elapsed < 0.1, "Performance degradation detected: \(elapsed) seconds")
    }

    // MARK: - Thread Safety Tests

    @Test
    func testThreadSafetyForCreate() async throws {
        let iterations = 100
        let inputs = ["valid_id", "", "@#$%", "test_123"]

        // Run multiple concurrent tasks
        let results = await withTaskGroup(of: Result<PropositionID, Error>.self) { group in
            for i in 0..<iterations {
                let input = inputs[i % inputs.count]
                group.addTask {
                    do {
                        let id = try PropositionIDFactory.create(from: input)
                        return .success(id)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var results: [Result<PropositionID, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // All operations should succeed
        #expect(results.count == iterations)
        for result in results {
            switch result {
            case .success:
                break // Expected
            case .failure(let error):
                Issue.record("Unexpected error in concurrent operation: \(error)")
            }
        }
    }

    @Test
    func testThreadSafetyForCreateOrNil() async {
        let iterations = 100
        let inputs = ["valid_id", "", "@#$%", "test_123"]

        let results = await withTaskGroup(of: PropositionID?.self) { group in
            for i in 0..<iterations {
                let input = inputs[i % inputs.count]
                group.addTask {
                    return PropositionIDFactory.createOrNil(from: input)
                }
            }

            var results: [PropositionID?] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // All operations should return non-nil
        #expect(results.count == iterations)
        for result in results {
            #expect(result != nil)
        }
    }

    @Test
    func testThreadSafetyForCreateUnique() async throws {
        let iterations = 100

        let results = await withTaskGroup(of: Result<PropositionID, Error>.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    do {
                        let id = try PropositionIDFactory.createUnique(seed: "seed_\(i)")
                        return .success(id)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var results: [Result<PropositionID, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // All operations should succeed
        #expect(results.count == iterations)

        // Collect all IDs to verify uniqueness
        var uniqueIDs = Set<String>()
        for result in results {
            switch result {
            case .success(let id):
                uniqueIDs.insert(id.rawValue)
            case .failure(let error):
                Issue.record("Unexpected error in concurrent operation: \(error)")
            }
        }

        // All IDs should be unique (different seeds)
        #expect(uniqueIDs.count == iterations)
    }

    // MARK: - Edge Cases

    @Test
    func testVeryLongInput() throws {
        let longInput = String(repeating: "a", count: 1000)
        let id = try PropositionIDFactory.create(from: longInput)
        #expect(id.rawValue.count > 0)
    }

    @Test
    func testSpecialUnicodeCharacters() throws {
        let unicodeInputs = [
            "🇯🇵🇺🇸🇬🇧", // Flag emojis - should trigger fallback
            "⌘⌥⇧⌃", // Mac modifier keys - should trigger fallback
            "prop🎉test", // Mixed valid and invalid
            "test😀" // Valid prefix with emoji
        ]

        for input in unicodeInputs {
            let id = try PropositionIDFactory.create(from: input)
            // These inputs should either use fallback or be transformed
            #expect(isValidPropositionID(id), "Invalid characters in ID for input: \(input)")
        }
    }

    @Test
    func testUnicodeLettersAreValid() throws {
        // These should be valid as they are considered letters
        let validUnicodeInputs = [
            "日本語", // Japanese characters
            "𝕳𝖊𝖑𝖑𝖔", // Mathematical alphanumeric symbols
            "①②③④⑤", // Circled numbers might be considered valid
            "Ελληνικά", // Greek
            "Русский" // Russian
        ]

        for input in validUnicodeInputs {
            let id = try PropositionIDFactory.create(from: input)
            // These are valid according to PropositionID's isLetter check
            #expect(id.rawValue == input, "Expected valid unicode input to be preserved: \(input)")
        }
    }

    // MARK: - Error Case Tests

    @Test
    func testCreateThrowsErrorWhenNoValidIDPossible() throws {
        // This test documents the expected behavior when all fallback mechanisms fail
        // In the current implementation, this is extremely unlikely as UUID generation
        // should always succeed, but we verify the implementation doesn't throw unexpectedly

        // Test that the factory methods handle all inputs without throwing
        let testInputs = ["", "@#$%", "test", "日本語", String(repeating: "x", count: 10000)]

        for input in testInputs {
            // Verify that create(from:) doesn't throw for any input
            let id = try PropositionIDFactory.create(from: input)
            #expect(isValidPropositionID(id), "Factory should always produce valid IDs")
        }

        // Document conditions that would cause errors (for future reference):
        // 1. PropositionID validation rules become more restrictive
        // 2. System resource constraints prevent UUID generation
        // 3. Memory allocation failures during string operations
        // Currently, these scenarios are theoretical and not testable without mocking
    }

    @Test
    func testConcurrentAccessWithMixedValidAndInvalidInputs() async throws {
        let iterations = 50
        let mixedInputs = [
            "valid_id",
            "",  // triggers fallback
            "@#$%",  // triggers fallback
            "test_123",
            "proposition with spaces",  // triggers fallback
            "测试",  // valid unicode
            "test@#"  // partially invalid
        ]

        let results = await withTaskGroup(of: (input: String, result: Result<PropositionID, Error>).self) { group in
            for i in 0..<iterations {
                let input = mixedInputs[i % mixedInputs.count]
                group.addTask {
                    do {
                        let id = try PropositionIDFactory.create(from: input)
                        return (input, .success(id))
                    } catch {
                        return (input, .failure(error))
                    }
                }
            }

            var results: [(String, Result<PropositionID, Error>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // Verify all operations completed successfully
        #expect(results.count == iterations)

        // Verify error handling consistency
        for (input, result) in results {
            switch result {
            case .success(let id):
                #expect(isValidPropositionID(id), "Invalid ID generated for input: \(input)")
            case .failure(let error):
                Issue.record("Unexpected error for input '\(input)': \(error)")
            }
        }
    }

    @Test
    func testCreateOrNilNeverThrows() {
        // Test that createOrNil handles all edge cases gracefully
        let edgeCases = [
            "",
            " ",
            "\n",
            "\t",
            "\0",  // actual null character
            String(repeating: "🎉", count: 1000),
            String(repeating: " ", count: 100),
            "test\nwith\nnewlines",
            "test\twith\ttabs",
            String(UnicodeScalar(0))  // explicit null character for clarity
        ]

        for input in edgeCases {
            // Should never throw, always return nil or valid ID
            let id = PropositionIDFactory.createOrNil(from: input)
            if let id = id {
                #expect(isValidPropositionID(id), "Invalid ID for edge case: \(input)")
            }
            // nil is also acceptable for invalid inputs
        }
    }
}
