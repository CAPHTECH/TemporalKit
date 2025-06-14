import XCTest
@testable import TemporalKit

final class LTLFormulaValidationTests: XCTestCase {
    typealias Formula = LTLFormula<DSLTestProposition>

    let p = Formula.atomic(DSLTestProposition("p"))
    let q = Formula.atomic(DSLTestProposition("q"))
    let r = Formula.atomic(DSLTestProposition("r"))

    // MARK: - Basic Validation Tests

    func testRedundantTemporalOperators() {
        // G(true) is redundant
        let alwaysTrue = Formula.G(.booleanLiteral(true))
        let warnings = alwaysTrue.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .redundancy })
    }

    func testDoubleNegation() {
        // !!p should be warned
        let doubleNeg = !(!p)
        let warnings = doubleNeg.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .redundancy })
    }

    func testContradiction() {
        // p && !p is a contradiction
        let contradiction = p && !p
        let warnings = contradiction.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .contradiction })
    }

    func testTautology() {
        // p || !p is a tautology
        let tautology = p || !p
        let warnings = tautology.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .tautology })
    }

    func testRedundantConjunction() {
        // p && p is redundant
        let redundant = p && p
        let warnings = redundant.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .redundancy })
    }

    func testVacuousImplication() {
        // false ==> p is always true
        let vacuous = Formula.booleanLiteral(false) ==> p
        let warnings = vacuous.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .tautology })
    }

    func testRedundantEventually() {
        // F(F(p)) can be simplified to F(p)
        let redundant = Formula.F(Formula.F(p))
        let warnings = redundant.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .redundancy })
    }

    func testRedundantGlobally() {
        // G(G(p)) can be simplified to G(p)
        let redundant = Formula.G(Formula.G(p))
        let warnings = redundant.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .redundancy })
    }

    func testImmediateUntil() {
        // p U true is immediately satisfied
        let immediate = p ~>> .booleanLiteral(true)
        let warnings = immediate.validate()

        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.type == .redundancy })
    }

    // MARK: - Semantic Equivalence Tests

    func testSemanticEquivalence() {
        // Test commutativity
        let andFormula1 = p && q
        let andFormula2 = q && p
        XCTAssertTrue(andFormula1.semanticallyEquivalent(to: andFormula2))

        let orFormula1 = p || q
        let orFormula2 = q || p
        XCTAssertTrue(orFormula1.semanticallyEquivalent(to: orFormula2))

        // Test double negation elimination
        let doubleNeg = !(!p)
        XCTAssertTrue(doubleNeg.semanticallyEquivalent(to: p))

        // Test identity laws
        let andTrue = p && .booleanLiteral(true)
        XCTAssertTrue(andTrue.semanticallyEquivalent(to: p))

        let orFalse = p || .booleanLiteral(false)
        XCTAssertTrue(orFalse.semanticallyEquivalent(to: p))

        // Test idempotent laws
        let andSelf = p && p
        XCTAssertTrue(andSelf.semanticallyEquivalent(to: p))

        let orSelf = p || p
        XCTAssertTrue(orSelf.semanticallyEquivalent(to: p))

        // Test nested temporal operators
        let nestedF = Formula.F(Formula.F(p))
        let singleF = Formula.F(p)
        XCTAssertTrue(nestedF.semanticallyEquivalent(to: singleF))

        let nestedG = Formula.G(Formula.G(p))
        let singleG = Formula.G(p)
        XCTAssertTrue(nestedG.semanticallyEquivalent(to: singleG))
    }

    func testNonEquivalentFormulas() {
        // These should NOT be equivalent
        XCTAssertFalse(p.semanticallyEquivalent(to: q))
        XCTAssertFalse((p && q).semanticallyEquivalent(to: (p || q)))
        XCTAssertFalse(Formula.F(p).semanticallyEquivalent(to: Formula.G(p)))
        XCTAssertFalse((p ~>> q).semanticallyEquivalent(to: (q ~>> p)))
    }

    // MARK: - Validation Configuration Tests

    func testValidationConfiguration() {
        // Create a deeply nested formula
        var deepFormula = p
        for _ in 0..<60 {
            deepFormula = Formula.F(deepFormula)
        }

        // Basic validation shouldn't warn about depth
        let basicWarnings = deepFormula.validate(configuration: .default)
        XCTAssertTrue(basicWarnings.allSatisfy { $0.type != .performance })

        // Thorough validation should warn about depth
        let thoroughWarnings = deepFormula.validate(configuration: .thorough)
        XCTAssertTrue(thoroughWarnings.contains { $0.type == .performance })
    }

    // MARK: - Pretty Print Tests

    func testPrettyPrintInfix() {
        let formula = p && q ==> Formula.F(r)
        let infix = formula.prettyPrint(style: .infix)
        XCTAssertTrue(infix.contains("∧"))
        XCTAssertTrue(infix.contains("→"))
        XCTAssertTrue(infix.contains("F"))
    }

    func testPrettyPrintPrefix() {
        let formula = p && q
        let prefix = formula.prettyPrint(style: .prefix)
        XCTAssertTrue(prefix.contains("AND"))
        XCTAssertTrue(prefix.contains("p"))
        XCTAssertTrue(prefix.contains("q"))
    }

    func testPrettyPrintTree() {
        let formula = p || q
        let tree = formula.prettyPrint(style: .tree)
        XCTAssertTrue(tree.contains("└─"))
        XCTAssertTrue(tree.contains("OR"))
    }

    // MARK: - Complex Validation Tests

    func testComplexFormulaValidation() {
        // Create a formula with multiple issues
        let complex = Formula.G(Formula.G(p && p)) || !(!q)
        let warnings = complex.validate()

        // Should have warnings for:
        // 1. Nested globally
        // 2. Redundant conjunction (p && p)
        // 3. Double negation
        XCTAssertGreaterThanOrEqual(warnings.count, 3)
    }

    func testValidFormula() {
        // A well-formed formula should have no warnings
        let wellFormed = Formula.G(p ==> Formula.F(q))
        let warnings = wellFormed.validate()

        XCTAssertTrue(warnings.isEmpty)
    }
}

// MARK: - Test Helpers

class DSLTestProposition: TemporalProposition {
    let id: PropositionID
    let name: String
    typealias Value = Bool

    init(_ name: String) {
        self.id = PropositionID(rawValue: name)!
        self.name = name
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        // For DSL tests, we don't need actual evaluation
        false
    }
}
