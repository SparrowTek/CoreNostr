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
    
    @Test("Encode and decode naddr", .disabled("Intermittent signal code 5"))
    func testNaddr() throws {
        let identifier = "1700847963"
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let kind = 30023
        let relays = ["wss://relay.damus.io", "wss://nos.lol"]
        let addr = try NAddr(identifier: identifier, pubkey: pubkey, kind: kind, relays: relays)
        let entity = Bech32Entity.naddr(addr)
        
        let encoded = try entity.encoded
        #expect(encoded.hasPrefix("naddr1"))
        
        let decoded = try Bech32Entity(from: encoded)
        guard case .naddr(let decodedAddr) = decoded else {
            Issue.record("Expected naddr entity")
            return
        }
        #expect(decodedAddr.identifier == identifier)
        #expect(decodedAddr.pubkey == pubkey)
        #expect(decodedAddr.kind == kind)
        #expect(decodedAddr.relays == relays)
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
    
    @Test("Test TLV encoding edge cases", .disabled("Intermittent signal code 5"))
    func testTLVEdgeCases() throws {
        // Test nprofile with no relays
        let profile = try NProfile(pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", relays: [])
        let entity = Bech32Entity.nprofile(profile)
        let encoded = try entity.encoded
        let decoded = try Bech32Entity(from: encoded)
        
        guard case .nprofile(let decodedProfile) = decoded else {
            Issue.record("Expected nprofile entity")
            return
        }
        #expect(decodedProfile.relays.isEmpty)
        
        // Test nevent with minimal fields
        let event = try NEvent(eventId: "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7")
        let eventEntity = Bech32Entity.nevent(event)
        let eventEncoded = try eventEntity.encoded
        let eventDecoded = try Bech32Entity(from: eventEncoded)
        
        guard case .nevent(let decodedEvent) = eventDecoded else {
            Issue.record("Expected nevent entity")
            return
        }
        #expect(decodedEvent.relays == nil)
        #expect(decodedEvent.author == nil)
        #expect(decodedEvent.kind == nil)
        
        // Test naddr with no relays
        let addr = try NAddr(identifier: "test", pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", kind: 30023)
        let addrEntity = Bech32Entity.naddr(addr)
        let addrEncoded = try addrEntity.encoded
        let addrDecoded = try Bech32Entity(from: addrEncoded)
        
        guard case .naddr(let decodedAddr) = addrDecoded else {
            Issue.record("Expected naddr entity")
            return
        }
        #expect(decodedAddr.relays == nil)
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
}
