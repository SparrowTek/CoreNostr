import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-Specific Fixtures: Real-world test vectors")
struct NIPFixtures {
    
    // MARK: - NIP-04 Legacy Direct Messages
    
    @Test("NIP-04 legacy DM encryption/decryption")
    func testNIP04LegacyDM() throws {
        // Test vector for NIP-04 legacy encrypted direct messages
        let senderKeyPair = try KeyPair(privateKey: "5a0e7d3e5f8c3a2b1d9e4f6c8b3a7d2e9f4c6b8a3d7e2f9c4b6a8d3e7f2c9b4a")
        let recipientKeyPair = try KeyPair(privateKey: "6b1f8d4a7c2e9b5f3a8d7e2c9f4b6a8d3e7f2c9b4a5e8c3a2b1d9e4f6c8b3a7d")
        
        let message = "Hello from NIP-04! This is a legacy encrypted message."
        
        // Create encrypted DM event
        let dmEvent = try CoreNostr.createDirectMessageEvent(
            senderKeyPair: senderKeyPair,
            recipientPublicKey: recipientKeyPair.publicKey,
            message: message,
            replyToEventId: nil
        )
        
        // Verify event structure
        #expect(dmEvent.kind == 4)
        #expect(dmEvent.tags.contains { $0.first == "p" && $0[safe: 1] == recipientKeyPair.publicKey })
        #expect(dmEvent.content.contains("?iv=")) // NIP-04 format includes IV
        
        // Decrypt message
        let decrypted = try CoreNostr.decryptDirectMessage(
            event: dmEvent,
            recipientKeyPair: recipientKeyPair
        )
        
        #expect(decrypted == message)
    }
    
    @Test("NIP-04 DM with reply tag")
    func testNIP04DMWithReply() throws {
        let senderKeyPair = try KeyPair.generate()
        let recipientKeyPair = try KeyPair.generate()
        let replyToEventId = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        
        let dmEvent = try CoreNostr.createDirectMessageEvent(
            senderKeyPair: senderKeyPair,
            recipientPublicKey: recipientKeyPair.publicKey,
            message: "This is a reply",
            replyToEventId: replyToEventId
        )
        
        // Should have both p and e tags
        #expect(dmEvent.tags.count == 2)
        #expect(dmEvent.tags.contains { $0 == ["p", recipientKeyPair.publicKey] })
        #expect(dmEvent.tags.contains { $0 == ["e", replyToEventId] })
    }
    
    // MARK: - NIP-17/44 Private Direct Messages
    
    @Test("NIP-44 encrypted payload format")
    func testNIP44PayloadFormat() throws {
        let senderKeyPair = try KeyPair.generate()
        let recipientKeyPair = try KeyPair.generate()
        
        let plaintext = "Modern encrypted message using NIP-44 🔐"
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: senderKeyPair.privateKey,
            recipientPublicKey: recipientKeyPair.publicKey
        )
        
        // Verify payload structure
        let payloadData = Data(base64Encoded: encrypted)!
        
        // Version byte should be 0x02
        #expect(payloadData[0] == 0x02)
        
        // Should have nonce (32 bytes), ciphertext, and MAC (32 bytes)
        #expect(payloadData.count >= 65) // 1 + 32 + min_ciphertext + 32
        
