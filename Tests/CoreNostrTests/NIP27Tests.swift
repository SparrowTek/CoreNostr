//
//  NIP27Tests.swift
//  CoreNostrTests
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-27: Text Note References")
struct NIP27Tests {
    let keyPair: KeyPair
    
    init() throws {
        let privateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
        self.keyPair = try KeyPair(privateKey: privateKeyHex)
    }
    
    @Test("Parse profile reference from nostr: URI")
    func testParseProfileReference() throws {
        // Create a profile reference
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npubEntity = try Bech32Entity.npub(pubkey).encoded
        let uri = "nostr:\(npubEntity)"
        
        let reference = NostrReference(uri: uri)
        #expect(reference != nil)
        
        if case .profile(let refPubkey, let relays) = reference?.type {
            #expect(refPubkey == pubkey)
            #expect(relays.isEmpty)
        } else {
            Issue.record("Expected profile reference")
        }
    }
    
    @Test("Parse event reference from nostr: URI")
    func testParseEventReference() throws {
        // Create an event reference
        let eventId = "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e"
        let noteEntity = try Bech32Entity.note(eventId).encoded
        let uri = "nostr:\(noteEntity)"
        
        let reference = NostrReference(uri: uri)
        #expect(reference != nil)
        
        if case .event(let refId, let relays, let author) = reference?.type {
            #expect(refId == eventId)
            #expect(relays.isEmpty)
            #expect(author == nil)
        } else {
            Issue.record("Expected event reference")
        }
    }
    
    @Test("Parse nprofile reference with relays")
    func testParseNProfileReference() throws {
        let profile = try NProfile(
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            relays: ["wss://relay1.com", "wss://relay2.com"]
        )
        let nprofileEntity = try Bech32Entity.nprofile(profile).encoded
        let uri = "nostr:\(nprofileEntity)"
        
        let reference = NostrReference(uri: uri)
        #expect(reference != nil)
        
        if case .profile(let pubkey, let relays) = reference?.type {
            #expect(pubkey == profile.pubkey)
            #expect(relays == profile.relays)
        } else {
            Issue.record("Expected profile reference")
        }
    }
    
    @Test("Parse nevent reference with metadata")
    func testParseNEventReference() throws {
        let event = try NEvent(
            eventId: "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e",
            relays: ["wss://relay.example.com"],
            author: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            kind: 1
        )
        let neventEntity = try Bech32Entity.nevent(event).encoded
        let uri = "nostr:\(neventEntity)"
        
        let reference = NostrReference(uri: uri)
        #expect(reference != nil)
        
        if case .event(let id, let relays, let author) = reference?.type {
            #expect(id == event.eventId)
            #expect(relays == event.relays)
            #expect(author == event.author)
        } else {
            Issue.record("Expected event reference")
        }
    }
    
    @Test("Find references in text")
    func testFindReferencesInText() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        let eventId = "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e"
        let note = try Bech32Entity.note(eventId).encoded
        
        let text = "Hello nostr:\(npub), check out this note: nostr:\(note)"
        
        let references = NostrTextProcessor.findReferences(in: text)
        #expect(references.count == 2)
        
        // Check first reference (profile)
        if case .profile(let refPubkey, _) = references[0].reference.type {
            #expect(refPubkey == pubkey)
        } else {
            Issue.record("Expected profile reference")
        }
        
