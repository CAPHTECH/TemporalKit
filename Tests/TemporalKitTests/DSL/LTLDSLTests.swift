import Testing
import Foundation // Added for UUID
@testable import TemporalKit // Allows access to internal types if needed, and public ones

// MARK: - Mocks and Helpers for DSL Tests

/// A simple mock proposition for DSL testing.
/// It doesn't need real evaluation logic for DSL structure tests.
final class MockProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = PropositionID(rawValue: id)!
        self.name = name
    }

    // Evaluation is not strictly needed for DSL construction tests,
    // but the protocol requires it.
    func evaluate(in context: EvaluationContext) throws -> Bool {
        // For DSL tests, we're not evaluating, so we can return a dummy value
        // or throw if it's unexpectedly called.
        // Consider fatalError if this should never be called in DSL unit tests.
        print("Warning: MockProposition.evaluate() called during DSL test. This might indicate an issue if evaluation was not expected.")
        return false
    }

    // Hashable and Equatable conformance (provided by TemporalProposition default implementation via ID)
}

// MARK: - LTL DSL Tests

// Changed from XCTestCase class to a struct, or could be top-level functions.
// Using a struct for grouping tests similar to XCTestCase.
struct LTLDSLTests {

    @Test // Added @Test attribute
    func testNotOperator() {
        let p = MockProposition(name: "p")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)

        let notP = !atomicP