        // Decrypt and verify
        let decrypted = try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: recipientKeyPair.privateKey,
            senderPublicKey: senderKeyPair.publicKey
        )
        
        #expect(decrypted == plaintext)
    }
    
    @Test("NIP-17 private direct message event structure")
    func testNIP17PrivateDMStructure() throws {
        // NIP-17 wraps NIP-44 encrypted content in specific event kinds
        let senderKeyPair = try KeyPair.generate()
        let recipientPublicKey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        
        // Create a seal event (kind 13)
        let rumor = NostrEvent(
            pubkey: senderKeyPair.publicKey,
            createdAt: Date(),
            kind: 14, // Chat message kind
            tags: [],
            content: "Private message content"
        )
        
        // This would be encrypted and wrapped
        // Testing the structure expectations
        #expect(rumor.kind == 14)
        #expect(!rumor.content.isEmpty)
    }
    
    // MARK: - NIP-57 Lightning Zaps
    
    @Test("NIP-57 zap request event")
    func testNIP57ZapRequest() throws {
        let zapperPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let recipientPubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let eventToZap = "abc0000000000000000000000000000000000000000000000000000000000123"
        
        // Create zap request event (kind 9734)
        let zapRequest = NostrEvent(
            pubkey: zapperPubkey,
            createdAt: Date(),
            kind: 9734,
            tags: [
                ["p", recipientPubkey],
                ["e", eventToZap],
                ["amount", "21000"], // millisats
                ["relays", "wss://relay.damus.io", "wss://nos.lol"],
                ["lnurl", "lnurl1dp68gurn8ghj7..."] // truncated for example
            ],
            content: "Zapping your post! ⚡"
        )
        
        #expect(zapRequest.kind == 9734)
        #expect(zapRequest.tags.contains { $0.first == "p" })
        #expect(zapRequest.tags.contains { $0.first == "e" })
        #expect(zapRequest.tags.contains { $0.first == "amount" })
    }
    
    @Test("NIP-57 zap receipt event")
    func testNIP57ZapReceipt() throws {
        let zapServicePubkey = "be1d89794bf92de5dd64c1e60f6a2c70c140abac9932418fee30c5c637fe9479"
        let zappedPubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let zappedEvent = "abc0000000000000000000000000000000000000000000000000000000000123"
        
        // Zap receipt (kind 9735)
        let zapReceipt = NostrEvent(
            pubkey: zapServicePubkey,
            createdAt: Date(),
            kind: 9735,
            tags: [
                ["p", zappedPubkey],
                ["e", zappedEvent],
                ["bolt11", "lnbc21u1p3..."], // Lightning invoice
                ["description", "{\"pubkey\":\"...\",\"content\":\"...\",\"kind\":9734}"], // JSON zap request
                ["preimage", "0000000000000000000000000000000000000000000000000000000000000000"]
            ],
            content: ""
        )
        
        #expect(zapReceipt.kind == 9735)
        #expect(zapReceipt.tags.contains { $0.first == "bolt11" })
        #expect(zapReceipt.tags.contains { $0.first == "description" })
    }
    
    // MARK: - NIP-65 Relay List Metadata
    
    @Test("NIP-65 relay list event")
    func testNIP65RelayList() throws {
        let userPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        
        // Relay list metadata (kind 10002)
        let relayList = NostrEvent(
            pubkey: userPubkey,
            createdAt: Date(),
            kind: 10002,
            tags: [
                ["r", "wss://relay.damus.io"],
                ["r", "wss://nos.lol", "read"],
                ["r", "wss://relay.nostr.band", "write"],
                ["r", "wss://purplepag.es", "read"],
                ["r", "wss://relay.current.fyi", "write"]
            ],
            content: ""
        )
        
        #expect(relayList.kind == 10002)
        
        // Parse relay list
        let relays = relayList.tags.filter { $0.first == "r" }
        #expect(relays.count == 5)
        
        // Check read/write markers
        let readRelays = relays.filter { $0.count > 2 && $0[2] == "read" }
        let writeRelays = relays.filter { $0.count > 2 && $0[2] == "write" }
        let generalRelays = relays.filter { $0.count == 2 } // No marker means both read and write
        
        #expect(readRelays.count == 2)
        #expect(writeRelays.count == 2)
        #expect(generalRelays.count == 1)
    }
    
    // MARK: - NIP-10 Threading
    
    @Test("NIP-10 thread structure with markers")
    func testNIP10ThreadingWithMarkers() throws {
        let authorPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let rootEventId = "root0000000000000000000000000000000000000000000000000000000000001"
        let replyToEventId = "reply000000000000000000000000000000000000000000000000000000000002"
        let mentionEventId = "mention0000000000000000000000000000000000000000000000000000000003"
        
        // Reply with proper threading
        let threadedReply = NostrEvent(
            pubkey: authorPubkey,
            createdAt: Date(),
            kind: 1,
            tags: [
                ["e", rootEventId, "wss://relay.example.com", "root"],
                ["e", replyToEventId, "wss://relay.example.com", "reply"],
                ["e", mentionEventId, "", "mention"],
                ["p", "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"],
                ["p", "def0000000000000000000000000000000000000000000000000000000000456"]
            ],
            content: "This is a properly threaded reply mentioning other events"
        )
        
        // Verify thread structure
        let eTags = threadedReply.tags.filter { $0.first == "e" }
        #expect(eTags.count == 3)
        
        // Find root
        let rootTag = eTags.first { $0.count > 3 && $0[3] == "root" }
        #expect(rootTag?[1] == rootEventId)
        
        // Find reply
        let replyTag = eTags.first { $0.count > 3 && $0[3] == "reply" }
        #expect(replyTag?[1] == replyToEventId)
        
        // Find mention
        let mentionTag = eTags.first { $0.count > 3 && $0[3] == "mention" }
        #expect(mentionTag?[1] == mentionEventId)
    }
    
    @Test("NIP-10 deprecated threading (positional)")
    func testNIP10DeprecatedThreading() throws {
        // Deprecated NIP-10 threading uses position instead of markers
        let authorPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let rootEventId = "root0000000000000000000000000000000000000000000000000000000000001"
        let replyToEventId = "reply000000000000000000000000000000000000000000000000000000000002"
        
        let deprecatedReply = NostrEvent(
            pubkey: authorPubkey,
            createdAt: Date(),
            kind: 1,
            tags: [
                ["e", rootEventId],     // First e tag is root
                ["e", replyToEventId],  // Last e tag is reply-to
                ["p", "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]
            ],
            content: "Reply using deprecated positional threading"
        )
        
        let eTags = deprecatedReply.tags.filter { $0.first == "e" }
        #expect(eTags.count == 2)
        #expect(eTags.first?[1] == rootEventId)  // First is root
        #expect(eTags.last?[1] == replyToEventId) // Last is reply-to
    }
    
    // MARK: - Complex Event Fixtures
    
    @Test("Long-form content event (NIP-23)")
    func testLongFormContent() throws {
        let authorPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        
        let article = NostrEvent(
            pubkey: authorPubkey,
            createdAt: Date(),
            kind: 30023,
            tags: [
                ["d", "my-first-article"],
                ["title", "Introduction to Nostr"],
                ["summary", "A comprehensive guide to the Nostr protocol"],
                ["published_at", "1700000000"],
                ["t", "nostr"],
                ["t", "protocol"],
                ["t", "decentralized"],
                ["image", "https://example.com/header.jpg"],
                ["a", "30023:\(authorPubkey):related-article"]
            ],
            content: """
            # Introduction to Nostr
            
            Nostr is a simple, open protocol that enables truly censorship-resistant 
            global social networking.
            
            ## Key Features
            
            - Decentralized
            - Cryptographically secure
            - No single point of failure
            
            ## How It Works
            
            Users are identified by public keys...
            """
        )
        
        #expect(article.kind == 30023)
        
        // Verify required tags
        let dTag = article.tags.first { $0.first == "d" }
        #expect(dTag?[1] == "my-first-article")
        
        let titleTag = article.tags.first { $0.first == "title" }
        #expect(titleTag?[1] == "Introduction to Nostr")
        
        // Count hashtags
        let hashtags = article.tags.filter { $0.first == "t" }
        #expect(hashtags.count == 3)
    }
    
    @Test("Reaction event with custom emoji")
    func testReactionWithCustomEmoji() throws {
        let reactorPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        let reactedEventId = "abc0000000000000000000000000000000000000000000000000000000000123"
        let reactedAuthor = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        
        // Custom emoji reaction
        let reaction = NostrEvent(
            pubkey: reactorPubkey,
            createdAt: Date(),
            kind: 7,
            tags: [
                ["e", reactedEventId],
                ["p", reactedAuthor],
                ["emoji", "sats", "https://example.com/emojis/sats.png"]
            ],
            content: ":sats:"
        )
        
        #expect(reaction.kind == 7)
        #expect(reaction.content == ":sats:")
        
        // Verify emoji tag
        let emojiTag = reaction.tags.first { $0.first == "emoji" }
        #expect(emojiTag?[1] == "sats")
        #expect(emojiTag?[2] == "https://example.com/emojis/sats.png")
    }
}