        // Check second reference (event)
        if case .event(let refId, _, _) = references[1].reference.type {
            #expect(refId == eventId)
        } else {
            Issue.record("Expected event reference")
        }
    }
    
    @Test("Extract profile references")
    func testExtractProfileReferences() throws {
        let pubkey1 = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let pubkey2 = "52b4a076bcbbbdc3a1aefa3735816cf74993b1b8db202b01c883c58be7fad8bd"
        let npub1 = try Bech32Entity.npub(pubkey1).encoded
        let npub2 = try Bech32Entity.npub(pubkey2).encoded
        
        let text = "Thanks nostr:\(npub1) and nostr:\(npub2) for the help!"
        
        let profiles = NostrTextProcessor.extractProfileReferences(from: text)
        #expect(profiles.count == 2)
        #expect(profiles[0].pubkey == pubkey1)
        #expect(profiles[1].pubkey == pubkey2)
    }
    
    @Test("Extract event references")
    func testExtractEventReferences() throws {
        let eventId1 = "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e"
        let eventId2 = "6f8a3b2c1d9e4f5a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a"
        let note1 = try Bech32Entity.note(eventId1).encoded
        let note2 = try Bech32Entity.note(eventId2).encoded
        
        let text = "Reply to nostr:\(note1) and also see nostr:\(note2)"
        
        let events = NostrTextProcessor.extractEventReferences(from: text)
        #expect(events.count == 2)
        #expect(events[0].id == eventId1)
        #expect(events[1].id == eventId2)
    }
    
    @Test("Create tags from references")
    func testCreateTagsFromReferences() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        let eventId = "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e"
        let note = try Bech32Entity.note(eventId).encoded
        
        let text = "Hey nostr:\(npub), regarding nostr:\(note)"
        
        let tags = NostrTextProcessor.createTags(from: text)
        #expect(tags.count == 2)
        #expect(tags[0] == ["p", pubkey])
        #expect(tags[1] == ["e", eventId])
    }
    
    @Test("NostrEvent content references")
    func testNostrEventContentReferences() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Hello nostr:\(npub)!"
        )
        
        let references = event.contentReferences
        #expect(references.count == 1)
        
        let profileRefs = event.profileReferences
        #expect(profileRefs.count == 1)
        #expect(profileRefs[0].pubkey == pubkey)
        
        #expect(event.mentionsProfile(pubkey))
        #expect(!event.mentionsProfile("differentpubkey"))
    }
    
    @Test("MentionBuilder")
    func testMentionBuilder() throws {
        var builder = MentionBuilder()
        
        let profile = try NProfile(
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            relays: ["wss://relay.com"]
        )
        
        let event = try NEvent(
            eventId: "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e",
            relays: [],
            author: nil,
            kind: 1
        )
        
        builder.addProfileMention(profile, displayName: "@alice")
        builder.addEventReference(event, label: "Reply to")
        
        let (content, tags) = builder.build()
        
        #expect(content.contains("@alice"))
        #expect(content.contains("nostr:"))
        #expect(tags.count >= 2)
        #expect(tags.contains(["p", profile.pubkey]))
        #expect(tags.contains(["e", event.eventId]))
    }
    
    @Test("Replace mention with nostr URI")
    func testReplaceMention() throws {
        let text = "Hello @alice, how are you?"
        let profile = try NProfile(
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            relays: []
        )
        
        let replaced = NostrTextProcessor.replaceMention(
            in: text,
            mention: "@alice",
            with: profile
        )
        
        #expect(replaced != nil)
        #expect(replaced?.contains("nostr:") == true)
        #expect(replaced?.contains("@alice") == false)
    }
    
    @Test("String extension for references")
    func testStringExtension() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        
        let text = "Check out nostr:\(npub)"
        
        #expect(text.containsNostrReferences)
        #expect(text.nostrReferences.count == 1)
        
        let emptyText = "No references here"
        #expect(!emptyText.containsNostrReferences)
        #expect(emptyText.nostrReferences.isEmpty)
    }
    
    @Test("Create text note with mentions")
    func testCreateTextNoteWithMentions() throws {
        let pubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let npub = try Bech32Entity.npub(pubkey).encoded
        let eventId = "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e"
        let note = try Bech32Entity.note(eventId).encoded
        
        let content = "Hey nostr:\(npub), about nostr:\(note)"
        
        let event = try CoreNostr.createTextNoteWithMentions(
            content: content,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.textNote.rawValue)
        #expect(event.content == content)
        #expect(event.tags.count >= 2)
        #expect(event.tags.contains(["p", pubkey]))
        #expect(event.tags.contains(["e", eventId]))
    }
    
    @Test("Invalid URI returns nil")
    func testInvalidURI() {
        let invalidURIs = [
            "nostr:invalid",
            "nostr:nsec1234", // Should reject nsec
            "notanostruri",
            "nostr:",
            ""
        ]
        
        for uri in invalidURIs {
            let reference = NostrReference(uri: uri)
            #expect(reference == nil)
        }
    }
    
    @Test("Parse naddr reference")
    func testParseNAddrReference() throws {
        let addr = try NAddr(
            identifier: "my-article",
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            kind: 30023,
            relays: ["wss://relay.example.com"]
        )
        
        let naddrEntity = try Bech32Entity.naddr(addr).encoded
        let uri = "nostr:\(naddrEntity)"
        
        let reference = NostrReference(uri: uri)
        #expect(reference != nil)
        
        if case .address(let identifier, let pubkey, let kind, let relays) = reference?.type {
            #expect(identifier == addr.identifier)
            #expect(pubkey == addr.pubkey)
            #expect(kind == addr.kind)
            #expect(relays == addr.relays)
        } else {
            Issue.record("Expected address reference")
        }
    }
}