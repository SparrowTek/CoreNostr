import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-21: nostr: URI scheme Tests")
struct NIP21Tests {
    
    @Test("Parse nostr: URIs")
    func testParseNostrURIs() throws {
        // Test npub URI
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        
        let npubURI = NostrURI(from: "nostr:\(npub)")
        #expect(npubURI != nil)
        if case .profile(let bech32) = npubURI {
            #expect(bech32 == npub)
        } else {
            Issue.record("Expected profile URI")
        }
        
        // Test note URI
        let eventId = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        let note = try Bech32Entity.note(eventId).encoded
        
        let noteURI = NostrURI(from: "nostr:\(note)")
        #expect(noteURI != nil)
        if case .event(let bech32) = noteURI {
            #expect(bech32 == note)
        } else {
            Issue.record("Expected event URI")
        }
        
        // Test nrelay URI
        let relayUrl = "wss://relay.damus.io"
        let nrelay = try Bech32Entity.nrelay(relayUrl).encoded
        
        let nrelayURI = NostrURI(from: "nostr:\(nrelay)")
        #expect(nrelayURI != nil)
        if case .relay(let bech32) = nrelayURI {
            #expect(bech32 == nrelay)
        } else {
            Issue.record("Expected relay URI")
        }
    }
    
    @Test("Parse URIs with different prefixes")
    func testParseDifferentPrefixes() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        
        // Test with nostr: prefix
        let uri1 = NostrURI(from: "nostr:\(npub)")
        #expect(uri1 != nil)
        
        // Test with web+nostr: prefix
        let uri2 = NostrURI(from: "web+nostr:\(npub)")
        #expect(uri2 != nil)
        
        // Test with nostr:// prefix
        let uri3 = NostrURI(from: "nostr://\(npub)")
        #expect(uri3 != nil)
        
        // Test without prefix
        let uri4 = NostrURI(from: npub)
        #expect(uri4 != nil)
        
