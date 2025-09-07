import Testing
import Foundation
@testable import CoreNostr

@Suite("Property-Based Tests: Invariants and Round-trips")
struct PropertyTests {
    
    // MARK: - Test Utilities
    
    /// Generates random hex string of specified length
    private func randomHex(length: Int) -> String {
        let chars = "0123456789abcdef"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    /// Generates random valid public key
    private func randomPublicKey() -> String {
        return randomHex(length: 64)
    }
    
    /// Generates random valid event ID
    private func randomEventId() -> String {
        return randomHex(length: 64)
    }
    
    /// Generates random valid signature
    private func randomSignature() -> String {
        return randomHex(length: 128)
    }
    
    /// Generates random string with various Unicode characters
    private func randomUnicodeString(maxLength: Int = 100) -> String {
        let length = Int.random(in: 1...maxLength)
        let ranges: [ClosedRange<UInt32>] = [
            0x0020...0x007E, // Basic Latin
            0x00A0...0x00FF, // Latin-1 Supplement
            0x0100...0x017F, // Latin Extended-A
            0x0400...0x04FF, // Cyrillic
            0x4E00...0x9FFF, // CJK Unified Ideographs
            0x1F300...0x1F6FF // Emoji
        ]
        
        return String((0..<length).compactMap { _ in
            let range = ranges.randomElement()!
            let scalar = UInt32.random(in: range)
            return Unicode.Scalar(scalar).map(Character.init)
        })
    }
    
    // MARK: - Bech32 Property Tests
    
    @Test("Bech32 npub round-trip property", arguments: 1...100)
    func testBech32NpubRoundTrip(_ iteration: Int) throws {
        // Property: For any valid public key, encoding to npub and decoding should return the original
        let pubkey = randomPublicKey()
        
        let entity = Bech32Entity.npub(pubkey)
        let encoded = try entity.encoded
        let decoded = try Bech32Entity(from: encoded)
        
        guard case .npub(let decodedPubkey) = decoded else {
            Issue.record("Failed to decode as npub")
            return
        }
        
        #expect(decodedPubkey.lowercased() == pubkey.lowercased())
    }
    
    @Test("Bech32 nsec round-trip property", arguments: 1...100)
    func testBech32NsecRoundTrip(_ iteration: Int) throws {
        // Property: For any valid private key, encoding to nsec and decoding should return the original
        let privkey = randomHex(length: 64)
        
        let entity = Bech32Entity.nsec(privkey)
        let encoded = try entity.encoded
        let decoded = try Bech32Entity(from: encoded)
        
        guard case .nsec(let decodedPrivkey) = decoded else {
            Issue.record("Failed to decode as nsec")
            return
        }
        
        #expect(decodedPrivkey.lowercased() == privkey.lowercased())
    }
    
    @Test("Bech32 note round-trip property", arguments: 1...100)
    func testBech32NoteRoundTrip(_ iteration: Int) throws {
        // Property: For any valid event ID, encoding to note and decoding should return the original
        let eventId = randomEventId()
        
        let entity = Bech32Entity.note(eventId)
        let encoded = try entity.encoded
        let decoded = try Bech32Entity(from: encoded)
        
        guard case .note(let decodedEventId) = decoded else {
            Issue.record("Failed to decode as note")
            return
        }
        
        #expect(decodedEventId.lowercased() == eventId.lowercased())
    }
    
    @Test("Bech32 nprofile round-trip with random relay counts", arguments: 0...10)
    func testBech32NprofileRoundTripRelays(_ relayCount: Int) throws {
        // Property: nprofile with any number of relays should round-trip correctly
        let pubkey = randomPublicKey()
        let relays = (0..<relayCount).map { "wss://relay\($0).example.com" }
        
        let profile = try NProfile(pubkey: pubkey, relays: relays)
        let entity = Bech32Entity.nprofile(profile)
        let encoded = try entity.encoded
        let decoded = try Bech32Entity(from: encoded)
        
        guard case .nprofile(let decodedProfile) = decoded else {
            Issue.record("Failed to decode as nprofile")
            return
        }
        
        #expect(decodedProfile.pubkey.lowercased() == pubkey.lowercased())
        #expect(decodedProfile.relays == relays)
    }
    
    @Test("Bech32 encoding determinism property")
    func testBech32EncodingDeterminism() throws {
        // Property: Encoding the same entity multiple times produces identical results
        let pubkey = randomPublicKey()
        let entity = Bech32Entity.npub(pubkey)
        
        let encodings = try (0..<10).map { _ in try entity.encoded }
        
        // All encodings should be identical
        let firstEncoding = encodings[0]
        for encoding in encodings {
            #expect(encoding == firstEncoding)
        }
    }
    
    // MARK: - Event Serialization Property Tests
    
    @Test("Event ID calculation determinism", arguments: 1...100)
    func testEventIdDeterminism(_ iteration: Int) throws {
        // Property: Same event data always produces same ID
        let event = NostrEvent(
            pubkey: randomPublicKey(),
            createdAt: Date(timeIntervalSince1970: Double(Int.random(in: 1000000000...2000000000))),
            kind: Int.random(in: 0...65535),
            tags: (0..<Int.random(in: 0...5)).map { _ in
                ["tag", randomHex(length: 20)]
            },
            content: randomUnicodeString()
        )
        
        let id1 = event.calculateId()
        let id2 = event.calculateId()
        let id3 = event.calculateId()
        
        #expect(id1 == id2)
        #expect(id2 == id3)
    }
    
    @Test("Event serialization stability", arguments: 1...100)
    func testEventSerializationStability(_ iteration: Int) throws {
        // Property: Serialization format is stable across multiple calls
        let event = NostrEvent(
            pubkey: randomPublicKey(),
            createdAt: Date(timeIntervalSince1970: 1700000000),
            kind: 1,
            tags: [["e", randomEventId()], ["p", randomPublicKey()]],
            content: "Test content #\(iteration)"
        )
        
        let serialized1 = event.serializedForSigning()
        let serialized2 = event.serializedForSigning()
        
        #expect(serialized1 == serialized2)
        
        // ID should be consistent with serialization
        let id1 = event.calculateId()
        let id2 = event.calculateId()
        #expect(id1 == id2)
    }
    
    @Test("Event JSON round-trip property", arguments: 1...50)
    func testEventJSONRoundTrip(_ iteration: Int) throws {
        // Property: Events can be encoded to JSON and decoded back
        let originalEvent = try NostrEvent(
            id: randomEventId(),
            pubkey: randomPublicKey(),
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: Int.random(in: 0...100),
            tags: (0..<Int.random(in: 0...3)).map { _ in
                ["tag", randomHex(length: 16)]
            },
            content: "Content \(iteration)",
            sig: randomSignature()
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(originalEvent)
        
        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(NostrEvent.self, from: jsonData)
        
        #expect(decodedEvent.id == originalEvent.id)
        #expect(decodedEvent.pubkey == originalEvent.pubkey)
        #expect(decodedEvent.createdAt == originalEvent.createdAt)
        #expect(decodedEvent.kind == originalEvent.kind)
        #expect(decodedEvent.tags == originalEvent.tags)
        #expect(decodedEvent.content == originalEvent.content)
        #expect(decodedEvent.sig == originalEvent.sig)
    }
    
    @Test("Event signing preserves all fields")
    func testEventSigningPreservesFields() throws {
        // Property: Signing an event preserves all original fields except id and sig
        let keyPair = try KeyPair.generate()
        
        let unsignedEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: 1,
            tags: [["t", "test"], ["p", randomPublicKey()]],
            content: "Test content with special chars: 🚀 你好 مرحبا"
        )
        
        let signedEvent = try keyPair.signEvent(unsignedEvent)
        
        // All fields except id and sig should match
        #expect(signedEvent.pubkey == unsignedEvent.pubkey)
        #expect(signedEvent.createdAt == unsignedEvent.createdAt)
        #expect(signedEvent.kind == unsignedEvent.kind)
        #expect(signedEvent.tags == unsignedEvent.tags)
        #expect(signedEvent.content == unsignedEvent.content)
        
        // id and sig should be populated
        #expect(!signedEvent.id.isEmpty)
        #expect(!signedEvent.sig.isEmpty)
        #expect(signedEvent.id.count == 64)
        #expect(signedEvent.sig.count == 128)
    }
    
    // MARK: - Filter Matching Property Tests
    
    @Test("Filter kind matching property")
    func testFilterKindMatching() throws {
        // Property: Events match filters only if their kind is in the filter's kinds array
        let kinds = [1, 3, 7]
        let filter = Filter(kinds: kinds)
        
        // Should match
        for kind in kinds {
            let event = NostrEvent(
                pubkey: randomPublicKey(),
                createdAt: Date(),
                kind: kind,
                tags: [],
                content: "Test"
            )
            #expect(eventMatchesFilter(event, filter))
        }
        
        // Should not match
        for kind in [0, 2, 4, 5, 6, 8, 100] {
            let event = NostrEvent(
                pubkey: randomPublicKey(),
                createdAt: Date(),
                kind: kind,
                tags: [],
                content: "Test"
            )
            #expect(!eventMatchesFilter(event, filter))
        }
    }
    
    @Test("Filter author matching property")
    func testFilterAuthorMatching() throws {
        // Property: Events match filters only if their author is in the filter's authors array
        let authors = [randomPublicKey(), randomPublicKey(), randomPublicKey()]
        let filter = Filter(authors: authors)
        
        // Should match
        for author in authors {
            let event = NostrEvent(
                pubkey: author,
                createdAt: Date(),
                kind: 1,
                tags: [],
                content: "Test"
            )
            #expect(eventMatchesFilter(event, filter))
        }
        
        // Should not match
        let otherAuthor = randomPublicKey()
        let event = NostrEvent(
            pubkey: otherAuthor,
            createdAt: Date(),
            kind: 1,
            tags: [],
            content: "Test"
        )
        #expect(!eventMatchesFilter(event, filter))
    }
    
    @Test("Filter time range property")
    func testFilterTimeRange() throws {
        // Property: Events match filters only if created within since/until range
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        
        let filter = Filter(
            since: yesterday,
            until: tomorrow
        )
        
        // Should match (within range)
        let eventInRange = NostrEvent(
            pubkey: randomPublicKey(),
            createdAt: now,
            kind: 1,
            tags: [],
            content: "Test"
        )
        #expect(eventMatchesFilter(eventInRange, filter))
        
        // Should not match (too old)
        let oldEvent = NostrEvent(
            pubkey: randomPublicKey(),
            createdAt: yesterday.addingTimeInterval(-3600),
            kind: 1,
            tags: [],
            content: "Test"
        )
        #expect(!eventMatchesFilter(oldEvent, filter))
        
        // Should not match (too new)
        let futureEvent = NostrEvent(
            pubkey: randomPublicKey(),
            createdAt: tomorrow.addingTimeInterval(3600),
            kind: 1,
            tags: [],
            content: "Test"
        )
        #expect(!eventMatchesFilter(futureEvent, filter))
    }
    
    @Test("Filter empty criteria matches all property")
    func testFilterEmptyCriteriaMatchesAll() throws {
        // Property: A filter with no criteria matches all events
        let emptyFilter = Filter()
        
        // Generate random events
        for _ in 0..<10 {
            let event = NostrEvent(
                pubkey: randomPublicKey(),
                createdAt: Date(timeIntervalSince1970: Double(Int.random(in: 1000000000...2000000000))),
                kind: Int.random(in: 0...100),
                tags: [],
                content: randomUnicodeString()
            )
            #expect(eventMatchesFilter(event, emptyFilter))
        }
    }
    
    // MARK: - Helper Functions
    
    /// Simple filter matching logic for testing
    private func eventMatchesFilter(_ event: NostrEvent, _ filter: Filter) -> Bool {
        // Check kinds
        if let kinds = filter.kinds, !kinds.contains(event.kind) {
            return false
        }
        
        // Check authors
        if let authors = filter.authors, !authors.contains(event.pubkey) {
            return false
        }
        
        // Check time range
        let timestamp = event.createdAt
        if let since = filter.since, timestamp < since {
            return false
        }
        if let until = filter.until, timestamp > until {
            return false
        }
        
        // Check event IDs
        if let ids = filter.ids, !ids.contains(event.id) {
            return false
        }
        
        // Check e tags
        if let eTags = filter.e {
            let eventETags = event.tags.filter { $0.first == "e" }.compactMap { $0[safe: 1] }
            if !eTags.contains(where: { eventETags.contains($0) }) {
                return false
            }
        }
        
        // Check p tags
        if let pTags = filter.p {
            let eventPTags = event.tags.filter { $0.first == "p" }.compactMap { $0[safe: 1] }
            if !pTags.contains(where: { eventPTags.contains($0) }) {
                return false
            }
        }
        
        return true
    }
}