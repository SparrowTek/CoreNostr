//
//  NIP17Tests.swift
//  CoreNostrTests
//
//  Tests for NIP-17: Private Direct Messages
//

import Testing
@testable import CoreNostr
import Foundation

/// Tests for NIP-17 Private Direct Messages
@Suite("NIP-17: Private Direct Messages Tests")
struct NIP17Tests {
    let aliceKeyPair: KeyPair
    let bobKeyPair: KeyPair
    let charlieKeyPair: KeyPair
    
    init() throws {
        // Create test key pairs
        aliceKeyPair = try KeyPair(privateKey: "0000000000000000000000000000000000000000000000000000000000000001")
        bobKeyPair = try KeyPair(privateKey: "0000000000000000000000000000000000000000000000000000000000000002")
        charlieKeyPair = try KeyPair(privateKey: "0000000000000000000000000000000000000000000000000000000000000003")
    }
    
    @Test("Create simple direct message")
    func testCreateSimpleDirectMessage() throws {
        let content = "Hello Bob!"
        
        let giftWraps = try NIP17.createDirectMessage(
            content: content,
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey]
        )
        
        // Should create 2 gift wraps: one for Bob, one for Alice
        #expect(giftWraps.count == 2)
        
        // All should be gift wrap events
        for wrap in giftWraps {
            #expect(wrap.kind == EventKind.giftWrap)
        }
    }
    
    @Test("Create group direct message")
    func testCreateGroupDirectMessage() throws {
        let content = "Hello everyone!"
        
        let giftWraps = try NIP17.createDirectMessage(
            content: content,
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey, charlieKeyPair.publicKey]
        )
        
        // Should create 3 gift wraps: one for each recipient + sender
        #expect(giftWraps.count == 3)
    }
    
    @Test("Create DM with subject")
    func testCreateDMWithSubject() throws {
        let content = "Let's discuss the project"
        let subject = "Project Discussion"
        
        let giftWraps = try NIP17.createDirectMessage(
            content: content,
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey],
            subject: subject
        )
        
        #expect(giftWraps.count == 2)
        
        // Verify subject is included in the rumor
        let (rumor, _) = try NIP59.unwrapAndOpen(giftWraps[1], recipientKeyPair: aliceKeyPair)
        let extractedSubject = NIP17.extractSubject(from: rumor)
        #expect(extractedSubject == subject)
    }
    
    @Test("Create reply message")
    func testCreateReplyMessage() throws {
        let replyToId = "1234567890abcdef"
        let content = "I agree!"
        
        let giftWraps = try NIP17.createDirectMessage(
            content: content,
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey],
            replyTo: replyToId
        )
        
        #expect(giftWraps.count == 2)
        
        // Verify reply tag is included
        let (rumor, _) = try NIP59.unwrapAndOpen(giftWraps[1], recipientKeyPair: aliceKeyPair)
        let extractedReplyTo = NIP17.extractReplyTo(from: rumor)
        #expect(extractedReplyTo == replyToId)
    }
    
    @Test("Receive and decrypt direct message")
    func testReceiveDirectMessage() throws {
        let content = "Secret message"
        
        // Alice sends to Bob
        let giftWraps = try NIP17.createDirectMessage(
            content: content,
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey]
        )
        
        // Find Bob's gift wrap
        let bobsWrap = giftWraps.first { wrap in
            wrap.tags.contains { tag in
                tag.count >= 2 && tag[0] == "p" && tag[1] == bobKeyPair.publicKey
            }
        }
        
        guard let bobsWrap = bobsWrap else {
            Issue.record("Bob's gift wrap not found")
            return
        }
        
        // Bob receives and decrypts
        let (message, senderPubkey) = try NIP17.receiveDirectMessage(
            bobsWrap,
            recipientKeyPair: bobKeyPair
        )
        
        #expect(message.content == content)
        #expect(senderPubkey == aliceKeyPair.publicKey)
        #expect(message.kind == EventKind.directMessage)
    }
    
    @Test("Create file message")
    func testCreateFileMessage() throws {
        let fileUrl = "https://example.com/encrypted-file.jpg"
        let fileType = "image/jpeg"
        let encryptionKey = "abcdef1234567890abcdef1234567890"
        let encryptionNonce = "1234567890abcdef"
        let fileHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        
        let giftWraps = try NIP17.createFileMessage(
            fileUrl: fileUrl,
            fileType: fileType,
            encryptionKey: encryptionKey,
            encryptionNonce: encryptionNonce,
            fileHash: fileHash,
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey]
        )
        
        #expect(giftWraps.count == 2)
        
        // Verify file metadata
        let (rumor, _) = try NIP59.unwrapAndOpen(giftWraps[1], recipientKeyPair: aliceKeyPair)
        #expect(rumor.kind == EventKind.fileMessage)
        #expect(rumor.content == fileUrl)
        
        // Check file metadata tags
        let tags = rumor.tags
        #expect(tags.contains(["file-type", fileType]))
        #expect(tags.contains(["encryption-algorithm", "aes-gcm"]))
        #expect(tags.contains(["decryption-key", encryptionKey]))
        #expect(tags.contains(["decryption-nonce", encryptionNonce]))
        #expect(tags.contains(["x", fileHash]))
    }
    
    @Test("File message with additional metadata")
    func testFileMessageWithMetadata() throws {
        let additionalMetadata = [
            "size": "1048576",
            "dim": "1920x1080",
            "blurhash": "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
            "thumb": "https://example.com/thumb.jpg"
        ]
        
        let giftWraps = try NIP17.createFileMessage(
            fileUrl: "https://example.com/file.mp4",
            fileType: "video/mp4",
            encryptionKey: "key123",
            encryptionNonce: "nonce123",
            fileHash: "hash123",
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey],
            additionalMetadata: additionalMetadata
        )
        
        let (rumor, _) = try NIP59.unwrapAndOpen(giftWraps[1], recipientKeyPair: aliceKeyPair)
        
        // Check additional metadata tags
        #expect(rumor.tags.contains(["size", "1048576"]))
        #expect(rumor.tags.contains(["dim", "1920x1080"]))
        #expect(rumor.tags.contains(["blurhash", "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"]))
        #expect(rumor.tags.contains(["thumb", "https://example.com/thumb.jpg"]))
    }
    
    @Test("Extract participants from DM")
    func testExtractParticipants() throws {
        let giftWraps = try NIP17.createDirectMessage(
            content: "Group message",
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey, charlieKeyPair.publicKey]
        )
        
        guard let lastWrap = giftWraps.last else {
            Issue.record("No gift wraps created")
            return
        }
        let (rumor, _) = try NIP59.unwrapAndOpen(lastWrap, recipientKeyPair: aliceKeyPair)
        let participants = NIP17.extractParticipants(from: rumor)
        
        #expect(participants.count == 3)
        #expect(participants.contains(aliceKeyPair.publicKey))
        #expect(participants.contains(bobKeyPair.publicKey))
        #expect(participants.contains(charlieKeyPair.publicKey))
    }
    
    @Test("Create DM inbox preference")
    func testCreateInboxPreference() throws {
        let relayUrls = [
            "wss://inbox.nostr.wine",
            "wss://relay.damus.io"
        ]
        
        let event = try NIP17.createInboxPreference(
            relayUrls: relayUrls,
            keyPair: aliceKeyPair
        )
        
        #expect(event.kind == EventKind.dmInboxPreference)
        #expect(event.tags.count == 2)
        #expect(event.tags[0] == ["relay", "wss://inbox.nostr.wine"])
        #expect(event.tags[1] == ["relay", "wss://relay.damus.io"])
        #expect(event.content == "")
    }
    
    @Test("Filter for gift-wrapped DMs")
    func testGiftWrappedDMFilter() {
        let filter = Filter.giftWrappedDMs(
            recipient: aliceKeyPair.publicKey,
            since: 1234567890,
            limit: 50
        )
        
        #expect(filter.kinds == [EventKind.giftWrap])
        #expect(filter.p == [aliceKeyPair.publicKey])
        #expect(filter.since == 1234567890)
        #expect(filter.limit == 50)
    }
    
    @Test("Filter for DM inbox preferences")
    func testInboxPreferencesFilter() {
        let pubkeys = [aliceKeyPair.publicKey, bobKeyPair.publicKey]
        let filter = Filter.dmInboxPreferences(for: pubkeys)
        
        #expect(filter.kinds == [EventKind.dmInboxPreference])
        #expect(filter.authors == pubkeys)
        #expect(filter.limit == 2)
    }
    
    @Test("Verify sender matches seal")
    func testVerifySenderMatchesSeal() throws {
        // Create a message
        let giftWraps = try NIP17.createDirectMessage(
            content: "Test",
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey]
        )
        
        let bobsWrap = giftWraps.first { wrap in
            wrap.tags.contains { tag in
                tag.count >= 2 && tag[0] == "p" && tag[1] == bobKeyPair.publicKey
            }
        }!
        
        // Normal receive should work
        let (_, senderPubkey) = try NIP17.receiveDirectMessage(
            bobsWrap,
            recipientKeyPair: bobKeyPair
        )
        
        #expect(senderPubkey == aliceKeyPair.publicKey)
    }
    
    @Test("DM with relay URLs")
    func testDMWithRelayUrls() throws {
        let relayUrls = [
            bobKeyPair.publicKey: "wss://relay.example.com",
            charlieKeyPair.publicKey: "wss://another.relay.com"
        ]
        
        let giftWraps = try NIP17.createDirectMessage(
            content: "Hello with relays",
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey, charlieKeyPair.publicKey],
            relayUrls: relayUrls
        )
        
        // Check Bob's wrap has relay URL
        let bobsWrap = giftWraps.first { wrap in
            wrap.tags.contains { tag in
                tag.count >= 3 && tag[0] == "p" && tag[1] == bobKeyPair.publicKey && tag[2] == "wss://relay.example.com"
            }
        }
        
        #expect(bobsWrap != nil)
    }
    
    @Test("Empty recipients should throw")
    func testEmptyRecipientsThrows() throws {
        #expect(throws: NIP17.DMError.invalidRecipients) {
            _ = try NIP17.createDirectMessage(
                content: "Test",
                senderKeyPair: aliceKeyPair,
                recipientPublicKeys: []
            )
        }
    }
    
    @Test("Empty message content should throw")
    func testEmptyContentThrows() throws {
        #expect(throws: NIP17.DMError.invalidMessage) {
            _ = try NIP17.createDirectMessage(
                content: "",
                senderKeyPair: aliceKeyPair,
                recipientPublicKeys: [bobKeyPair.publicKey]
            )
        }
    }
    
    @Test("Multiple messages conversation flow")
    func testConversationFlow() throws {
        // Alice sends initial message
        let message1Wraps = try NIP17.createDirectMessage(
            content: "Hey Bob, how are you?",
            senderKeyPair: aliceKeyPair,
            recipientPublicKeys: [bobKeyPair.publicKey],
            subject: "Catching up"
        )
        
        let bobsWrap1 = message1Wraps.first { $0.tags.contains { $0.count >= 2 && $0[0] == "p" && $0[1] == bobKeyPair.publicKey } }!
        let (message1, _) = try NIP17.receiveDirectMessage(bobsWrap1, recipientKeyPair: bobKeyPair)
        
        // Extract event ID for reply (in real implementation, would calculate proper ID)
        let message1Id = "mock-message-1-id"
        
        // Bob replies
        let message2Wraps = try NIP17.createDirectMessage(
            content: "I'm doing great! How about you?",
            senderKeyPair: bobKeyPair,
            recipientPublicKeys: [aliceKeyPair.publicKey],
            replyTo: message1Id
        )
        
        let alicesWrap2 = message2Wraps.first { $0.tags.contains { $0.count >= 2 && $0[0] == "p" && $0[1] == aliceKeyPair.publicKey } }!
        let (message2, _) = try NIP17.receiveDirectMessage(alicesWrap2, recipientKeyPair: aliceKeyPair)
        
        // Verify conversation structure
        #expect(NIP17.extractSubject(from: message1) == "Catching up")
        #expect(NIP17.extractReplyTo(from: message2) == message1Id)
        
        // Both messages should have same participants
        let participants1 = NIP17.extractParticipants(from: message1)
        let participants2 = NIP17.extractParticipants(from: message2)
        #expect(participants1 == participants2)
    }
}

// MARK: - Test Helpers

extension Array where Element == [String] {
    func contains(_ element: [String]) -> Bool {
        return self.contains { $0 == element }
    }
}