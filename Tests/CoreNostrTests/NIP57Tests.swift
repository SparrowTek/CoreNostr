//
//  NIP57Tests.swift
//  CoreNostrTests
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-57: Lightning Zaps")
struct NIP57Tests {
    let keyPair: KeyPair
    let recipientPubkey = "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"
    
    init() throws {
        let privateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
        self.keyPair = try KeyPair(privateKey: privateKeyHex)
    }
    
    @Test("Create ZapRequest")
    func testCreateZapRequest() {
        let zapRequest = ZapRequest(
            amount: 1000,
            recipientPubkey: recipientPubkey,
            relays: ["wss://relay1.com", "wss://relay2.com"],
            eventId: "event123",
            content: "Great post!"
        )
        
        #expect(zapRequest.amount == 1000)
        #expect(zapRequest.recipientPubkey == recipientPubkey)
        #expect(zapRequest.relays.count == 2)
        #expect(zapRequest.eventId == "event123")
        #expect(zapRequest.content == "Great post!")
        
        let tags = zapRequest.toTags()
        #expect(tags.contains(["relays", "wss://relay1.com", "wss://relay2.com"]))
        #expect(tags.contains(["amount", "1000"]))
        #expect(tags.contains(["p", recipientPubkey]))
        #expect(tags.contains(["e", "event123"]))
    }
    
    @Test("Create zap request event for user")
    func testCreateZapRequestEventForUser() throws {
        let event = try CoreNostr.createZapRequestForUser(
            recipientPubkey: recipientPubkey,
            amount: 5000,
            relays: ["wss://relay.nostr.com"],
            comment: "Thanks for your work!",
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.zapRequest.rawValue)
        #expect(event.content == "Thanks for your work!")
        
        let tags = event.tags
        #expect(tags.contains(["relays", "wss://relay.nostr.com"]))
        #expect(tags.contains(["amount", "5000"]))
        #expect(tags.contains(["p", recipientPubkey]))
        
        // Should not have event tag for user zaps
        #expect(!tags.contains { $0.first == "e" })
    }
    
    @Test("Create zap request event for event")
    func testCreateZapRequestEventForEvent() throws {
        let eventId = "45326f5d6962881b52ba562a2e5e0b43c90e6e3c5f30a1c7e305c6b99f5f1a5e"
        
        let event = try CoreNostr.createZapRequestForEvent(
            eventId: eventId,
            eventAuthorPubkey: recipientPubkey,
            amount: 2100,
            relays: ["wss://relay1.com", "wss://relay2.com"],
            comment: "⚡️",
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.zapRequest.rawValue)
        #expect(event.content == "⚡️")
        
        let tags = event.tags
        #expect(tags.contains(["e", eventId]))
        #expect(tags.contains(["p", recipientPubkey]))
        #expect(tags.contains(["amount", "2100"]))
    }
    
    @Test("Parse zap request from event")
    func testParseZapRequest() throws {
        let zapRequest = ZapRequest(
            amount: 10000,
            recipientPubkey: recipientPubkey,
            relays: ["wss://relay.example.com"],
            eventId: "event456",
            eventCoordinate: "30023:author:article",
            content: "Zapping your article",
            lnurl: "lnurl1234"
        )
        
        let event = try CoreNostr.createZapRequest(zapRequest, keyPair: keyPair)
        
        #expect(event.isZapRequest)
        #expect(!event.isZapReceipt)
        
        let parsed = event.parseZapRequest()
        #expect(parsed != nil)
        #expect(parsed?.amount == 10000)
        #expect(parsed?.recipientPubkey == recipientPubkey)
        #expect(parsed?.relays == ["wss://relay.example.com"])
        #expect(parsed?.eventId == "event456")
        #expect(parsed?.eventCoordinate == "30023:author:article")
        #expect(parsed?.content == "Zapping your article")
        #expect(parsed?.lnurl == "lnurl1234")
    }
    
