//
//  NIP57.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// NIP-57: Lightning Zaps
/// https://github.com/nostr-protocol/nips/blob/master/57.md
///
/// Defines how to send Bitcoin Lightning tips (zaps) to Nostr users and events.

// MARK: - Zap Request

/// A zap request that will be sent to a Lightning service
public struct ZapRequest: Sendable {
    /// The amount in millisatoshis
    public let amount: Int64
    
    /// The recipient's public key
    public let recipientPubkey: String
    
    /// The relays where the zap receipt should be published
    public let relays: [String]
    
    /// Optional event ID being zapped
    public let eventId: String?
    
    /// Optional event coordinate for parameterized replaceable events
    public let eventCoordinate: String?
    
    /// Optional comment/message with the zap
    public let content: String
    
    /// Optional lnurl override
    public let lnurl: String?
    
    /// Initialize a zap request
    public init(
        amount: Int64,
        recipientPubkey: String,
        relays: [String],
        eventId: String? = nil,
        eventCoordinate: String? = nil,
        content: String = "",
        lnurl: String? = nil
    ) {
        self.amount = amount
        self.recipientPubkey = recipientPubkey
        self.relays = relays
        self.eventId = eventId
        self.eventCoordinate = eventCoordinate
        self.content = content
        self.lnurl = lnurl
    }
    
    /// Create tags for the zap request event
    public func toTags() -> [[String]] {
        var tags: [[String]] = []
        
        // Required tags
        tags.append(["relays"] + relays)
        tags.append(["amount", String(amount)])
        tags.append(["p", recipientPubkey])
        
        // Optional tags
        if let eventId = eventId {
            tags.append(["e", eventId])
        }
        
        if let eventCoordinate = eventCoordinate {
            tags.append(["a", eventCoordinate])
        }
        
        if let lnurl = lnurl {
            tags.append(["lnurl", lnurl])
        }
        
        return tags
    }
}

// MARK: - Zap Receipt

/// A zap receipt published by the Lightning service after payment
public struct ZapReceipt: Sendable {
    /// The zap recipient's public key
    public let recipientPubkey: String
    
    /// The Lightning invoice (bolt11)
    public let bolt11: String
    
    /// The original zap request (JSON encoded)
    public let zapRequest: String
    
    /// Optional zap sender's public key
    public let senderPubkey: String?
    
    /// Optional event ID that was zapped
    public let eventId: String?
    
    /// Optional event coordinate that was zapped
    public let eventCoordinate: String?
    
    /// Optional payment preimage (proof of payment)
    public let preimage: String?
    
    /// Initialize from a NostrEvent
    public init?(from event: NostrEvent) {
        guard event.kind == EventKind.zapReceipt.rawValue else { return nil }
        
        // Find required tags
        guard let pTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "p" }),
              let bolt11Tag = event.tags.first(where: { $0.count >= 2 && $0[0] == "bolt11" }),
              let descTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "description" }) else {
            return nil
        }
        
        self.recipientPubkey = pTag[1]
        self.bolt11 = bolt11Tag[1]
        self.zapRequest = descTag[1]
        
        // Optional tags
        self.senderPubkey = event.tags.first(where: { $0.count >= 2 && $0[0] == "P" })?[1]
        self.eventId = event.tags.first(where: { $0.count >= 2 && $0[0] == "e" })?[1]
        self.eventCoordinate = event.tags.first(where: { $0.count >= 2 && $0[0] == "a" })?[1]
        self.preimage = event.tags.first(where: { $0.count >= 2 && $0[0] == "preimage" })?[1]
    }
    
    /// Parse the original zap request from the receipt
    public func parseZapRequest() throws -> NostrEvent? {
        guard let data = zapRequest.data(using: .utf8),
              let eventDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Convert back to NostrEvent
        let eventData = try JSONSerialization.data(withJSONObject: eventDict)
        return try JSONDecoder().decode(NostrEvent.self, from: eventData)
    }
}

// MARK: - Lightning Address

/// Utilities for working with Lightning addresses and LNURL
public struct LightningAddress: Sendable {
    /// Parse a Lightning address (e.g., "alice@example.com")
    public static func parse(_ address: String) -> (name: String, domain: String)? {
        let parts = address.split(separator: "@")
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }
    
    /// Get the LNURL callback URL for a Lightning address
    public static func getLNURLCallback(for address: String) -> URL? {
        guard let (name, domain) = parse(address) else { return nil }
        return URL(string: "https://\(domain)/.well-known/lnurlp/\(name)")
    }
    
    /// Extract Lightning address from a user's metadata
    public static func fromMetadata(_ metadata: [String: Any]) -> String? {
        // Look for lightning address in various fields
        if let lud16 = metadata["lud16"] as? String {
            return lud16
        }
        
        // Check lud06 (LNURL)
        if let lud06 = metadata["lud06"] as? String,
           lud06.lowercased().starts(with: "lnurl") {
            // This is an encoded LNURL, not a Lightning address
            return nil
        }
        
        return nil
    }
}

// MARK: - CoreNostr Extensions

