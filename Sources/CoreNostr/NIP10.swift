import Foundation

/// NIP-10: Reply Threading
/// https://github.com/nostr-protocol/nips/blob/master/10.md
public extension NostrEvent {
    
    /// Tag reference types for threading
    enum TagReference: Sendable, Equatable {
        case root(eventId: String, relayUrl: String? = nil, marker: String? = nil)
        case reply(eventId: String, relayUrl: String? = nil, marker: String? = nil)
        case mention(eventId: String, relayUrl: String? = nil)
        
        /// The event ID being referenced
        public var eventId: String {
            switch self {
            case .root(let eventId, _, _),
                 .reply(let eventId, _, _),
                 .mention(let eventId, _):
                return eventId
            }
        }
        
        /// The optional relay URL hint
        public var relayUrl: String? {
            switch self {
            case .root(_, let relay, _),
                 .reply(_, let relay, _),
                 .mention(_, let relay):
                return relay
            }
        }
        
        /// Convert to tag array for inclusion in event
        public var tag: [String] {
            switch self {
            case .root(let eventId, let relay, let marker):
                var tag = ["e", eventId]
                if let relay = relay {
                    tag.append(relay)
                }
                if let marker = marker {
                    if relay == nil {
                        tag.append("") // Empty relay placeholder
                    }
                    tag.append(marker)
                }
                return tag
                
            case .reply(let eventId, let relay, let marker):
                var tag = ["e", eventId]
                if let relay = relay {
                    tag.append(relay)
                }
                if let marker = marker {
                    if relay == nil {
                        tag.append("") // Empty relay placeholder
                    }
                    tag.append(marker)
                }
                return tag
                
            case .mention(let eventId, let relay):
                var tag = ["e", eventId]
                if let relay = relay {
                    tag.append(relay)
                }
                tag.append("mention")
                return tag
            }
        }
    }
    
    /// Extract thread references from event tags
    /// Returns structured references following NIP-10 conventions
    func extractThreadReferences() -> [TagReference] {
        var references: [TagReference] = []
        
        // Process e tags
        let eTags = tags.filter { $0.first == "e" }
        
        // Check for marked tags (preferred format)
        let markedTags = eTags.filter { $0.count >= 4 }
        if !markedTags.isEmpty {
            // Use marked format
            for tag in eTags {
                guard tag.count >= 2 else { continue }
                
                let eventId = tag[1]
                let relay = tag.count > 2 && !tag[2].isEmpty ? tag[2] : nil
                let marker = tag.count > 3 ? tag[3] : nil
                
                switch marker {
                case "root":
                    references.append(.root(eventId: eventId, relayUrl: relay, marker: marker))
                case "reply":
                    references.append(.reply(eventId: eventId, relayUrl: relay, marker: marker))
                case "mention":
                    references.append(.mention(eventId: eventId, relayUrl: relay))
                default:
                    // Unmarked tag in marked format - treat as mention
                    references.append(.mention(eventId: eventId, relayUrl: relay))
                }
            }
        } else {
            // Use positional format (deprecated but still supported)
            if eTags.count == 1 {
                // Single e-tag is the direct parent (reply)
                let tag = eTags[0]
                let eventId = tag[1]
                let relay = tag.count > 2 ? tag[2] : nil
                references.append(.reply(eventId: eventId, relayUrl: relay))
            } else if eTags.count >= 2 {
                // First is root, last is reply, others are mentions
                for (index, tag) in eTags.enumerated() {
                    guard tag.count >= 2 else { continue }
                    
                    let eventId = tag[1]
                    let relay = tag.count > 2 ? tag[2] : nil
                    
                    if index == 0 {
                        references.append(.root(eventId: eventId, relayUrl: relay))
                    } else if index == eTags.count - 1 {
                        references.append(.reply(eventId: eventId, relayUrl: relay))
                    } else {
                        references.append(.mention(eventId: eventId, relayUrl: relay))
                    }
                }
            }
        }
        
        return references
    }
    
    /// Get the root event ID if this is part of a thread
    var rootEventId: String? {
        let refs = extractThreadReferences()
        return refs.first { 
            if case .root = $0 { return true }
            return false
        }?.eventId
    }
    