    @Test("Parse zap receipt")
    func testParseZapReceipt() throws {
        // Create a mock zap request first
        let zapRequestEvent = try CoreNostr.createZapRequestForUser(
            recipientPubkey: recipientPubkey,
            amount: 1000,
            relays: ["wss://relay.com"],
            keyPair: keyPair
        )
        
        let zapRequestJSON = try JSONEncoder().encode(zapRequestEvent)
        let zapRequestString = String(data: zapRequestJSON, encoding: .utf8)!
        
        // Create a zap receipt event
        let receiptEvent = NostrEvent(
            pubkey: "lightningprovider",
            kind: EventKind.zapReceipt.rawValue,
            tags: [
                ["p", recipientPubkey],
                ["P", keyPair.publicKey],
                ["bolt11", "lnbc1000n1234..."],
                ["description", zapRequestString],
                ["preimage", "0123456789abcdef"]
            ],
            content: ""
        )
        
        #expect(receiptEvent.isZapReceipt)
        #expect(!receiptEvent.isZapRequest)
        
        let receipt = receiptEvent.parseZapReceipt()
        #expect(receipt != nil)
        #expect(receipt?.recipientPubkey == recipientPubkey)
        #expect(receipt?.senderPubkey == keyPair.publicKey)
        #expect(receipt?.bolt11 == "lnbc1000n1234...")
        #expect(receipt?.preimage == "0123456789abcdef")
        
        // Parse the original zap request
        let originalRequest = try receipt?.parseZapRequest()
        #expect(originalRequest != nil)
        #expect(originalRequest?.kind == EventKind.zapRequest.rawValue)
    }
    
    @Test("Lightning address parsing")
    func testLightningAddressParsing() {
        // Valid address
        let address = "alice@example.com"
        let parsed = LightningAddress.parse(address)
        #expect(parsed?.name == "alice")
        #expect(parsed?.domain == "example.com")
        
        // Get callback URL
        let callbackURL = LightningAddress.getLNURLCallback(for: address)
        #expect(callbackURL?.absoluteString == "https://example.com/.well-known/lnurlp/alice")
        
        // Invalid addresses
        #expect(LightningAddress.parse("notanemail") == nil)
        #expect(LightningAddress.parse("@example.com") == nil)
        #expect(LightningAddress.parse("alice@") == nil)
    }
    
    @Test("Extract lightning address from metadata")
    func testExtractLightningAddressFromMetadata() {
        // With lud16 (Lightning address)
        let metadata1: [String: Any] = [
            "name": "Alice",
            "lud16": "alice@lightning.example.com"
        ]
        #expect(LightningAddress.fromMetadata(metadata1) == "alice@lightning.example.com")
        
        // With lud06 (LNURL - should return nil)
        let metadata2: [String: Any] = [
            "name": "Bob",
            "lud06": "LNURL1DP68GURN8GHJ7..."
        ]
        #expect(LightningAddress.fromMetadata(metadata2) == nil)
        
        // No lightning info
        let metadata3: [String: Any] = [
            "name": "Charlie"
        ]
        #expect(LightningAddress.fromMetadata(metadata3) == nil)
    }
    
    @Test("Zap amount from receipt")
    func testZapAmountFromReceipt() throws {
        // Create a zap request with amount
        let zapRequestEvent = try CoreNostr.createZapRequestForUser(
            recipientPubkey: recipientPubkey,
            amount: 21000,
            relays: ["wss://relay.com"],
            keyPair: keyPair
        )
        
        let zapRequestJSON = try JSONEncoder().encode(zapRequestEvent)
        let zapRequestString = String(data: zapRequestJSON, encoding: .utf8)!
        
        // Create receipt
        let receiptEvent = NostrEvent(
            pubkey: "lightningprovider",
            kind: EventKind.zapReceipt.rawValue,
            tags: [
                ["p", recipientPubkey],
                ["bolt11", "lnbc21000n1234..."],
                ["description", zapRequestString]
            ],
            content: ""
        )
        
        #expect(receiptEvent.zapAmount == 21000)
    }
    
