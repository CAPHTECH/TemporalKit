import Foundation
import Testing
@testable import TemporalKit

struct PropositionIDTests {

    @Test
    func testValidPropositionID() {
        let id = PropositionID(rawValue: "validID")!
        #expect(id.rawValue == "validID")

        let id2 = PropositionID("anotherValidID")!
        #expect(id2.rawValue == "anotherValidID")
    }

    @Test
    func testPropositionIDEquality() {
        let id1 = PropositionID("testID")!
        let id2 = PropositionID("testID")!
        let id3 = PropositionID("differentID")!

        #expect(id1 == id2)
        #expect(id1 != id3)
    }

    @Test
    func testPropositionIDHashable() {
        let id1 = PropositionID("testID")!
        let id2 = PropositionID("testID")!
        let id3 = PropositionID("differentID")!

        var set = Set<PropositionID>()
        set.insert(id1)
        set.insert(id2)
        set.insert(id3)

        #expect(set.count == 2)
        #expect(set.contains(id1))
        #expect(set.contains(id3))
    }

    @Test
    func testPropositionIDCodable() throws {
        let id = PropositionID("codableID")!

        let encoder = JSONEncoder()
        let data = try encoder.encode(id)

        let decoder = JSONDecoder()
        let decodedID = try decoder.decode(PropositionID.self, from: data)

        #expect(id == decodedID)
        #expect(id.rawValue == decodedID.rawValue)
    }
}
