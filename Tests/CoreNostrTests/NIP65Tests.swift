//
//  NIP65Tests.swift
//  CoreNostrTests
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-65: Relay List Metadata")
struct NIP65Tests {
    let keyPair: KeyPair
    
    init() throws {
        let privateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
        self.keyPair = try KeyPair(privateKey: privateKeyHex)
    }
    
    @Test("RelayUsage enum")
    func testRelayUsage() {
        #expect(RelayUsage.readWrite.rawValue == "")
        #expect(RelayUsage.read.rawValue == "read")
        #expect(RelayUsage.write.rawValue == "write")
        
        // Test all cases
        #expect(RelayUsage.allCases.count == 3)
    }
    
    @Test("RelayPreference creation and tag conversion")
    func testRelayPreferenceCreation() {
        // Test read/write relay (no marker)
        let rwRelay = RelayPreference(url: "wss://relay.example.com")
        #expect(rwRelay.usage == .readWrite)
        #expect(rwRelay.toTag() == ["r", "wss://relay.example.com"])
        
        // Test read-only relay
        let readRelay = RelayPreference(url: "wss://read.example.com", usage: .read)
        #expect(readRelay.toTag() == ["r", "wss://read.example.com", "read"])
        
        // Test write-only relay
        let writeRelay = RelayPreference(url: "wss://write.example.com", usage: .write)
        #expect(writeRelay.toTag() == ["r", "wss://write.example.com", "write"])
    }
    
    @Test("RelayPreference parsing from tags")
    func testRelayPreferenceParsing() {
        // Parse read/write relay
        let rwTag = ["r", "wss://relay.example.com"]
        let rwRelay = RelayPreference(fromTag: rwTag)
        #expect(rwRelay?.url == "wss://relay.example.com")
        #expect(rwRelay?.usage == .readWrite)
        
        // Parse read relay
        let readTag = ["r", "wss://read.example.com", "read"]
        let readRelay = RelayPreference(fromTag: readTag)
        #expect(readRelay?.url == "wss://read.example.com")
        #expect(readRelay?.usage == .read)
        
        // Parse write relay
        let writeTag = ["r", "wss://write.example.com", "write"]
        let writeRelay = RelayPreference(fromTag: writeTag)
        #expect(writeRelay?.url == "wss://write.example.com")
        #expect(writeRelay?.usage == .write)
        
        // Invalid tag
        let invalidTag = ["p", "some-pubkey"]
        let invalid = RelayPreference(fromTag: invalidTag)
        #expect(invalid == nil)
    }
    
    @Test("RelayListMetadata filtering")
    func testRelayListMetadataFiltering() {
        let relays = [
            RelayPreference(url: "wss://rw1.com", usage: .readWrite),
            RelayPreference(url: "wss://rw2.com", usage: .readWrite),
            RelayPreference(url: "wss://read1.com", usage: .read),
            RelayPreference(url: "wss://read2.com", usage: .read),
            RelayPreference(url: "wss://write1.com", usage: .write),
            RelayPreference(url: "wss://write2.com", usage: .write)
        ]
        
        let metadata = RelayListMetadata(relays: relays)
        
        // Test read relays (includes read/write)
        #expect(metadata.readRelays.count == 4)
        #expect(metadata.readRelays.contains("wss://rw1.com"))
        #expect(metadata.readRelays.contains("wss://rw2.com"))
        #expect(metadata.readRelays.contains("wss://read1.com"))
        #expect(metadata.readRelays.contains("wss://read2.com"))
        
        // Test write relays (includes read/write)
        #expect(metadata.writeRelays.count == 4)
        #expect(metadata.writeRelays.contains("wss://rw1.com"))
        #expect(metadata.writeRelays.contains("wss://rw2.com"))
        #expect(metadata.writeRelays.contains("wss://write1.com"))
        #expect(metadata.writeRelays.contains("wss://write2.com"))
        
        // Test exclusive relays
        #expect(metadata.readOnlyRelays.count == 2)
        #expect(metadata.writeOnlyRelays.count == 2)
        #expect(metadata.readWriteRelays.count == 2)
    }
    
    @Test("RelayListMetadata initialization from URLs")
    func testRelayListMetadataFromURLs() {
        let metadata = RelayListMetadata(
            readWrite: ["wss://rw1.com", "wss://rw2.com"],
            readOnly: ["wss://read.com"],
            writeOnly: ["wss://write.com"]
        )
        
        #expect(metadata.relays.count == 4)
        #expect(metadata.readWriteRelays.count == 2)
        #expect(metadata.readOnlyRelays.count == 1)
        #expect(metadata.writeOnlyRelays.count == 1)
    }
    
    @Test("Create relay list metadata event")
    func testCreateRelayListMetadata() throws {
        let event = try CoreNostr.createRelayListMetadata(
            readWrite: ["wss://rw.example.com"],
            readOnly: ["wss://read.example.com"],
            writeOnly: ["wss://write.example.com"],
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.relayList.rawValue)
        #expect(event.content == "")
        
        // Check tags
        let rTags = event.tags.filter { $0[0] == "r" }
        #expect(rTags.count == 3)
        
        // Verify each relay type
        let rwTag = rTags.first { $0[1] == "wss://rw.example.com" }
        #expect(rwTag?.count == 2) // No marker for read/write
        
        let readTag = rTags.first { $0[1] == "wss://read.example.com" }
        #expect(readTag?.count == 3)
        #expect(readTag?[2] == "read")
        
        let writeTag = rTags.first { $0[1] == "wss://write.example.com" }
        #expect(writeTag?.count == 3)
        #expect(writeTag?[2] == "write")
    }
    
