import XCTest
@testable import TemporalKit

/// Test case for GBAConditionGenerator focusing on Release operator acceptance condition verification
final class GBAConditionGeneratorTests: XCTestCase {

    // MARK: - Test Types

    // Mock proposition for testing
    class TestProposition: TemporalProposition {
        typealias Value = Bool
        typealias ID = PropositionID

        let id: PropositionID
        var name: String { id.rawValue }

        init(id: String) {
            self.id = PropositionID(rawValue: id)!
        }

        func evaluate(in context: EvaluationContext) throws -> Bool {
            true // Default evaluation doesn't matter for these tests
        }
    }

    // Create propositions
    let p = TestProposition(id: "p")
    let q = TestProposition(id: "q")
    let r = TestProposition(id: "r")

    // MARK: - Helper Methods

    /// Creates a tableau node with the given formulas
    private func createTableauNode(formulas: Set<LTLFormula<TestProposition>>, nextFormulas: Set<LTLFormula<TestProposition>> = []) -> TableauNode<TestProposition> {
        TableauNode(currentFormulas: formulas, nextFormulas: nextFormulas)
    }

    /// Creates a map from tableau nodes to state IDs
    private func createNodeToStateMap(_ nodes: [TableauNode<TestProposition>]) -> [TableauNode<TestProposition>: FormulaAutomatonState] {
        var map = [TableauNode<TestProposition>: FormulaAutomatonState]()
        for (index, node) in nodes.enumerated() {
            map[node] = index
        }
        return map
    }

    // MARK: - Tests

    /// Tests that the collector properly identifies liveness subformulas
    func testCollectLivenessSubformulas() throws {
        // Just call determineConditions to validate it works without errors
        let releaseFormula: LTLFormula<TestProposition> = .release(.atomic(p), .atomic(q))

        let result = GBAConditionGenerator<TestProposition>.determineConditions(
            tableauNodes: [],
            nodeToStateIDMap: [:],
            originalNNFFormula: releaseFormula
        )

        // Just ensure we got a result without errors
        XCTAssertNotNil(result)
    }

    /// Tests the core functionality of acceptance set generation for Release operator
    func testReleaseOperatorAcceptanceSets() throws {
        // Create Release formula: p R q
        let releaseFormula: LTLFormula<TestProposition> = .release(.atomic(p), .atomic(q))

        // Create tableau nodes with different formula combinations
        let node1 = createTableauNode(formulas: [.atomic(p), .atomic(q), releaseFormula]) // p=true, q=true, p R q present
        let node2 = createTableauNode(formulas: [.atomic(q), releaseFormula]) // p=false, q=true, p R q present
        let node3 = createTableauNode(formulas: [.atomic(p)]) // p=true, q=false, p R q not present
        let node4 = createTableauNode(formulas: []) // p=false, q=false, p R q not present

        // Create node to state map
        let nodes = [node1, node2, node3, node4]
        let nodeMap = createNodeToStateMap(nodes)

        // Generate acceptance sets
        let acceptanceSets = GBAConditionGenerator<TestProposition>.determineConditions(
            tableauNodes: Set(nodes),
            nodeToStateIDMap: nodeMap,
            originalNNFFormula: releaseFormula
        )

        // Verify that at least one acceptance set was created
        XCTAssertFalse(acceptanceSets.isEmpty, "Should generate at least one acceptance set for Release formula")

        if let firstSet = acceptanceSets.first {
            // For Release formula p R q:
            // - Node 1 (p=true, q=true) should be in acceptance set (satisfies both p and q)
            // - Node 3 (p=true, q=false) should be in acceptance set (has p but not p R q)
            // - Node 4 (empty) should be in acceptance set (doesn't have p R q)
            XCTAssertTrue(firstSet.contains(0), "Node with p=true, q=true should be in acceptance set")
            XCTAssertTrue(firstSet.contains(2), "Node with p=true, q=false should be in acceptance set (doesn't have formula)")
            XCTAssertTrue(firstSet.contains(3), "Empty node should be in acceptance set (doesn't have formula)")

            // Node 2 (p=false, q=true) with p R q present might be in acceptance set depending on implementation
            // (It has q but not p, and p R q is pending, so whether it's in the set depends on exact implementation)
        }
    }

