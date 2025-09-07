import Testing
import Foundation
import CryptoKit
@testable import CoreNostr

@Suite("NIP-01: Canonical Serialization and Event ID")
struct NIP01CanonicalTests {

    @Test("Canonical serializedForSigning matches expected JSON array")
    func testCanonicalSerializationString() throws {
        // Fixed values for determinism
        let pubkey = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let createdAt: Int64 = 1_700_000_000
        let kind = 1
        let tags = [["e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
                    ["p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"]]
        let content = "Hello, NOSTR!"

        let unsigned = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: tags,
            content: content
        )

        let serialized = unsigned.serializedForSigning()

        // Expected exact JSON array string per NIP-01: [0, pubkey, created_at, kind, tags, content]
        let expected = "[0,\"\(pubkey)\",\(createdAt),\(kind),\(try jsonString(tags)),\"\(content)\"]"

        #expect(serialized == expected)
    }

    @Test("Event ID hashing equals SHA256 over canonical JSON")
    func testEventIdHashingKnownVector() throws {
        // Same fixed event as above
        let pubkey = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let createdAt: Int64 = 1_700_000_000
        let kind = 1
        let tags = [["e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
                    ["p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"]]
        let content = "Hello, NOSTR!"

        let unsigned = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: tags,
            content: content
        )

        let serialized = unsigned.serializedForSigning()

        // Compute expected hash using CryptoKit independently
        let data = Data(serialized.utf8)
        let digest = SHA256.hash(data: data)
        let expectedId = digest.map { String(format: "%02x", $0) }.joined()

        let calculatedId = unsigned.calculateId()
        #expect(calculatedId == expectedId)
        #expect(calculatedId.count == 64)
    }
}

// Helper to turn a value into a compact JSON string with stable ordering for arrays
private func jsonString(_ value: Any) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.withoutEscapingSlashes])
    guard let string = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "NIP01CanonicalTests", code: 1)
    }
    return string
}