        // Using #expect for assertion
        switch notP {
        case .not(let innerFormula):
            #expect(innerFormula == atomicP, "The inner formula of .not should be the original atomic proposition.")
        default:
            // Using #expect(Bool(false), ...) for failure, similar to XCTFail
            #expect(Bool(false), "The NOT operator did not produce an LTLFormula.not case. Got: \(notP)")
        }
    }

    @Test
    func testAndOperator() {
        let p = MockProposition(name: "p")
        let q = MockProposition(name: "q")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)
        let atomicQ: LTLFormula<MockProposition> = .atomic(q)

        let pAndQ = atomicP && atomicQ

        switch pAndQ {
        case .and(let lhs, let rhs):
            #expect(lhs == atomicP, "LHS of .and should be the first atomic proposition.")
            #expect(rhs == atomicQ, "RHS of .and should be the second atomic proposition.")
        default:
            #expect(Bool(false), "The AND operator did not produce an LTLFormula.and case. Got: \(pAndQ)")
        }
    }

    @Test
    func testOrOperator() {
        let p = MockProposition(name: "p")
        let q = MockProposition(name: "q")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)
        let atomicQ: LTLFormula<MockProposition> = .atomic(q)

        let pOrQ = atomicP || atomicQ

        switch pOrQ {
        case .or(let lhs, let rhs):
            #expect(lhs == atomicP, "LHS of .or should be the first atomic proposition.")
            #expect(rhs == atomicQ, "RHS of .or should be the second atomic proposition.")
        default:
            #expect(Bool(false), "The OR operator did not produce an LTLFormula.or case. Got: \(pOrQ)")
        }
    }

    @Test
    func testImpliesOperator() {
        let p = MockProposition(name: "p")
        let q = MockProposition(name: "q")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)
        let atomicQ: LTLFormula<MockProposition> = .atomic(q)

        let pImpliesQ = atomicP ==> atomicQ

        switch pImpliesQ {
        case .implies(let lhs, let rhs):
            #expect(lhs == atomicP, "LHS of .implies should be the first atomic proposition.")
            #expect(rhs == atomicQ, "RHS of .implies should be the second atomic proposition.")
        default:
            #expect(Bool(false), "The IMPLIES operator (==>) did not produce an LTLFormula.implies case. Got: \(pImpliesQ)")
        }
    }

    // MARK: - Temporal Operator Tests

    @Test
    func testNextOperator() {
        let p = MockProposition(name: "p")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)

        let nextP = LTLFormula.X(atomicP)

        switch nextP {
        case .next(let innerFormula):
            #expect(innerFormula == atomicP, "The inner formula of .next should be the original atomic proposition.")
        default:
            #expect(Bool(false), "The Next operator (X) did not produce an LTLFormula.next case. Got: \(nextP)")
        }
    }

    @Test
    func testEventuallyOperator() {
        let p = MockProposition(name: "p")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)

        let eventuallyP = LTLFormula.F(atomicP)

        switch eventuallyP {
        case .eventually(let innerFormula):
            #expect(innerFormula == atomicP, "The inner formula of .eventually should be the original atomic proposition.")
        default:
            #expect(Bool(false), "The Eventually operator (F) did not produce an LTLFormula.eventually case. Got: \(eventuallyP)")
        }
    }

    @Test
    func testGloballyOperator() {
        let p = MockProposition(name: "p")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)

        let globallyP = LTLFormula.G(atomicP)

        switch globallyP {
        case .globally(let innerFormula):
            #expect(innerFormula == atomicP, "The inner formula of .globally should be the original atomic proposition.")
        default:
            #expect(Bool(false), "The Globally operator (G) did not produce an LTLFormula.globally case. Got: \(globallyP)")
        }
    }

    @Test
    func testUntilOperator() {
        let p = MockProposition(name: "p")
        let q = MockProposition(name: "q")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)
        let atomicQ: LTLFormula<MockProposition> = .atomic(q)

        let pUntilQ = atomicP ~>> atomicQ

        switch pUntilQ {
        case .until(let lhs, let rhs):
            #expect(lhs == atomicP, "LHS of .until should be the first atomic proposition.")
            #expect(rhs == atomicQ, "RHS of .until should be the second atomic proposition.")
        default:
            #expect(Bool(false), "The Until operator (~>>) did not produce an LTLFormula.until case. Got: \(pUntilQ)")
        }
    }

    @Test
    func testWeakUntilOperator() {
        let p = MockProposition(name: "p")
        let q = MockProposition(name: "q")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)
        let atomicQ: LTLFormula<MockProposition> = .atomic(q)

        let pWeakUntilQ = atomicP ~~> atomicQ

        switch pWeakUntilQ {
        case .weakUntil(let lhs, let rhs):
            #expect(lhs == atomicP, "LHS of .weakUntil should be the first atomic proposition.")
            #expect(rhs == atomicQ, "RHS of .weakUntil should be the second atomic proposition.")
        default:
            #expect(Bool(false), "The Weak Until operator (~~>) did not produce an LTLFormula.weakUntil case. Got: \(pWeakUntilQ)")
        }
    }

    @Test
    func testReleaseOperator() {
        let p = MockProposition(name: "p")
        let q = MockProposition(name: "q")
        let atomicP: LTLFormula<MockProposition> = .atomic(p)
        let atomicQ: LTLFormula<MockProposition> = .atomic(q)

        let pReleaseQ = atomicP ~< atomicQ

        switch pReleaseQ {
        case .release(let lhs, let rhs):
            #expect(lhs == atomicP, "LHS of .release should be the first atomic proposition.")
            #expect(rhs == atomicQ, "RHS of .release should be the second atomic proposition.")
        default:
            #expect(Bool(false), "The Release operator (~<) did not produce an LTLFormula.release case. Got: \(pReleaseQ)")
        }
    }

    // MARK: - Boolean Literal Tests

    @Test
    func testTrueBooleanLiteral() {
        let trueLiteral = LTLFormula<MockProposition>.true

        switch trueLiteral {
        case .booleanLiteral(let value):
            #expect(value == true, "LTLFormula.true should produce .booleanLiteral(true).")
        default:
            #expect(Bool(false), "LTLFormula.true did not produce a .booleanLiteral. Got: \(trueLiteral)")
        }
    }

    @Test
    func testFalseBooleanLiteral() {
        let falseLiteral = LTLFormula<MockProposition>.false

        switch falseLiteral {
        case .booleanLiteral(let value):
            #expect(value == false, "LTLFormula.false should produce .booleanLiteral(false).")
        default:
            #expect(Bool(false), "LTLFormula.false did not produce a .booleanLiteral. Got: \(falseLiteral)")
        }
    }
}