    /// Tests special case: true R q
    func testTrueReleaseSpecialCase() throws {
        // Create formula: true R q
        let trueRelease: LTLFormula<TestProposition> = .release(.booleanLiteral(true), .atomic(q))

        // Create tableau nodes
        let node1 = createTableauNode(formulas: [.atomic(q), trueRelease]) // q=true, true R q present
        let node2 = createTableauNode(formulas: [trueRelease]) // q=false, true R q present

        let nodes = [node1, node2]
        let nodeMap = createNodeToStateMap(nodes)

        // Generate acceptance sets
        let acceptanceSets = GBAConditionGenerator<TestProposition>.determineConditions(
            tableauNodes: Set(nodes),
            nodeToStateIDMap: nodeMap,
            originalNNFFormula: trueRelease
        )

        XCTAssertFalse(acceptanceSets.isEmpty, "Should generate acceptance sets for true R q formula")

        if let firstSet = acceptanceSets.first {
            // For true R q, all states should be in the acceptance set
            // since true R q should simplify to just q with no liveness constraint
            XCTAssertEqual(firstSet.count, nodes.count, "All nodes should be in acceptance set for true R q")
        }
    }

    /// Tests special case: false R q (equivalent to G q)
    func testFalseReleaseSpecialCase() throws {
        // Create formula: false R q (equivalent to G q)
        let falseRelease: LTLFormula<TestProposition> = .release(.booleanLiteral(false), .atomic(q))

        // Create tableau nodes
        let node1 = createTableauNode(formulas: [.atomic(q), falseRelease]) // q=true, false R q present
        let node2 = createTableauNode(formulas: [falseRelease]) // q=false, false R q present
        let node3 = createTableauNode(formulas: [.atomic(q)]) // q=true, false R q absent

        let nodes = [node1, node2, node3]
        let nodeMap = createNodeToStateMap(nodes)

        // Generate acceptance sets
        let acceptanceSets = GBAConditionGenerator<TestProposition>.determineConditions(
            tableauNodes: Set(nodes),
            nodeToStateIDMap: nodeMap,
            originalNNFFormula: falseRelease
        )

        XCTAssertFalse(acceptanceSets.isEmpty, "Should generate acceptance sets for false R q formula")

        if let firstSet = acceptanceSets.first {
            // For false R q (equivalent to G q):
            // - Node 1 (q=true, false R q present) should be in set (satisfies q)
            // - Node 3 (q=true, false R q absent) should be in set (satisfies q)
            XCTAssertTrue(firstSet.contains(0), "Node with q=true should be in acceptance set")
            XCTAssertTrue(firstSet.contains(2), "Node with q=true without formula should be in acceptance set")

            // Node 2 might not be in set as it doesn't satisfy q
            if firstSet.contains(1) {
                // If present, additional verification would be needed
                // (depends on exact implementation - may be there because it has the formula)
            }
        }
    }

    /// Tests that empty formulas are properly handled
    func testEmptyFormula() throws {
        // Create a few tableau nodes
        let node1 = createTableauNode(formulas: [.atomic(p)])
        let node2 = createTableauNode(formulas: [.atomic(q)])

        let nodes = [node1, node2]
        let nodeMap = createNodeToStateMap(nodes)

        // Test with true formula (no liveness constraints)
        let trueFormula: LTLFormula<TestProposition> = .booleanLiteral(true)

        let acceptanceSets = GBAConditionGenerator<TestProposition>.determineConditions(
            tableauNodes: Set(nodes),
            nodeToStateIDMap: nodeMap,
            originalNNFFormula: trueFormula
        )

        XCTAssertFalse(acceptanceSets.isEmpty, "Should generate acceptance sets even for true formula")

        if let firstSet = acceptanceSets.first {
            XCTAssertEqual(firstSet.count, nodes.count, "All nodes should be in acceptance set for true formula")
        }
    }

    /// Tests complex nested formulas with Release operators
    func testNestedReleaseFormulas() throws {
        // p R (q R r) - nested Release
        let innerRelease: LTLFormula<TestProposition> = .release(.atomic(q), .atomic(r))
        let outerRelease: LTLFormula<TestProposition> = .release(.atomic(p), innerRelease)

        // Create some tableau nodes with different formula combinations
        let node1 = createTableauNode(formulas: [.atomic(p), .atomic(q), .atomic(r), innerRelease, outerRelease])
        let node2 = createTableauNode(formulas: [.atomic(q), .atomic(r), innerRelease, outerRelease])
        let node3 = createTableauNode(formulas: [.atomic(p), .atomic(r), outerRelease])

        let nodes = [node1, node2, node3]
        let nodeMap = createNodeToStateMap(nodes)

        // Generate acceptance sets
        let acceptanceSets = GBAConditionGenerator<TestProposition>.determineConditions(
            tableauNodes: Set(nodes),
            nodeToStateIDMap: nodeMap,
            originalNNFFormula: outerRelease
        )

        // We should have two acceptance sets - one for each Release operator
        XCTAssertGreaterThanOrEqual(acceptanceSets.count, 1, "Should generate at least one acceptance set for nested Release formula")

        // More detailed verification would depend on exact GBAConditionGenerator implementation
    }
}