public extension CoreNostr {
    /// Create a zap request event
    static func createZapRequest(
        _ zapRequest: ZapRequest,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.zapRequest.rawValue,
            tags: zapRequest.toTags(),
            content: zapRequest.content
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Create a zap request for a user
    static func createZapRequestForUser(
        recipientPubkey: String,
        amount: Int64,
        relays: [String],
        comment: String = "",
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let zapRequest = ZapRequest(
            amount: amount,
            recipientPubkey: recipientPubkey,
            relays: relays,
            content: comment
        )
        
        return try createZapRequest(zapRequest, keyPair: keyPair)
    }
    
    /// Create a zap request for an event
    static func createZapRequestForEvent(
        eventId: String,
        eventAuthorPubkey: String,
        amount: Int64,
        relays: [String],
        comment: String = "",
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let zapRequest = ZapRequest(
            amount: amount,
            recipientPubkey: eventAuthorPubkey,
            relays: relays,
            eventId: eventId,
            content: comment
        )
        
        return try createZapRequest(zapRequest, keyPair: keyPair)
    }
}

// MARK: - NostrEvent Extensions

public extension NostrEvent {
    /// Check if this is a zap request
    var isZapRequest: Bool {
        kind == EventKind.zapRequest.rawValue
    }
    
    /// Check if this is a zap receipt
    var isZapReceipt: Bool {
        kind == EventKind.zapReceipt.rawValue
    }
    
    /// Parse zap request from this event
    func parseZapRequest() -> ZapRequest? {
        guard isZapRequest else { return nil }
        
        // Extract required fields
        guard let relaysTag = tags.first(where: { $0.count >= 2 && $0[0] == "relays" }),
              let amountTag = tags.first(where: { $0.count >= 2 && $0[0] == "amount" }),
              let amount = Int64(amountTag[1]),
              let pTag = tags.first(where: { $0.count >= 2 && $0[0] == "p" }) else {
            return nil
        }
        
        let relays = Array(relaysTag.dropFirst())
        let recipientPubkey = pTag[1]
        
        // Extract optional fields
        let eventId = tags.first(where: { $0.count >= 2 && $0[0] == "e" })?[1]
        let eventCoordinate = tags.first(where: { $0.count >= 2 && $0[0] == "a" })?[1]
        let lnurl = tags.first(where: { $0.count >= 2 && $0[0] == "lnurl" })?[1]
        
        return ZapRequest(
            amount: amount,
            recipientPubkey: recipientPubkey,
            relays: relays,
            eventId: eventId,
            eventCoordinate: eventCoordinate,
            content: content,
            lnurl: lnurl
        )
    }
    
    /// Parse zap receipt from this event
    func parseZapReceipt() -> ZapReceipt? {
        guard isZapReceipt else { return nil }
        return ZapReceipt(from: self)
    }
    
    /// Get the zap amount from a zap receipt
    var zapAmount: Int64? {
        guard let receipt = parseZapReceipt(),
              let zapRequestEvent = try? receipt.parseZapRequest(),
              let amountTag = zapRequestEvent.tags.first(where: { $0.count >= 2 && $0[0] == "amount" }),
              let amount = Int64(amountTag[1]) else {
            return nil
        }
        
        return amount
    }
}

// MARK: - Zap Statistics

/// Helper for calculating zap statistics
public struct ZapStats: Sendable {
    /// Calculate total zaps for an event
    public static func totalZapsForEvent(_ eventId: String, from receipts: [NostrEvent]) -> (count: Int, totalAmount: Int64) {
        let eventZaps = receipts.filter { receipt in
            receipt.isZapReceipt &&
            receipt.tags.contains { $0.count >= 2 && $0[0] == "e" && $0[1] == eventId }
        }
        
        let totalAmount = eventZaps.compactMap { $0.zapAmount }.reduce(0, +)
        
        return (eventZaps.count, totalAmount)
    }
    
    /// Calculate total zaps for a user
    public static func totalZapsForUser(_ pubkey: String, from receipts: [NostrEvent]) -> (count: Int, totalAmount: Int64) {
        let userZaps = receipts.filter { receipt in
            receipt.isZapReceipt &&
            receipt.tags.contains { $0.count >= 2 && $0[0] == "p" && $0[1] == pubkey }
        }
        
        let totalAmount = userZaps.compactMap { $0.zapAmount }.reduce(0, +)
        
        return (userZaps.count, totalAmount)
    }
    
    /// Get top zappers for an event or user
    public static func topZappers(from receipts: [NostrEvent], limit: Int = 10) -> [(pubkey: String, totalAmount: Int64)] {
        var zapperTotals: [String: Int64] = [:]
        
        for receipt in receipts where receipt.isZapReceipt {
            guard let senderPubkey = receipt.tags.first(where: { $0.count >= 2 && $0[0] == "P" })?[1],
                  let amount = receipt.zapAmount else {
                continue
            }
            
            zapperTotals[senderPubkey, default: 0] += amount
        }
        
        return zapperTotals
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}

// MARK: - Filter Extensions

public extension Filter {
    /// Create a filter for zap receipts
    static func zapReceipts(
        for eventId: String? = nil,
        recipient: String? = nil,
        sender: String? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil
    ) -> Filter {
        var e: [String]? = nil
        var p: [String]? = nil
        
        if let eventId = eventId {
            e = [eventId]
        }
        
        if let recipient = recipient {
            p = [recipient]
        }
        
        // Note: Filter doesn't support custom tags like "P" for sender
        // This would need to be filtered client-side
        
        return Filter(
            kinds: [EventKind.zapReceipt.rawValue],
            since: since,
            until: until,
            limit: limit,
            e: e,
            p: p
        )
    }
}