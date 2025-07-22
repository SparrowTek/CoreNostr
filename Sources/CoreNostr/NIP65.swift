//
//  NIP65.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// NIP-65: Relay List Metadata
/// https://github.com/nostr-protocol/nips/blob/master/65.md
///
/// Defines a user's preferred relays for reading and writing events.
/// This enables better relay discovery and more efficient event distribution.

// MARK: - Relay List Types

/// The usage type for a relay
public enum RelayUsage: String, Sendable, CaseIterable {
    /// Relay is used for both reading and writing
    case readWrite = ""
    
    /// Relay is used only for reading events
    case read = "read"
    
    /// Relay is used only for writing events  
    case write = "write"
}

/// Represents a relay with its usage preference
public struct RelayPreference: Sendable, Equatable {
    /// The relay URL
    public let url: String
    
    /// How this relay should be used
    public let usage: RelayUsage
    
    /// Initialize a relay preference
    public init(url: String, usage: RelayUsage = .readWrite) {
        self.url = url
        self.usage = usage
    }
    
    /// Convert to a tag array for NostrEvent
    public func toTag() -> [String] {
        var tag = ["r", url]
        if usage != .readWrite {
            tag.append(usage.rawValue)
        }
        return tag
    }
    
    /// Initialize from a tag array
    public init?(fromTag tag: [String]) {
        guard tag.count >= 2, tag[0] == "r" else { return nil }
        
        self.url = tag[1]
        
        if tag.count >= 3 {
            self.usage = RelayUsage(rawValue: tag[2]) ?? .readWrite
        } else {
            self.usage = .readWrite
        }
    }
}

/// A user's relay list metadata
public struct RelayListMetadata: Sendable {
    /// All relay preferences
    public let relays: [RelayPreference]
    
    /// Get only read relays (including read/write relays)
    public var readRelays: [String] {
        relays
            .filter { $0.usage == .read || $0.usage == .readWrite }
            .map { $0.url }
    }
    
    /// Get only write relays (including read/write relays)
    public var writeRelays: [String] {
        relays
            .filter { $0.usage == .write || $0.usage == .readWrite }
            .map { $0.url }
    }
    
    /// Get relays that are exclusively for reading
    public var readOnlyRelays: [String] {
        relays
            .filter { $0.usage == .read }
            .map { $0.url }
    }
    
    /// Get relays that are exclusively for writing
    public var writeOnlyRelays: [String] {
        relays
            .filter { $0.usage == .write }
            .map { $0.url }
    }
    
    /// Get relays that are for both reading and writing
    public var readWriteRelays: [String] {
        relays
            .filter { $0.usage == .readWrite }
            .map { $0.url }
    }
    
    /// Initialize relay list metadata
    public init(relays: [RelayPreference]) {
        self.relays = relays
    }
    
    /// Initialize from relay URLs with specific usage
    public init(
        readWrite: [String] = [],
        readOnly: [String] = [],
        writeOnly: [String] = []
    ) {
        var relays: [RelayPreference] = []
        
        relays.append(contentsOf: readWrite.map { RelayPreference(url: $0, usage: .readWrite) })
        relays.append(contentsOf: readOnly.map { RelayPreference(url: $0, usage: .read) })
        relays.append(contentsOf: writeOnly.map { RelayPreference(url: $0, usage: .write) })
        
        self.relays = relays
    }
}

// MARK: - CoreNostr Extensions

public extension CoreNostr {
    /// Create a relay list metadata event
    static func createRelayListMetadata(
        _ metadata: RelayListMetadata,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let tags = metadata.relays.map { $0.toTag() }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.relayList.rawValue,
            tags: tags,
            content: ""
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Create a relay list metadata event from relay URLs
    static func createRelayListMetadata(
        readWrite: [String] = [],
        readOnly: [String] = [],
        writeOnly: [String] = [],
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let metadata = RelayListMetadata(
            readWrite: readWrite,
            readOnly: readOnly,
            writeOnly: writeOnly
        )
        
        return try createRelayListMetadata(metadata, keyPair: keyPair)
    }
}

// MARK: - NostrEvent Extensions

public extension NostrEvent {
    /// Parse relay list metadata from this event
    func parseRelayListMetadata() -> RelayListMetadata? {
        guard kind == EventKind.relayList.rawValue else { return nil }
        
        let relayPreferences = tags.compactMap { RelayPreference(fromTag: $0) }
        
        return RelayListMetadata(relays: relayPreferences)
    }
}

// MARK: - Relay Discovery Helper

/// Helper for discovering relays for users
public struct RelayDiscovery: Sendable {
    /// Get suggested relays to download events from a specific author
    ///
    /// According to NIP-65:
    /// - Use the author's write relays to download events they authored
    /// - Use the author's read relays to download events that mention them
    public static func getRelaysForAuthor(
        _ authorMetadata: RelayListMetadata,
        forAuthoredEvents: Bool
    ) -> [String] {
        if forAuthoredEvents {
            return authorMetadata.writeRelays
        } else {
            return authorMetadata.readRelays
        }
    }
    
    /// Get suggested relays to publish an event to
    ///
    /// According to NIP-65:
    /// - Send to your own write relays
    /// - Send to read relays of any tagged users
    public static func getRelaysForPublishing(
        authorMetadata: RelayListMetadata,
        taggedUsersMetadata: [RelayListMetadata]
    ) -> Set<String> {
        var relays = Set<String>()
        
        // Add author's write relays
        relays.formUnion(authorMetadata.writeRelays)
        
        // Add tagged users' read relays
        for userMetadata in taggedUsersMetadata {
            relays.formUnion(userMetadata.readRelays)
        }
        
        return relays
    }
    
    /// Validate relay list according to NIP-65 recommendations
    ///
    /// Returns warnings if:
    /// - Too many relays per category (recommends 2-4)
    /// - No write relays specified
    /// - No read relays specified
    public static func validateRelayList(_ metadata: RelayListMetadata) -> [String] {
        var warnings: [String] = []
        
        let readCount = metadata.readRelays.count
        let writeCount = metadata.writeRelays.count
        
        if readCount == 0 {
            warnings.append("No read relays specified")
        } else if readCount > 4 {
            warnings.append("Too many read relays (\(readCount)). Recommended: 2-4")
        }
        
        if writeCount == 0 {
            warnings.append("No write relays specified")
        } else if writeCount > 4 {
            warnings.append("Too many write relays (\(writeCount)). Recommended: 2-4")
        }
        
        return warnings
    }
}

// MARK: - Filter Extensions

public extension Filter {
    /// Create a filter to find relay list metadata for specific users
    static func relayListMetadata(for pubkeys: [PublicKey]) -> Filter {
        return Filter(
            authors: pubkeys,
            kinds: [EventKind.relayList.rawValue]
        )
    }
}