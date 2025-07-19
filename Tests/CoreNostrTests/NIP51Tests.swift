//
//  NIP51Tests.swift
//  CoreNostrTests
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-51: Lists")
struct NIP51Tests {
    let keyPair: KeyPair
    
    init() throws {
        let privateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
        self.keyPair = try KeyPair(privateKey: privateKeyHex)
    }
    
    @Test("ListItem creation and tag conversion")
    func testListItemCreation() {
        // Test public key item
        let pubkeyItem = ListItem.publicKey("pubkey123", relay: "wss://relay.com", petname: "Alice")
        #expect(pubkeyItem.toTag() == ["p", "pubkey123", "wss://relay.com", "Alice"])
        
        // Test event item
        let eventItem = ListItem.event("event123", relay: "wss://relay.com")
        #expect(eventItem.toTag() == ["e", "event123", "wss://relay.com"])
        
        // Test hashtag item
        let hashtagItem = ListItem.hashtag("nostr")
        #expect(hashtagItem.toTag() == ["t", "nostr"])
        
        // Test relay item
        let relayItem = ListItem.relay("wss://relay.nostr.com")
        #expect(relayItem.toTag() == ["r", "wss://relay.nostr.com"])
        
        // Test emoji item
        let emojiItem = ListItem.emoji(shortcode: "custom", url: "https://example.com/emoji.png")
        #expect(emojiItem.toTag() == ["emoji", "custom", "https://example.com/emoji.png"])
    }
    
    @Test("ListItem parsing from tags")
    func testListItemParsing() {
        // Parse public key
        let pTag = ["p", "pubkey123", "wss://relay.com", "Alice"]
        let pubkeyItem = ListItem(fromTag: pTag)
        #expect(pubkeyItem == .publicKey("pubkey123", relay: "wss://relay.com", petname: "Alice"))
        
        // Parse event
        let eTag = ["e", "event123"]
        let eventItem = ListItem(fromTag: eTag)
        #expect(eventItem == .event("event123", relay: nil))
        
        // Parse hashtag
        let tTag = ["t", "bitcoin"]
        let hashtagItem = ListItem(fromTag: tTag)
        #expect(hashtagItem == .hashtag("bitcoin"))
        
        // Parse relay
        let rTag = ["r", "wss://relay.example.com"]
        let relayItem = ListItem(fromTag: rTag)
        #expect(relayItem == .relay("wss://relay.example.com"))
        
        // Parse emoji
        let emojiTag = ["emoji", "heart", "https://example.com/heart.png"]
        let emojiItem = ListItem(fromTag: emojiTag)
        #expect(emojiItem == .emoji(shortcode: "heart", url: "https://example.com/heart.png"))
    }
    
    @Test("Create standard mute list")
    func testCreateMuteList() throws {
        let event = try CoreNostr.createMuteList(
            publicKeys: ["pubkey1", "pubkey2"],
            events: ["event1", "event2"],
            hashtags: ["spam", "nsfw"],
            keyPair: keyPair,
            encrypted: false
        )
        
        #expect(event.kind == EventKind.muteList.rawValue)
        #expect(event.content == "")
        
        // Check tags
        let pTags = event.tags.filter { $0[0] == "p" }
        #expect(pTags.count == 2)
        #expect(pTags[0][1] == "pubkey1")
        #expect(pTags[1][1] == "pubkey2")
        
        let eTags = event.tags.filter { $0[0] == "e" }
        #expect(eTags.count == 2)
        #expect(eTags[0][1] == "event1")
        #expect(eTags[1][1] == "event2")
        
        let tTags = event.tags.filter { $0[0] == "t" }
        #expect(tTags.count == 2)
        #expect(tTags[0][1] == "spam")
        #expect(tTags[1][1] == "nsfw")
    }
    
    @Test("Create bookmark list")
    func testCreateBookmarkList() throws {
        let event = try CoreNostr.createBookmarkList(
            events: ["event1", "event2"],
            hashtags: ["interesting", "savedforlater"],
            relays: ["wss://relay1.com", "wss://relay2.com"],
            keyPair: keyPair,
            encrypted: false
        )
        
        #expect(event.kind == EventKind.bookmarks.rawValue)
        
        // Check tags
        let eTags = event.tags.filter { $0[0] == "e" }
        #expect(eTags.count == 2)
        
        let tTags = event.tags.filter { $0[0] == "t" }
        #expect(tTags.count == 2)
        
        let rTags = event.tags.filter { $0[0] == "r" }
        #expect(rTags.count == 2)
    }
    
    @Test("Create follow set")
    func testCreateFollowSet() throws {
        let follows: [(pubkey: PublicKey, relay: String?, petname: String?)] = [
            ("pubkey1", "wss://relay1.com", "Alice"),
            ("pubkey2", nil, "Bob"),
            ("pubkey3", "wss://relay3.com", nil)
        ]
        
        let event = try CoreNostr.createFollowSet(
            identifier: "close-friends",
            title: "Close Friends",
            publicKeys: follows,
            description: "My closest friends on Nostr",
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.followSets.rawValue)
        
        // Check d tag
        let dTag = event.tags.first { $0[0] == "d" }
        #expect(dTag?[1] == "close-friends")
        
        // Check title tag
        let titleTag = event.tags.first { $0[0] == "title" }
        #expect(titleTag?[1] == "Close Friends")
        
        // Check description tag
        let descTag = event.tags.first { $0[0] == "description" }
        #expect(descTag?[1] == "My closest friends on Nostr")
        
        // Check p tags
        let pTags = event.tags.filter { $0[0] == "p" }
        #expect(pTags.count == 3)
        #expect(pTags[0] == ["p", "pubkey1", "wss://relay1.com", "Alice"])
        #expect(pTags[1] == ["p", "pubkey2", "", "Bob"])
        #expect(pTags[2] == ["p", "pubkey3", "wss://relay3.com"])
    }
    