        // All should decode to the same thing
        #expect(uri1 == uri2)
        #expect(uri2 == uri3)
        #expect(uri3 == uri4)
    }
    
    @Test("Parse nprofile and nevent URIs")
    func testParseComplexURIs() throws {
        // Test nprofile
        let profile = try NProfile(
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            relays: ["wss://relay.damus.io", "wss://nos.lol"]
        )
        let nprofile = try Bech32Entity.nprofile(profile).encoded
        
        let profileURI = NostrURI(from: "nostr:\(nprofile)")
        #expect(profileURI != nil)
        if case .pubkey(let bech32) = profileURI {
            #expect(bech32 == nprofile)
            
            // Verify we can decode back
            if let entity = profileURI?.entity,
               case .nprofile(let decodedProfile) = entity {
                #expect(decodedProfile.pubkey == profile.pubkey)
                #expect(decodedProfile.relays == profile.relays)
            } else {
                Issue.record("Failed to decode nprofile entity")
            }
        } else {
            Issue.record("Expected pubkey URI")
        }
        
        // Test nevent
        let event = try NEvent(
            eventId: "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7",
            relays: ["wss://relay.damus.io"],
            author: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            kind: 1
        )
        let nevent = try Bech32Entity.nevent(event).encoded
        
        let eventURI = NostrURI(from: "nostr:\(nevent)")
        #expect(eventURI != nil)
        if case .eventId(let bech32) = eventURI {
            #expect(bech32 == nevent)
        } else {
            Issue.record("Expected eventId URI")
        }
    }
    
    @Test("Parse naddr URI", .disabled("Related to NIP19 naddr issue"))
    func testParseNaddrURI() throws {
        let addr = try NAddr(
            identifier: "1700847963",
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            kind: 30023,
            relays: ["wss://relay.damus.io"]
        )
        let naddr = try Bech32Entity.naddr(addr).encoded
        
        let addrURI = NostrURI(from: "nostr:\(naddr)")
        #expect(addrURI != nil)
        if case .addr(let bech32) = addrURI {
            #expect(bech32 == naddr)
        } else {
            Issue.record("Expected addr URI")
        }
    }
    
    @Test("Reject nsec URIs")
    func testRejectNsecURIs() throws {
        // nsec should not be allowed in URIs for security
        let privkey = "5a0e7d3e5f8c3a2b1d9e4f6c8b3a7d2e9f4c6b8a3d7e2f9c4b6a8d3e7f2c9b4a"
        let nsec = try Bech32Entity.nsec(privkey).encoded
        
        let nsecURI = NostrURI(from: "nostr:\(nsec)")
        #expect(nsecURI == nil)
    }
    
    @Test("Invalid URI handling")
    func testInvalidURIs() {
        // Invalid bech32
        #expect(NostrURI(from: "nostr:invalid") == nil)
        
        // Invalid prefix in bech32
        #expect(NostrURI(from: "nostr:lnbc1234") == nil)
        
        // Empty string
        #expect(NostrURI(from: "") == nil)
        
        // Just prefix
        #expect(NostrURI(from: "nostr:") == nil)
    }
    
    @Test("URI string generation")
    func testURIStringGeneration() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        
        let uri = NostrURI.profile(npub)
        
        // Test standard URI string
        #expect(uri.uriString == "nostr:\(npub)")
        
        // Test web URI string
        #expect(uri.webUriString == "web+nostr:\(npub)")
        
        // Test bech32 string
        #expect(uri.bech32String == npub)
    }
    
    @Test("Convenience extensions", .disabled("Related to NIP19 encoding issues"))
    func testConvenienceExtensions() throws {
        // Test PublicKey builder
        let pubkey: PublicKey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let pubkeyURI = NostrURIBuilder.fromPublicKey(pubkey)
        #expect(pubkeyURI != nil)
        #expect(pubkeyURI?.uriString.hasPrefix("nostr:npub") == true)
        
        // Test EventID builder
        let eventId: EventID = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        let eventURI = NostrURIBuilder.fromEventID(eventId)
        #expect(eventURI != nil)
        #expect(eventURI?.uriString.hasPrefix("nostr:note") == true)
        
        // Test NProfile extension
        let profile = try NProfile(
            pubkey: pubkey,
            relays: ["wss://relay.damus.io"]
        )
        let profileURI = profile.nostrURI
        #expect(profileURI != nil)
        #expect(profileURI?.uriString.hasPrefix("nostr:nprofile") == true)
        
        // Test NEvent extension
        let event = try NEvent(
            eventId: eventId,
            relays: ["wss://relay.damus.io"],
            author: pubkey,
            kind: 1
        )
        let neventURI = event.nostrURI
        #expect(neventURI != nil)
        #expect(neventURI?.uriString.hasPrefix("nostr:nevent") == true)
        
        // Test NAddr extension
        let addr = try NAddr(
            identifier: "test",
            pubkey: pubkey,
            kind: 30023,
            relays: ["wss://relay.damus.io"]
        )
        let addrURI = addr.nostrURI
        #expect(addrURI != nil)
        #expect(addrURI?.uriString.hasPrefix("nostr:naddr") == true)
        
        // Test String extension
        let uriString = "nostr:\(try pubkey.npub)"
        let parsedURI = uriString.parseNostrURI()
        #expect(parsedURI != nil)
        if case .profile(let bech32) = parsedURI {
            let decoded = try Bech32Entity(from: bech32)
            if case .npub(let decodedPubkey) = decoded {
                #expect(decodedPubkey == pubkey)
            } else {
                Issue.record("Failed to decode npub")
            }
        } else {
            Issue.record("Failed to parse URI")
        }
    }
    
    @Test("Round-trip encoding")
    func testRoundTripEncoding() throws {
        // Test with various entities
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let eventId = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        
        // npub round-trip
        let npubURI = NostrURIBuilder.fromPublicKey(pubkey)!
        let npubString = npubURI.uriString
        let parsedNpub = NostrURI(from: npubString)
        #expect(parsedNpub == npubURI)
        
        // note round-trip
        let noteURI = NostrURIBuilder.fromEventID(eventId)!
        let noteString = noteURI.uriString
        let parsedNote = NostrURI(from: noteString)
        #expect(parsedNote == noteURI)
        
        // Complex nprofile round-trip
        let profile = try NProfile(pubkey: pubkey, relays: ["wss://relay1.com", "wss://relay2.com"])
        let profileURI = profile.nostrURI!
        let profileString = profileURI.uriString
        let parsedProfile = NostrURI(from: profileString)
        #expect(parsedProfile == profileURI)
        
        // Verify decoded data matches
        if let entity = parsedProfile?.entity,
           case .nprofile(let decodedProfile) = entity {
            #expect(decodedProfile.pubkey == profile.pubkey)
            #expect(decodedProfile.relays == profile.relays)
        } else {
            Issue.record("Failed to decode profile entity")
        }
    }
    
    @Test("Whitespace handling")
    func testWhitespaceHandling() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        
        // Test with leading/trailing whitespace
        let uri1 = NostrURI(from: "  nostr:\(npub)  ")
        #expect(uri1 != nil)
        
        let uri2 = NostrURI(from: "\nnostr:\(npub)\n")
        #expect(uri2 != nil)
        
        let uri3 = NostrURI(from: "\t\tnostr:\(npub)\t\t")
        #expect(uri3 != nil)
        
        // All should parse to the same URI
        #expect(uri1 == uri2)
        #expect(uri2 == uri3)
    }
}