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
    
    @Test("Cross-verify with rust-nostr test vector")
    func testRustNostrCompatibility() throws {
        // Test vector from rust-nostr implementation
        // https://github.com/rust-nostr/nostr/blob/master/crates/nostr/src/event/mod.rs
        let pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let createdAt: Int64 = 1671588354
        let kind = 1
        let tags: [[String]] = []
        let content = "GM"
        
        let unsigned = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: tags,
            content: content
        )
        
        let serialized = unsigned.serializedForSigning()
        let expectedSerialized = "[0,\"79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798\",1671588354,1,[],\"GM\"]"
        #expect(serialized == expectedSerialized)
        
        let calculatedId = unsigned.calculateId()
        let expectedId = "4376c65d2f232afbe9b882a35baa4f6fe8667c4e684749af565f981833ed6a65"
        #expect(calculatedId == expectedId)
    }
    
    @Test("Serialization handles special characters correctly")
    func testSpecialCharacterHandling() throws {
        let pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let createdAt: Int64 = 1671588354
        let kind = 1
        
        // Test with various special characters that need JSON escaping
        let testCases = [
            ("Content with \"quotes\"", "Content with \\\"quotes\\\""),
            ("Content with\nnewline", "Content with\\nnewline"),
            ("Content with\ttab", "Content with\\ttab"),
            ("Content with\\backslash", "Content with\\\\backslash"),
            ("Unicode: 🚀 emoji", "Unicode: 🚀 emoji"), // Emojis should pass through
            ("Unicode: 你好", "Unicode: 你好") // Chinese characters
        ]
        
        for (input, expectedEscaped) in testCases {
            let event = NostrEvent(
                pubkey: pubkey,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
                kind: kind,
                tags: [],
                content: input
            )
            
            let serialized = event.serializedForSigning()
            let expected = "[0,\"\(pubkey)\",\(createdAt),\(kind),[],\"\(expectedEscaped)\"]"
            #expect(serialized == expected)
        }
    }
    
    @Test("Serialization handles complex tag structures")
    func testComplexTagSerialization() throws {
        let pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let createdAt: Int64 = 1671588354
        let kind = 1
        
        // Complex tag structure with multiple elements
        let tags = [
            ["e", "event123", "wss://relay.example.com", "reply"],
            ["p", "pubkey456"],
            ["t", "nostr"],
            ["nonce", "42", "16"]
        ]
        
        let event = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: tags,
            content: "Test"
        )
        
        let serialized = event.serializedForSigning()
        
        // Verify structure contains proper JSON array formatting
        #expect(serialized.contains("[[\"e\",\"event123\",\"wss://relay.example.com\",\"reply\"],[\"p\",\"pubkey456\"],[\"t\",\"nostr\"],[\"nonce\",\"42\",\"16\"]]"))
    }
    
    @Test("Event ID calculation is deterministic")
    func testEventIdDeterminism() throws {
        let pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let createdAt: Int64 = 1671588354
        let kind = 1
        let tags = [["e", "test"]]
        let content = "Determinism test"
        
        let event1 = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: tags,
            content: content
        )
        
        let event2 = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: tags,
            content: content
        )
        
        let id1 = event1.calculateId()
        let id2 = event2.calculateId()
        
        #expect(id1 == id2)
    }
    
    @Test("Empty content and tags serialization")
    func testEmptyFieldsSerialization() throws {
        let pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let createdAt: Int64 = 1671588354
        let kind = 0
        
        let event = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: [],
            content: ""
        )
        
        let serialized = event.serializedForSigning()
        let expected = "[0,\"\(pubkey)\",\(createdAt),\(kind),[],\"\"]"
        
        #expect(serialized == expected)
    }
    
    @Test("Large timestamp handling")
    func testLargeTimestampHandling() throws {
        let pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let createdAt: Int64 = 9999999999 // Far future timestamp
        let kind = 1
        
        let event = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            kind: kind,
            tags: [],
            content: "Future event"
        )
        
        let serialized = event.serializedForSigning()
        #expect(serialized.contains("\(createdAt)"))
        
        let id = event.calculateId()
        #expect(id.count == 64)
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