    @Test("Zap statistics")
    func testZapStatistics() throws {
        let eventId = "event123"
        let userPubkey = recipientPubkey
        
        // Create some mock zap receipts
        var receipts: [NostrEvent] = []
        
        // Receipt 1: 1000 sats to event
        let zapRequest1 = try CoreNostr.createZapRequestForEvent(
            eventId: eventId,
            eventAuthorPubkey: userPubkey,
            amount: 1000,
            relays: ["wss://relay.com"],
            keyPair: keyPair
        )
        let zapRequestJSON1 = try JSONEncoder().encode(zapRequest1)
        
        receipts.append(NostrEvent(
            pubkey: "provider",
            kind: EventKind.zapReceipt.rawValue,
            tags: [
                ["p", userPubkey],
                ["e", eventId],
                ["P", "sender1"],
                ["bolt11", "lnbc1000n..."],
                ["description", String(data: zapRequestJSON1, encoding: .utf8)!]
            ],
            content: ""
        ))
        
        // Receipt 2: 5000 sats to event
        let zapRequest2 = try CoreNostr.createZapRequestForEvent(
            eventId: eventId,
            eventAuthorPubkey: userPubkey,
            amount: 5000,
            relays: ["wss://relay.com"],
            keyPair: keyPair
        )
        let zapRequestJSON2 = try JSONEncoder().encode(zapRequest2)
        
        receipts.append(NostrEvent(
            pubkey: "provider",
            kind: EventKind.zapReceipt.rawValue,
            tags: [
                ["p", userPubkey],
                ["e", eventId],
                ["P", "sender2"],
                ["bolt11", "lnbc5000n..."],
                ["description", String(data: zapRequestJSON2, encoding: .utf8)!]
            ],
            content: ""
        ))
        
        // Test event stats
        let eventStats = ZapStats.totalZapsForEvent(eventId, from: receipts)
        #expect(eventStats.count == 2)
        #expect(eventStats.totalAmount == 6000)
        
        // Test user stats
        let userStats = ZapStats.totalZapsForUser(userPubkey, from: receipts)
        #expect(userStats.count == 2)
        #expect(userStats.totalAmount == 6000)
        
        // Test top zappers
        let topZappers = ZapStats.topZappers(from: receipts)
        #expect(topZappers.count == 2)
        #expect(topZappers[0].pubkey == "sender2")
        #expect(topZappers[0].totalAmount == 5000)
        #expect(topZappers[1].pubkey == "sender1")
        #expect(topZappers[1].totalAmount == 1000)
    }
    
    @Test("Zap receipt filter")
    func testZapReceiptFilter() {
        let eventId = "event123"
        let recipient = "recipient123"
        let sender = "sender123"
        let since = Date(timeIntervalSince1970: 1000000)
        let until = Date(timeIntervalSince1970: 2000000)
        
        let filter = Filter.zapReceipts(
            for: eventId,
            recipient: recipient,
            sender: sender,
            since: since,
            until: until,
            limit: 100
        )
        
        #expect(filter.kinds == [EventKind.zapReceipt.rawValue])
        #expect(filter.e == [eventId])
        #expect(filter.p == [recipient])
        // Note: sender filtering would need to be done client-side
        #expect(filter.since == 1000000)
        #expect(filter.until == 2000000)
        #expect(filter.limit == 100)
    }
    
    @Test("Invalid zap request parsing")
    func testInvalidZapRequestParsing() {
        // Missing required tags
        let invalidEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.zapRequest.rawValue,
            tags: [["p", recipientPubkey]], // Missing relays and amount
            content: ""
        )
        
        let parsed = invalidEvent.parseZapRequest()
        #expect(parsed == nil)
    }
    
    @Test("Invalid zap receipt parsing")
    func testInvalidZapReceiptParsing() {
        // Wrong event kind
        let wrongKindEvent = NostrEvent(
            pubkey: "provider",
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: ""
        )
        
        #expect(wrongKindEvent.parseZapReceipt() == nil)
        
        // Missing required tags
        let invalidEvent = NostrEvent(
            pubkey: "provider",
            kind: EventKind.zapReceipt.rawValue,
            tags: [["p", recipientPubkey]], // Missing bolt11 and description
            content: ""
        )
        
        #expect(invalidEvent.parseZapReceipt() == nil)
    }
}