    @Test("Parse standard list from event")
    func testParseStandardList() throws {
        let event = try CoreNostr.createMuteList(
            publicKeys: ["pubkey1"],
            events: ["event1"],
            hashtags: ["spam"],
            keyPair: keyPair,
            encrypted: false
        )
        
        let list = event.parseStandardList()
        #expect(list != nil)
        #expect(list?.kind == .muteList)
        #expect(list?.publicItems.count == 3)
        #expect(list?.encryptedContent == nil)
    }
    
    @Test("Parse parameterized list from event")
    func testParseParameterizedList() throws {
        let event = try CoreNostr.createFollowSet(
            identifier: "test-set",
            title: "Test Set",
            publicKeys: [("pubkey1", nil, nil)],
            description: "Test description",
            keyPair: keyPair
        )
        
        let list = event.parseParameterizedList()
        #expect(list != nil)
        #expect(list?.kind == .followSets)
        #expect(list?.identifier == "test-set")
        #expect(list?.title == "Test Set")
        #expect(list?.description == "Test description")
        #expect(list?.publicItems.count == 1)
    }
    
    @Test("Encrypt and decrypt list items")
    func testEncryptDecryptListItems() throws {
        let items: [ListItem] = [
            .publicKey("pubkey1", relay: "wss://relay.com"),
            .event("event1"),
            .hashtag("secret")
        ]
        
        // Encrypt items
        let encrypted = try CoreNostr.encryptListItems(
            items,
            recipientPublicKey: keyPair.publicKey,
            senderKeyPair: keyPair
        )
        
        #expect(!encrypted.isEmpty)
        
        // Decrypt items
        let decrypted = try CoreNostr.decryptListItems(
            encryptedContent: encrypted,
            senderPublicKey: keyPair.publicKey,
            recipientKeyPair: keyPair
        )
        
        #expect(decrypted.count == 3)
        #expect(decrypted[0] == items[0])
        #expect(decrypted[1] == items[1])
        #expect(decrypted[2] == items[2])
    }
    
    @Test("Create encrypted mute list")
    func testCreateEncryptedMuteList() throws {
        let event = try CoreNostr.createMuteList(
            publicKeys: ["pubkey1"],
            events: ["event1"],
            hashtags: ["private"],
            keyPair: keyPair,
            encrypted: true
        )
        
        #expect(event.kind == EventKind.muteList.rawValue)
        #expect(!event.content.isEmpty) // Should have encrypted content
        #expect(event.tags.isEmpty) // No public tags
    }
    
    @Test("StandardList initialization")
    func testStandardListInit() {
        let items = [
            ListItem.publicKey("pubkey1"),
            ListItem.event("event1")
        ]
        
        let list = StandardList(
            kind: .muteList,
            publicItems: items,
            encryptedContent: "encrypted",
            metadata: [["custom", "tag"]]
        )
        
        #expect(list.kind == .muteList)
        #expect(list.publicItems.count == 2)
        #expect(list.encryptedContent == "encrypted")
        #expect(list.metadata.count == 1)
    }
    
    @Test("ParameterizedList initialization")
    func testParameterizedListInit() {
        let items = [ListItem.publicKey("pubkey1")]
        
        let list = ParameterizedList(
            kind: .followSets,
            identifier: "test",
            title: "Test List",
            description: "A test list",
            publicItems: items,
            encryptedContent: nil,
            metadata: []
        )
        
        #expect(list.kind == .followSets)
        #expect(list.identifier == "test")
        #expect(list.title == "Test List")
        #expect(list.description == "A test list")
        #expect(list.publicItems.count == 1)
    }
    
    @Test("Community and interest items")
    func testCommunityAndInterestItems() {
        // Test community item
        let communityItem = ListItem.community("34550:pubkey:identifier", relay: "wss://relay.com")
        let communityTag = communityItem.toTag()
        #expect(communityTag == ["a", "34550:pubkey:identifier", "wss://relay.com"])
        
        // Test interest item
        let interestItem = ListItem.interest("bitcoin")
        let interestTag = interestItem.toTag()
        #expect(interestTag == ["t", "bitcoin"])
    }
    
    @Test("Custom list items")
    func testCustomListItems() {
        let customItem = ListItem.custom(tag: "custom", values: ["value1", "value2", "value3"])
        let tag = customItem.toTag()
        #expect(tag == ["custom", "value1", "value2", "value3"])
        
        // Parse back
        let parsed = ListItem(fromTag: tag)
        #expect(parsed == customItem)
    }
    
    @Test("Empty tag handling")
    func testEmptyTagHandling() {
        // Empty tag should return nil
        let empty: [String] = []
        let item = ListItem(fromTag: empty)
        #expect(item == nil)
        
        // Single element tag should return nil
        let single = ["p"]
        let item2 = ListItem(fromTag: single)
        #expect(item2 == nil)
    }
}