    /// Get the direct parent event ID if this is a reply
    var replyToEventId: String? {
        let refs = extractThreadReferences()
        return refs.first { 
            if case .reply = $0 { return true }
            return false
        }?.eventId
    }
    
    /// Get all mentioned event IDs
    var mentionedEventIds: [String] {
        let refs = extractThreadReferences()
        return refs.compactMap { 
            if case .mention(let eventId, _) = $0 { return eventId }
            return nil
        }
    }
    
    /// Check if this event is a reply
    var isReply: Bool {
        replyToEventId != nil
    }
    
    /// Check if this event is part of a thread
    var isThreaded: Bool {
        rootEventId != nil || isReply
    }
}

/// Extensions for creating threaded events
public extension NostrEvent {
    
    /// Create a reply to another event
    /// - Parameters:
    ///   - event: The event to reply to
    ///   - root: Optional root event of the thread (if different from direct parent)
    ///   - content: The reply content
    ///   - mentions: Additional events to mention
    ///   - keyPair: The key pair to sign with
    /// - Returns: A new signed reply event
    static func createReply(
        to event: NostrEvent,
        root: NostrEvent? = nil,
        content: String,
        mentions: [NostrEvent] = [],
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Add p tag for the author we're replying to
        tags.append(["p", event.pubkey])
        
        // Determine root event
        let rootEvent = root ?? event.rootEventId.flatMap { _ in event } ?? event
        
        // Add root marker if applicable
        if rootEvent.id != event.id {
            tags.append(TagReference.root(
                eventId: rootEvent.id,
                marker: "root"
            ).tag)
        }
        
        // Add reply marker
        tags.append(TagReference.reply(
            eventId: event.id,
            marker: "reply"
        ).tag)
        
        // Add mentions
        for mention in mentions {
            tags.append(TagReference.mention(
                eventId: mention.id
            ).tag)
            
            // Also add p tag for mentioned authors
            if !tags.contains(where: { $0.count >= 2 && $0[0] == "p" && $0[1] == mention.pubkey }) {
                tags.append(["p", mention.pubkey])
            }
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: tags,
            content: content
        )
        return try keyPair.signEvent(event)
    }
    
    /// Create a mention of events within content
    /// - Parameters:
    ///   - content: The content that mentions events
    ///   - mentionedEvents: Events being mentioned
    ///   - keyPair: The key pair to sign with
    /// - Returns: A new signed event with mentions
    static func createWithMentions(
        content: String,
        mentionedEvents: [NostrEvent],
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Add mention tags for each event
        for event in mentionedEvents {
            tags.append(TagReference.mention(
                eventId: event.id
            ).tag)
            
            // Also add p tag for mentioned authors
            if !tags.contains(where: { $0.count >= 2 && $0[0] == "p" && $0[1] == event.pubkey }) {
                tags.append(["p", event.pubkey])
            }
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: tags,
            content: content
        )
        return try keyPair.signEvent(event)
    }
}

/// Convenience methods for building thread queries
public extension Filter {
    
    /// Create a filter for replies to a specific event
    /// - Parameters:
    ///   - eventId: The event ID to find replies for
    ///   - includeRoot: Whether to include root thread events
    /// - Returns: A filter for reply events
    static func replies(to eventId: String, includeRoot: Bool = false) -> Filter {
        return Filter(
            kinds: [EventKind.textNote.rawValue],
            e: [eventId]
        )
    }
    
    /// Create a filter for an entire thread
    /// - Parameters:
    ///   - rootEventId: The root event ID of the thread
    /// - Returns: A filter for all events in the thread
    static func thread(rootEventId: String) -> Filter {
        return Filter(
            kinds: [EventKind.textNote.rawValue],
            e: [rootEventId]
        )
    }
    
    /// Create a filter for events mentioning specific events
    /// - Parameters:
    ///   - eventIds: The event IDs being mentioned
    /// - Returns: A filter for mentioning events
    static func mentioning(events eventIds: [String]) -> Filter {
        return Filter(
            kinds: [EventKind.textNote.rawValue],
            e: eventIds
        )
    }
}