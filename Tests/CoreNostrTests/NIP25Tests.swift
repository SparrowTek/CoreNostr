//
//  NIP25Tests.swift
//  CoreNostrTests
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-25: Reactions")
struct NIP25Tests {
    let keyPair: KeyPair
    let eventId = "a3d15b5a5e8b7b5c3f1d2e4a6b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6"
    let eventPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    
    init() throws {
        // Create a test key pair with a known private key
        let privateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
        self.keyPair = try KeyPair(privateKey: privateKeyHex)
    }
    
    @Test("Parse reaction content types")
    func testReactionContentParsing() {
        #expect(ReactionContent(from: "+") == .plus)
        #expect(ReactionContent(from: "-") == .minus)
        #expect(ReactionContent(from: "👍") == .emoji("👍"))
        #expect(ReactionContent(from: "❤️") == .emoji("❤️"))
        #expect(ReactionContent(from: ":heart:") == .customEmoji(shortcode: "heart"))
        #expect(ReactionContent(from: ":custom_emoji:") == .customEmoji(shortcode: "custom_emoji"))
        #expect(ReactionContent(from: "random text") == .emoji("random text"))
    }
    
    @Test("Reaction content string representation")
    func testReactionContentString() {
        #expect(ReactionContent.plus.content == "+")
        #expect(ReactionContent.minus.content == "-")
        #expect(ReactionContent.emoji("👍").content == "👍")
        #expect(ReactionContent.customEmoji(shortcode: "heart").content == ":heart:")
    }
    
    @Test("Reaction interpretation flags")
    func testReactionInterpretation() {
        #expect(ReactionContent.plus.isLike == true)
        #expect(ReactionContent.plus.isDislike == false)
        #expect(ReactionContent.minus.isLike == false)
        #expect(ReactionContent.minus.isDislike == true)
        #expect(ReactionContent.emoji("👍").isLike == false)
        #expect(ReactionContent.emoji("👍").isDislike == false)
    }
    
    @Test("Create simple reaction event")
    func testCreateSimpleReaction() throws {
        let event = try CoreNostr.createReaction(
            to: eventId,
            eventPubkey: eventPubkey,
            reaction: .plus,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.reaction.rawValue)
        #expect(event.content == "+")
        
        // Verify tags
        let eTags = event.tags.filter { $0[0] == "e" }
        let pTags = event.tags.filter { $0[0] == "p" }
        
        #expect(eTags.count == 1)
        #expect(eTags[0][1] == eventId)
        #expect(pTags.count == 1)
        #expect(pTags[0][1] == eventPubkey)
    }
    
    @Test("Create reaction with event kind")
    func testCreateReactionWithKind() throws {
        let event = try CoreNostr.createReaction(
            to: eventId,
            eventPubkey: eventPubkey,
            eventKind: .textNote,
            reaction: .minus,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.reaction.rawValue)
        #expect(event.content == "-")
        
        // Verify kind tag
        let kTags = event.tags.filter { $0[0] == "k" }
        #expect(kTags.count == 1)
        #expect(kTags[0][1] == "1") // textNote kind = 1
    }
    
    @Test("Create emoji reaction")
    func testCreateEmojiReaction() throws {
        let event = try CoreNostr.createReaction(
            to: eventId,
            eventPubkey: eventPubkey,
            reaction: .emoji("🚀"),
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.reaction.rawValue)
        #expect(event.content == "🚀")
    }
    
    @Test("Create custom emoji reaction")
    func testCreateCustomEmojiReaction() throws {
        let emojiURL = URL(string: "https://example.com/emoji/custom.png")!
        let event = try CoreNostr.createReaction(
            to: eventId,
            eventPubkey: eventPubkey,
            reaction: .customEmoji(shortcode: "custom"),
            customEmojiURL: emojiURL,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.reaction.rawValue)
        #expect(event.content == ":custom:")
        
        // Verify emoji tag
        let emojiTags = event.tags.filter { $0[0] == "emoji" }
        #expect(emojiTags.count == 1)
        #expect(emojiTags[0][1] == "custom")
        #expect(emojiTags[0][2] == emojiURL.absoluteString)
    }
    
    @Test("Create reaction with relay hint")
    func testCreateReactionWithRelayHint() throws {
        let relayHint = "wss://relay.example.com"
        let event = try CoreNostr.createReaction(
            to: eventId,
            eventPubkey: eventPubkey,
            reaction: .plus,
            relayHint: relayHint,
            keyPair: keyPair
        )
        
        // Verify relay hint in e tag
        let eTags = event.tags.filter { $0[0] == "e" }
        #expect(eTags[0].count == 3)
        #expect(eTags[0][2] == relayHint)
    }
    
