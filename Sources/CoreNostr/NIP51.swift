//
//  NIP51.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// NIP-51: Lists
/// https://github.com/nostr-protocol/nips/blob/master/51.md
///
/// Defines lists that can contain references to anything,
/// and these references can be public or private.

// MARK: - List Item Types

/// Represents an item that can be stored in a list
public enum ListItem: Sendable, Equatable {
    /// A public key reference
    case publicKey(String, relay: String? = nil, petname: String? = nil)
    
    /// An event reference
    case event(String, relay: String? = nil)
    
    /// A hashtag reference
    case hashtag(String)
    
    /// A relay reference
    case relay(String)
    
    /// A community reference (a tag identifier)
    case community(String, relay: String? = nil)
    
    /// An interest/topic reference
    case interest(String)
    
    /// An emoji reference
    case emoji(shortcode: String, url: String)
    
    /// A generic reference with custom tag
    case custom(tag: String, values: [String])
    
    /// Convert to a tag array for NostrEvent
    public func toTag() -> [String] {
        switch self {
        case .publicKey(let pubkey, let relay, let petname):
            var tag = ["p", pubkey]
            if let relay = relay {
                tag.append(relay)
            }
            if let petname = petname {
                if relay == nil {
                    tag.append("") // Empty relay field
                }
                tag.append(petname)
            }
            return tag
            
        case .event(let eventId, let relay):
            var tag = ["e", eventId]
            if let relay = relay {
                tag.append(relay)
            }
            return tag
            
        case .hashtag(let hashtag):
            return ["t", hashtag]
            
        case .relay(let url):
            return ["r", url]
            
        case .community(let identifier, let relay):
            var tag = ["a", identifier]
            if let relay = relay {
                tag.append(relay)
            }
            return tag
            
        case .interest(let topic):
            return ["t", topic]
            
        case .emoji(let shortcode, let url):
            return ["emoji", shortcode, url]
            
        case .custom(let tagName, let values):
            return [tagName] + values
        }
    }
    
    /// Initialize from a tag array
    public init?(fromTag tag: [String]) {
        guard tag.count >= 2 else { return nil }
        
        switch tag[0] {
        case "p":
            let relay = tag.count > 2 ? tag[2] : nil
            let petname = tag.count > 3 ? tag[3] : nil
            self = .publicKey(tag[1], relay: relay, petname: petname)
            
        case "e":
            let relay = tag.count > 2 ? tag[2] : nil
            self = .event(tag[1], relay: relay)
            
        case "t":
            self = .hashtag(tag[1])
            
        case "r":
            self = .relay(tag[1])
            
        case "a":
            let relay = tag.count > 2 ? tag[2] : nil
            self = .community(tag[1], relay: relay)
            
        case "emoji":
            guard tag.count >= 3 else { return nil }
            self = .emoji(shortcode: tag[1], url: tag[2])
            
        default:
            self = .custom(tag: tag[0], values: Array(tag.dropFirst()))
        }
    }
}

// MARK: - List Types

/// A standard list that can only have one instance per user
public struct StandardList: Sendable {
    /// The event kind for this list type
    public let kind: EventKind
    
    /// Public items in the list
    public let publicItems: [ListItem]
    
    /// Encrypted private items (stored in content field)
    public let encryptedContent: String?
    
    /// Additional metadata tags
    public let metadata: [[String]]
    
    /// Initialize a standard list
    public init(
        kind: EventKind,
        publicItems: [ListItem] = [],
        encryptedContent: String? = nil,
        metadata: [[String]] = []
    ) {
        self.kind = kind
        self.publicItems = publicItems
        self.encryptedContent = encryptedContent
        self.metadata = metadata
    }
}

/// A parameterized replaceable list that can have multiple instances
public struct ParameterizedList: Sendable {
    /// The event kind for this list type
    public let kind: EventKind
    
    /// The unique identifier for this list instance
    public let identifier: String
    
    /// The title of the list
    public let title: String?
    
    /// The description of the list
    public let description: String?
    
    /// Public items in the list
    public let publicItems: [ListItem]
    
    /// Encrypted private items (stored in content field)
    public let encryptedContent: String?
    
    /// Additional metadata tags
    public let metadata: [[String]]
    
