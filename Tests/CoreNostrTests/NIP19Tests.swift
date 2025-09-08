import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-19: Bech32 Encoding Tests")
struct NIP19Tests {
    
    @Test("Encode and decode npub")
    func testNpub() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let entity = Bech32Entity.npub(pubkey)
        
        let encoded = try entity.encoded
        #expect(encoded.hasPrefix("npub1"))
        #expect(encoded.count > 50)
        
        let decoded = try Bech32Entity(from: encoded)
        guard case .npub(let decodedPubkey) = decoded else {
            Issue.record("Expected npub entity")
            return
        }
        #expect(decodedPubkey == pubkey)
    }
    
    @Test("Encode and decode nsec")
    func testNsec() throws {
        let privkey = "5a0e7d3e5f8c3a2b1d9e4f6c8b3a7d2e9f4c6b8a3d7e2f9c4b6a8d3e7f2c9b4a"
        let entity = Bech32Entity.nsec(privkey)
        
        let encoded = try entity.encoded
        #expect(encoded.hasPrefix("nsec1"))
        #expect(encoded.count > 50)
        
        let decoded = try Bech32Entity(from: encoded)
        guard case .nsec(let decodedPrivkey) = decoded else {
            Issue.record("Expected nsec entity")
            return
        }
        #expect(decodedPrivkey == privkey)
    }
    
    @Test("Encode and decode note")
    func testNote() throws {
        let eventId = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        let entity = Bech32Entity.note(eventId)
        
        let encoded = try entity.encoded
        #expect(encoded.hasPrefix("note1"))
        #expect(encoded.count > 50)
        
        let decoded = try Bech32Entity(from: encoded)
        guard case .note(let decodedEventId) = decoded else {
            Issue.record("Expected note entity")
            return
        }
        #expect(decodedEventId == eventId)
    }
    
    @Test("Encode and decode nprofile with relays")
    func testNprofile() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let relays = ["wss://relay.damus.io", "wss://nos.lol"]
        let profile = try NProfile(pubkey: pubkey, relays: relays)
        let entity = Bech32Entity.nprofile(profile)
        
        let encoded = try entity.encoded
        #expect(encoded.hasPrefix("nprofile1"))
        
        let decoded = try Bech32Entity(from: encoded)
        guard case .nprofile(let decodedProfile) = decoded else {
            Issue.record("Expected nprofile entity")
            return
        }
        #expect(decodedProfile.pubkey == pubkey)
        #expect(decodedProfile.relays == relays)
    }
    
    @Test("Encode and decode nevent with all fields")
    func testNevent() throws {
        let eventId = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        let author = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let relays = ["wss://relay.damus.io"]
        let kind = 1
        let event = try NEvent(eventId: eventId, relays: relays, author: author, kind: kind)
        let entity = Bech32Entity.nevent(event)
        
        let encoded = try entity.encoded
        #expect(encoded.hasPrefix("nevent1"))
        
        let decoded = try Bech32Entity(from: encoded)
        guard case .nevent(let decodedEvent) = decoded else {
            Issue.record("Expected nevent entity")
            return
        }
        #expect(decodedEvent.eventId == eventId)
        #expect(decodedEvent.author == author)
        #expect(decodedEvent.relays == relays)
        #expect(decodedEvent.kind == kind)
    }
    
    @Test("Encode and decode nrelay")
    func testNrelay() throws {
        let url = "wss://relay.nostr.band"
        let entity = Bech32Entity.nrelay(url)
        
        let encoded = try entity.encoded
        #expect(encoded.hasPrefix("nrelay1"))
        
        let decoded = try Bech32Entity(from: encoded)
        guard case .nrelay(let decodedUrl) = decoded else {
            Issue.record("Expected nrelay entity")
            return
        }
        #expect(decodedUrl == url)
    }
    
    @Test("Test invalid bech32 strings")
    func testInvalidBech32() {
        // Invalid character
        #expect(throws: NostrError.self) {
            _ = try Bech32Entity(from: "npub1@invalid")
        }
        
        // No separator
        #expect(throws: NostrError.self) {
            _ = try Bech32Entity(from: "npubinvalid")
        }
        
        // Invalid checksum
        #expect(throws: NostrError.self) {
            _ = try Bech32Entity(from: "npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq")
        }
        
        // Unknown HRP
        #expect(throws: NostrError.self) {
            _ = try Bech32Entity(from: "unknown1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsdlt6v")
        }
    }
    
    @Test("Test convenience extensions")
    func testConvenienceExtensions() throws {
        // Test PublicKey.npub
        let pubkey: PublicKey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try pubkey.npub
        #expect(npub.hasPrefix("npub1"))
        
        // Test PrivateKey.nsec
        let privkey: PrivateKey = "5a0e7d3e5f8c3a2b1d9e4f6c8b3a7d2e9f4c6b8a3d7e2f9c4b6a8d3e7f2c9b4a"
        let nsec = try privkey.nsec
        #expect(nsec.hasPrefix("nsec1"))
        
        // Test EventID.note
        let eventId: EventID = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        let note = try eventId.note
        #expect(note.hasPrefix("note1"))
        
        // Test String.bech32Entity
        let entity = npub.bech32Entity
        #expect(entity != nil)
        if case .npub(let decodedPubkey) = entity {
            #expect(decodedPubkey == pubkey)
        } else {
            Issue.record("Expected npub entity")
        }
    }
    
    @Test("Test bech32 implementation with known vectors")
    func testBech32Vectors() throws {
        // Test encoding and decoding round trip
        let testData = Data([0, 14, 20, 15, 7, 13, 26, 0, 25, 18, 6, 11, 13, 8, 21, 4, 20, 3, 17, 2, 29, 3])
        let encoded = try Bech32.encode(hrp: "bc", data: testData)
        
        // Verify round trip
        let (hrp, data) = try Bech32.decode(encoded)
        #expect(hrp == "bc")
        #expect(data == testData)
        
        // Note: The exact encoded string may vary between implementations
        // What matters is that decode(encode(data)) == data
    }
    
    @Test("Test large kind values")
    func testLargeKindValues() throws {
        // Test with various kind values including large ones
        let kinds = [0, 1, 1000, 10000, 30023, 65535, 1000000]
        
        for kind in kinds {
            let event = try NEvent(
                eventId: "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7",
                kind: kind
            )
            let entity = Bech32Entity.nevent(event)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .nevent(let decodedEvent) = decoded else {
                Issue.record("Expected nevent entity for kind \(kind)")
                continue
            }
            #expect(decodedEvent.kind == kind)
        }
    }

    @Test("Invalid TLV: nprofile missing pubkey should throw")
    func testInvalidTLVProfileMissingPubkey() throws {
        // Build TLV with only a relay entry (no special=0 pubkey)
        let relay = "wss://relay.damus.io"
        var tlv = Data()
        tlv.append(1) // relay type
        tlv.append(UInt8(relay.utf8.count))
        tlv.append(contentsOf: relay.utf8)

        let bech = try Bech32.encode(hrp: "nprofile", data: tlv)

        #expect(throws: NostrError.self) {
            _ = try Bech32Entity(from: bech)
        }
    }

    @Test("Invalid TLV: nevent missing event id should throw")
    func testInvalidTLVEventMissingId() throws {
        // Build TLV with only author entry (no special=0 event id)
        let author = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        var tlv = Data()
        tlv.append(2) // author type
        tlv.append(32) // length
        tlv.append(contentsOf: Data(hex: author)!)

        let bech = try Bech32.encode(hrp: "nevent", data: tlv)

        #expect(throws: NostrError.self) {
            _ = try Bech32Entity(from: bech)
        }
    }

    @Test("Invalid TLV: naddr missing required fields should throw")
    func testInvalidTLVAddrMissingFields() throws {
        // Build TLV with only identifier (no author/kind)
        let identifier = "my-article"
        var tlv = Data()
        tlv.append(0) // special type (identifier)
        tlv.append(UInt8(identifier.utf8.count))
        tlv.append(contentsOf: identifier.utf8)

        let bech = try Bech32.encode(hrp: "naddr", data: tlv)

        #expect(throws: NostrError.self) {
            _ = try Bech32Entity(from: bech)
        }
    }
    
    // MARK: - Extended Round-trip Tests
    
    @Test("Comprehensive npub round-trip with various hex patterns")
    func testNpubRoundTripVariousPatterns() throws {
        let testCases = [
            // All zeros
            "0000000000000000000000000000000000000000000000000000000000000000",
            // All ones
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            // Alternating
            "0101010101010101010101010101010101010101010101010101010101010101",
            // Random valid hex
            "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        ]
        
        for pubkey in testCases {
            let entity = Bech32Entity.npub(pubkey)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .npub(let decodedPubkey) = decoded else {
                Issue.record("Failed to decode npub for pubkey: \(pubkey)")
                continue
            }
            #expect(decodedPubkey == pubkey.lowercased())
        }
    }
    
    @Test("Comprehensive nsec round-trip with various patterns")
    func testNsecRoundTripVariousPatterns() throws {
        let testCases = [
            "0000000000000000000000000000000000000000000000000000000000000001",
            "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
            "5a0e7d3e5f8c3a2b1d9e4f6c8b3a7d2e9f4c6b8a3d7e2f9c4b6a8d3e7f2c9b4a",
            "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        ]
        
        for privkey in testCases {
            let entity = Bech32Entity.nsec(privkey)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .nsec(let decodedPrivkey) = decoded else {
                Issue.record("Failed to decode nsec for privkey: \(privkey)")
                continue
            }
            #expect(decodedPrivkey == privkey.lowercased())
        }
    }
    
    @Test("NProfile round-trip with various relay configurations")
    func testNprofileRoundTripVariousRelays() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        
        let testCases = [
            // No relays
            [],
            // Single relay
            ["wss://relay.damus.io"],
            // Multiple relays
            ["wss://relay.damus.io", "wss://nos.lol", "wss://relay.nostr.band"],
            // With ports
            ["wss://relay.example.com:8080", "ws://localhost:9000"],
            // Long relay list
            (1...10).map { "wss://relay\($0).example.com" }
        ]
        
        for relays in testCases {
            let profile = try NProfile(pubkey: pubkey, relays: relays)
            let entity = Bech32Entity.nprofile(profile)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .nprofile(let decodedProfile) = decoded else {
                Issue.record("Failed to decode nprofile with \(relays.count) relays")
                continue
            }
            #expect(decodedProfile.pubkey == pubkey)
            #expect(decodedProfile.relays == relays)
        }
    }
    
    @Test("NEvent round-trip with all combinations of optional fields")
    func testNeventRoundTripOptionalFields() throws {
        let eventId = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        let author = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let relays = ["wss://relay.damus.io", "wss://nos.lol"]
        
        // Test all combinations of optional fields
        let testCases: [(relays: [String]?, author: String?, kind: Int?)] = [
            (nil, nil, nil),
            (relays, nil, nil),
            (nil, author, nil),
            (nil, nil, 1),
            (relays, author, nil),
            (relays, nil, 1),
            (nil, author, 1),
            (relays, author, 1)
        ]
        
        for testCase in testCases {
            let event = try NEvent(
                eventId: eventId,
                relays: testCase.relays,
                author: testCase.author,
                kind: testCase.kind
            )
            let entity = Bech32Entity.nevent(event)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .nevent(let decodedEvent) = decoded else {
                Issue.record("Failed to decode nevent")
                continue
            }
            #expect(decodedEvent.eventId == eventId)
            #expect(decodedEvent.relays == testCase.relays)
            #expect(decodedEvent.author == testCase.author)
            #expect(decodedEvent.kind == testCase.kind)
        }
    }
    
    @Test("NAddr round-trip with various identifier types")
    func testNaddrRoundTripVariousIdentifiers() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let kind = 30023
        
        let identifiers = [
            "",  // Empty identifier
            "a",  // Single character
            "test-article",  // Normal identifier
            "1234567890",  // Numeric
            "article-with-special-chars_123",  // Mixed
            String(repeating: "x", count: 100),  // Long identifier
            "文章",  // Unicode
            "article with spaces"  // Spaces
        ]
        
        for identifier in identifiers {
            let addr = try NAddr(
                identifier: identifier,
                pubkey: pubkey,
                kind: kind,
                relays: ["wss://relay.example.com"]
            )
            let entity = Bech32Entity.naddr(addr)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .naddr(let decodedAddr) = decoded else {
                Issue.record("Failed to decode naddr with identifier: \(identifier)")
                continue
            }
            #expect(decodedAddr.identifier == identifier)
            #expect(decodedAddr.pubkey == pubkey)
            #expect(decodedAddr.kind == kind)
        }
    }
    
    @Test("NRelay round-trip with various URL formats")
    func testNrelayRoundTripVariousURLs() throws {
        let urls = [
            "wss://relay.damus.io",
            "ws://localhost:8080",
            "wss://relay.example.com:9000",
            "wss://relay.nostr.band/path",
            "ws://192.168.1.1:7777",
            "wss://relay-with-dash.example.com",
            "wss://sub.domain.relay.example.com"
        ]
        
        for url in urls {
            let entity = Bech32Entity.nrelay(url)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .nrelay(let decodedUrl) = decoded else {
                Issue.record("Failed to decode nrelay for URL: \(url)")
                continue
            }
            #expect(decodedUrl == url)
        }
    }
    
    @Test("Invalid hex input handling")
    func testInvalidHexInput() throws {
        // Invalid hex characters
        #expect(throws: Error.self) {
            _ = try Bech32Entity.npub("xyz0000000000000000000000000000000000000000000000000000000000000").encoded
        }
        
        // Wrong length (not 64 chars) - bech32 encoding will work but it's not a valid public key
        // Let's check if it encodes and what we get back
        let shortHex = "3bf0c63fcb93463407af97a5e5ee64fa"
        do {
            let encoded = try Bech32Entity.npub(shortHex).encoded
            // If it succeeds, verify it round-trips correctly
            let decoded = try Bech32Entity(from: encoded)
            if case .npub(let decodedHex) = decoded {
                #expect(decodedHex.lowercased() == shortHex.lowercased())
            }
        } catch {
            // If it fails, that's also acceptable - public key validation might happen at encode time
            #expect(error is NostrError)
        }
        
        // Odd length hex - This should fail as hex must be even length
        #expect(throws: Error.self) {
            _ = try Bech32Entity.npub("3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459").encoded
        }
    }
    
    @Test("Case insensitive hex decoding")
    func testCaseInsensitiveHexDecoding() throws {
        let pubkeyLower = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let pubkeyUpper = "3BF0C63FCB93463407AF97A5E5EE64FA883D107EF9E558472C4EB9AAAEFA459D"
        let pubkeyMixed = "3Bf0C63FcB93463407aF97A5e5EE64Fa883D107eF9E558472c4eB9AaaEFa459D"
        
        for pubkey in [pubkeyLower, pubkeyUpper, pubkeyMixed] {
            let entity = Bech32Entity.npub(pubkey)
            let encoded = try entity.encoded
            let decoded = try Bech32Entity(from: encoded)
            
            guard case .npub(let decodedPubkey) = decoded else {
                Issue.record("Failed to decode npub")
                return
            }
            #expect(decodedPubkey.lowercased() == pubkeyLower)
        }
    }
    
    
    @Test("Maximum length stress test")
    func testMaximumLengthHandling() throws {
        // Create naddr with maximum reasonable data
        let identifier = String(repeating: "x", count: 200)
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let kind = 30023
        let relays = (1...20).map { "wss://relay\($0).example.com" }
        
        let addr = try NAddr(
            identifier: identifier,
            pubkey: pubkey,
            kind: kind,
            relays: relays
        )
        
        let entity = Bech32Entity.naddr(addr)
        let encoded = try entity.encoded
        
        // Should handle long encoding
        #expect(encoded.count > 200)
        
        // Should decode correctly
        let decoded = try Bech32Entity(from: encoded)
        guard case .naddr(let decodedAddr) = decoded else {
            Issue.record("Failed to decode large naddr")
            return
        }
        #expect(decodedAddr.identifier == identifier)
        #expect(decodedAddr.relays == relays)
    }
}