    @Test("Create website reaction")
    func testCreateWebsiteReaction() throws {
        let url = URL(string: "https://example.com/page")!
        let event = try CoreNostr.createWebsiteReaction(
            to: url,
            reaction: .plus,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.websiteReaction.rawValue)
        #expect(event.content == "+")
        
        // Verify r tag
        let rTags = event.tags.filter { $0[0] == "r" }
        #expect(rTags.count == 1)
        #expect(rTags[0][1] == "https://example.com/page")
    }
    
    @Test("Parse reaction event")
    func testParseReaction() throws {
        let event = try CoreNostr.createReaction(
            to: eventId,
            eventPubkey: eventPubkey,
            eventKind: .textNote,
            reaction: .plus,
            relayHint: "wss://relay.example.com",
            keyPair: keyPair
        )
        
        let reaction = event.parseReaction()
        #expect(reaction != nil)
        #expect(reaction?.eventId == eventId)
        #expect(reaction?.eventPubkey == eventPubkey)
        #expect(reaction?.eventKind == .textNote)
        #expect(reaction?.reaction == .plus)
        #expect(reaction?.relayHint == "wss://relay.example.com")
    }
    
    @Test("Parse custom emoji reaction")
    func testParseCustomEmojiReaction() throws {
        let emojiURL = URL(string: "https://example.com/emoji/heart.png")!
        let event = try CoreNostr.createReaction(
            to: eventId,
            eventPubkey: eventPubkey,
            reaction: .customEmoji(shortcode: "heart"),
            customEmojiURL: emojiURL,
            keyPair: keyPair
        )
        
        let reaction = event.parseReaction()
        #expect(reaction != nil)
        #expect(reaction?.reaction == .customEmoji(shortcode: "heart"))
        #expect(reaction?.customEmojiURL == emojiURL)
    }
    
    @Test("Parse website reaction")
    func testParseWebsiteReaction() throws {
        let url = URL(string: "https://example.com/page")!
        let event = try CoreNostr.createWebsiteReaction(
            to: url,
            reaction: .emoji("👍"),
            keyPair: keyPair
        )
        
        let reaction = event.parseWebsiteReaction()
        #expect(reaction != nil)
        #expect(reaction?.url.absoluteString == "https://example.com/page")
        #expect(reaction?.reaction == .emoji("👍"))
    }
    
    @Test("URL normalization")
    func testURLNormalization() throws {
        // Test trailing slash removal
        let url1 = URL(string: "https://example.com/page/")!
        let event1 = try CoreNostr.createWebsiteReaction(
            to: url1,
            reaction: .plus,
            keyPair: keyPair
        )
        let rTag1 = event1.tags.first { $0[0] == "r" }
        #expect(rTag1?[1] == "https://example.com/page")
        
        // Test fragment removal
        let url2 = URL(string: "https://example.com/page#section")!
        let event2 = try CoreNostr.createWebsiteReaction(
            to: url2,
            reaction: .plus,
            keyPair: keyPair
        )
        let rTag2 = event2.tags.first { $0[0] == "r" }
        #expect(rTag2?[1] == "https://example.com/page")
        
        // Test case normalization
        let url3 = URL(string: "HTTPS://EXAMPLE.COM/page")!
        let event3 = try CoreNostr.createWebsiteReaction(
            to: url3,
            reaction: .plus,
            keyPair: keyPair
        )
        let rTag3 = event3.tags.first { $0[0] == "r" }
        #expect(rTag3?[1] == "https://example.com/page")
    }
    
    @Test("Invalid reaction parsing returns nil")
    func testInvalidReactionParsing() throws {
        // Create an event without required tags
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.reaction.rawValue,
            tags: [], // Missing required e and p tags
            content: "+"
        )
        
        let reaction = event.parseReaction()
        #expect(reaction == nil)
    }
    
    @Test("Non-reaction event returns nil when parsing")
    func testNonReactionEventParsing() throws {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.textNote.rawValue,
            tags: [["e", eventId], ["p", eventPubkey]],
            content: "This is not a reaction"
        )
        
        let reaction = event.parseReaction()
        let websiteReaction = event.parseWebsiteReaction()
        #expect(reaction == nil)
        #expect(websiteReaction == nil)
    }
}