    /// Initialize a parameterized list
    public init(
        kind: EventKind,
        identifier: String,
        title: String? = nil,
        description: String? = nil,
        publicItems: [ListItem] = [],
        encryptedContent: String? = nil,
        metadata: [[String]] = []
    ) {
        self.kind = kind
        self.identifier = identifier
        self.title = title
        self.description = description
        self.publicItems = publicItems
        self.encryptedContent = encryptedContent
        self.metadata = metadata
    }
}

// MARK: - CoreNostr Extensions

public extension CoreNostr {
    /// Create a standard list event
    static func createList(
        _ list: StandardList,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags = list.publicItems.map { $0.toTag() }
        tags.append(contentsOf: list.metadata)
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: list.kind.rawValue,
            tags: tags,
            content: list.encryptedContent ?? ""
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Create a parameterized list event
    static func createParameterizedList(
        _ list: ParameterizedList,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Add d tag for identifier
        tags.append(["d", list.identifier])
        
        // Add title if present
        if let title = list.title {
            tags.append(["title", title])
        }
        
        // Add description if present  
        if let description = list.description {
            tags.append(["description", description])
        }
        
        // Add all public items
        tags.append(contentsOf: list.publicItems.map { $0.toTag() })
        
        // Add any additional metadata
        tags.append(contentsOf: list.metadata)
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: list.kind.rawValue,
            tags: tags,
            content: list.encryptedContent ?? ""
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Encrypt items for a private list using NIP-04
    /// - Warning: NIP-04 is deprecated. Consider using NIP-44 for new implementations.
    @available(*, deprecated, message: "NIP-04 is deprecated. Consider using NIP-44 for new implementations.")
    static func encryptListItems(
        _ items: [ListItem],
        recipientPublicKey: PublicKey,
        senderKeyPair: KeyPair
    ) throws -> String {
        let tags = items.map { $0.toTag() }
        let jsonData = try JSONSerialization.data(withJSONObject: tags)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        let sharedSecret = try senderKeyPair.getSharedSecret(with: recipientPublicKey)
        let encrypted = try NostrCrypto.encryptMessage(jsonString, with: sharedSecret)
        
        return encrypted
    }
    
    /// Decrypt items from a private list using NIP-04
    /// - Warning: NIP-04 is deprecated. Consider using NIP-44 for new implementations.
    @available(*, deprecated, message: "NIP-04 is deprecated. Consider using NIP-44 for new implementations.")
    static func decryptListItems(
        encryptedContent: String,
        senderPublicKey: PublicKey,
        recipientKeyPair: KeyPair
    ) throws -> [ListItem] {
        let sharedSecret = try recipientKeyPair.getSharedSecret(with: senderPublicKey)
        let decrypted = try NostrCrypto.decryptMessage(encryptedContent, with: sharedSecret)
        
        guard let data = decrypted.data(using: .utf8),
              let tags = try JSONSerialization.jsonObject(with: data) as? [[String]] else {
            throw NostrError.serializationError(type: "list items", reason: "Failed to parse decrypted JSON array")
        }
        
        return tags.compactMap { ListItem(fromTag: $0) }
    }
}

// MARK: - NostrEvent Extensions

public extension NostrEvent {
    /// Parse a standard list from this event
    func parseStandardList() -> StandardList? {
        guard let eventKind = EventKind(rawValue: kind) else { return nil }
        
        // Check if this is a standard list kind
        let standardListKinds: [EventKind] = [
            .muteList, .pinnedNotes, .relayList, .bookmarks,
            .communities, .publicChats, .blockedRelays,
            .searchRelays, .simpleGroups, .interests,
            .emojis, .dmRelays
        ]
        
        guard standardListKinds.contains(eventKind) else { return nil }
        
        let items = tags.compactMap { ListItem(fromTag: $0) }
        let metadata = tags.filter { tag in
            guard let first = tag.first else { return false }
            // Filter out known list item tags
            return !["p", "e", "t", "r", "a", "emoji"].contains(first)
        }
        
        return StandardList(
            kind: eventKind,
            publicItems: items,
            encryptedContent: content.isEmpty ? nil : content,
            metadata: metadata
        )
    }
    
    /// Parse a parameterized list from this event
    func parseParameterizedList() -> ParameterizedList? {
        guard let eventKind = EventKind(rawValue: kind) else { return nil }
        
        // Check if this is a parameterized list kind
        let parameterizedListKinds: [EventKind] = [
            .followSets, .relaySets, .bookmarkSets,
            .curationSets, .interestSets, .emojiSets
        ]
        
        guard parameterizedListKinds.contains(eventKind) else { return nil }
        
        // Find d tag for identifier
        guard let dTag = tags.first(where: { $0.count >= 2 && $0[0] == "d" }) else {
            return nil
        }
        
        let identifier = dTag[1]
        
        // Find title tag
        let title = tags.first(where: { $0.count >= 2 && $0[0] == "title" })?[1]
        
        // Find description tag
        let description = tags.first(where: { $0.count >= 2 && $0[0] == "description" })?[1]
        
        // Parse items
        let items = tags.compactMap { tag -> ListItem? in
            guard let first = tag.first else { return nil }
            // Skip metadata tags
            if ["d", "title", "description"].contains(first) { return nil }
            return ListItem(fromTag: tag)
        }
        
        let metadata = tags.filter { tag in
            guard let first = tag.first else { return false }
            // Filter out known tags
            return !["p", "e", "t", "r", "a", "emoji", "d", "title", "description"].contains(first)
        }
        
        return ParameterizedList(
            kind: eventKind,
            identifier: identifier,
            title: title,
            description: description,
            publicItems: items,
            encryptedContent: content.isEmpty ? nil : content,
            metadata: metadata
        )
    }
}

// MARK: - Convenience Methods

public extension CoreNostr {
    /// Create a mute list
    static func createMuteList(
        publicKeys: [PublicKey] = [],
        events: [EventID] = [],
        hashtags: [String] = [],
        keyPair: KeyPair,
        encrypted: Bool = false
    ) throws -> NostrEvent {
        var publicItems: [ListItem] = []
        var privateItems: [ListItem] = []
        
        let pubkeyItems = publicKeys.map { ListItem.publicKey($0) }
        let eventItems = events.map { ListItem.event($0) }
        let hashtagItems = hashtags.map { ListItem.hashtag($0) }
        
        if encrypted {
            privateItems = pubkeyItems + eventItems + hashtagItems
        } else {
            publicItems = pubkeyItems + eventItems + hashtagItems
        }
        
        var encryptedContent: String?
        if !privateItems.isEmpty {
            // Using deprecated NIP-04 encryption for backward compatibility
            // TODO: Migrate to NIP-44 when widely supported  
            encryptedContent = try Self.encryptListItems(
                privateItems,
                recipientPublicKey: keyPair.publicKey,
                senderKeyPair: keyPair
            )
        }
        
        let list = StandardList(
            kind: .muteList,
            publicItems: publicItems,
            encryptedContent: encryptedContent
        )
        
        return try createList(list, keyPair: keyPair)
    }
    
    /// Create a bookmark list
    static func createBookmarkList(
        events: [EventID] = [],
        hashtags: [String] = [],
        relays: [String] = [],
        keyPair: KeyPair,
        encrypted: Bool = false
    ) throws -> NostrEvent {
        var publicItems: [ListItem] = []
        var privateItems: [ListItem] = []
        
        let eventItems = events.map { ListItem.event($0) }
        let hashtagItems = hashtags.map { ListItem.hashtag($0) }
        let relayItems = relays.map { ListItem.relay($0) }
        
        if encrypted {
            privateItems = eventItems + hashtagItems + relayItems
        } else {
            publicItems = eventItems + hashtagItems + relayItems
        }
        
        var encryptedContent: String?
        if !privateItems.isEmpty {
            // Using deprecated NIP-04 encryption for backward compatibility
            // TODO: Migrate to NIP-44 when widely supported  
            encryptedContent = try Self.encryptListItems(
                privateItems,
                recipientPublicKey: keyPair.publicKey,
                senderKeyPair: keyPair
            )
        }
        
        let list = StandardList(
            kind: .bookmarks,
            publicItems: publicItems,
            encryptedContent: encryptedContent
        )
        
        return try createList(list, keyPair: keyPair)
    }
    
    /// Create a follow set
    static func createFollowSet(
        identifier: String,
        title: String,
        publicKeys: [(pubkey: PublicKey, relay: String?, petname: String?)],
        description: String? = nil,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let items = publicKeys.map { 
            ListItem.publicKey($0.pubkey, relay: $0.relay, petname: $0.petname)
        }
        
        let list = ParameterizedList(
            kind: .followSets,
            identifier: identifier,
            title: title,
            description: description,
            publicItems: items
        )
        
        return try createParameterizedList(list, keyPair: keyPair)
    }
}