    @Test("Parse relay list metadata from event")
    func testParseRelayListMetadata() throws {
        let event = try CoreNostr.createRelayListMetadata(
            readWrite: ["wss://rw.com"],
            readOnly: ["wss://read.com"],
            writeOnly: ["wss://write.com"],
            keyPair: keyPair
        )
        
        let metadata = event.parseRelayListMetadata()
        #expect(metadata != nil)
        #expect(metadata?.relays.count == 3)
        #expect(metadata?.readRelays.count == 2) // rw + read
        #expect(metadata?.writeRelays.count == 2) // rw + write
    }
    
    @Test("Relay discovery for authored events")
    func testRelayDiscoveryForAuthoredEvents() {
        let metadata = RelayListMetadata(
            readWrite: ["wss://rw.com"],
            readOnly: ["wss://read.com"],
            writeOnly: ["wss://write.com"]
        )
        
        // For authored events, use write relays
        let authoredRelays = RelayDiscovery.getRelaysForAuthor(
            metadata,
            forAuthoredEvents: true
        )
        #expect(authoredRelays.count == 2)
        #expect(authoredRelays.contains("wss://rw.com"))
        #expect(authoredRelays.contains("wss://write.com"))
        
        // For events mentioning the author, use read relays
        let mentionRelays = RelayDiscovery.getRelaysForAuthor(
            metadata,
            forAuthoredEvents: false
        )
        #expect(mentionRelays.count == 2)
        #expect(mentionRelays.contains("wss://rw.com"))
        #expect(mentionRelays.contains("wss://read.com"))
    }
    
    @Test("Relay discovery for publishing")
    func testRelayDiscoveryForPublishing() {
        let authorMetadata = RelayListMetadata(
            readWrite: ["wss://author-rw.com"],
            writeOnly: ["wss://author-write.com"]
        )
        
        let taggedUser1 = RelayListMetadata(
            readWrite: ["wss://user1-rw.com"],
            readOnly: ["wss://user1-read.com"]
        )
        
        let taggedUser2 = RelayListMetadata(
            readOnly: ["wss://user2-read.com"]
        )
        
        let publishRelays = RelayDiscovery.getRelaysForPublishing(
            authorMetadata: authorMetadata,
            taggedUsersMetadata: [taggedUser1, taggedUser2]
        )
        
        // Should include author's write relays + tagged users' read relays
        #expect(publishRelays.count == 5)
        #expect(publishRelays.contains("wss://author-rw.com"))
        #expect(publishRelays.contains("wss://author-write.com"))
        #expect(publishRelays.contains("wss://user1-rw.com"))
        #expect(publishRelays.contains("wss://user1-read.com"))
        #expect(publishRelays.contains("wss://user2-read.com"))
    }
    
    @Test("Relay list validation")
    func testRelayListValidation() {
        // Good relay list
        let goodMetadata = RelayListMetadata(
            readWrite: ["wss://rw1.com", "wss://rw2.com"],
            readOnly: ["wss://read.com"]
        )
        let goodWarnings = RelayDiscovery.validateRelayList(goodMetadata)
        #expect(goodWarnings.isEmpty)
        
        // Too many relays
        let tooManyMetadata = RelayListMetadata(
            readWrite: ["wss://rw1.com", "wss://rw2.com", "wss://rw3.com"],
            readOnly: ["wss://read1.com", "wss://read2.com"],
            writeOnly: ["wss://write1.com", "wss://write2.com"]
        )
        let tooManyWarnings = RelayDiscovery.validateRelayList(tooManyMetadata)
        #expect(tooManyWarnings.count == 2)
        #expect(tooManyWarnings.contains { $0.contains("Too many read relays") })
        #expect(tooManyWarnings.contains { $0.contains("Too many write relays") })
        
        // No read relays
        let noReadMetadata = RelayListMetadata(
            writeOnly: ["wss://write.com"]
        )
        let noReadWarnings = RelayDiscovery.validateRelayList(noReadMetadata)
        #expect(noReadWarnings.contains { $0.contains("No read relays") })
        
        // No write relays
        let noWriteMetadata = RelayListMetadata(
            readOnly: ["wss://read.com"]
        )
        let noWriteWarnings = RelayDiscovery.validateRelayList(noWriteMetadata)
        #expect(noWriteWarnings.contains { $0.contains("No write relays") })
    }
    
    @Test("Filter for relay list metadata")
    func testRelayListFilter() {
        let pubkeys = ["pubkey1", "pubkey2", "pubkey3"]
        let filter = Filter.relayListMetadata(for: pubkeys)
        
        #expect(filter.authors == pubkeys)
        #expect(filter.kinds == [EventKind.relayList.rawValue])
    }
    
    @Test("Empty relay list")
    func testEmptyRelayList() throws {
        let metadata = RelayListMetadata(relays: [])
        let event = try CoreNostr.createRelayListMetadata(metadata, keyPair: keyPair)
        
        #expect(event.kind == EventKind.relayList.rawValue)
        #expect(event.tags.isEmpty)
        #expect(event.content == "")
    }
    
    @Test("RelayPreference equality")
    func testRelayPreferenceEquality() {
        let relay1 = RelayPreference(url: "wss://relay.com", usage: .read)
        let relay2 = RelayPreference(url: "wss://relay.com", usage: .read)
        let relay3 = RelayPreference(url: "wss://relay.com", usage: .write)
        let relay4 = RelayPreference(url: "wss://other.com", usage: .read)
        
        #expect(relay1 == relay2)
        #expect(relay1 != relay3)
        #expect(relay1 != relay4)
    }
}