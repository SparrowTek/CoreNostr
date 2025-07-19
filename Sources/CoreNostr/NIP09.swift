import Foundation

/// NIP-09: Event Deletion
/// https://github.com/nostr-protocol/nips/blob/master/09.md
///
/// A special event with kind 5 that can be published by an event author to request deletion of their previous events.

public extension NostrEvent {
    /// Check if this event is a deletion request
    var isDeletionEvent: Bool {
        kind == EventKind.deletion.rawValue
    }
    
    /// Extract the event IDs that this deletion event is requesting to delete
    var deletedEventIds: [String] {
        guard isDeletionEvent else { return [] }
        
        return tags
            .filter { $0.count >= 2 && $0[0] == "e" }
            .map { $0[1] }
    }
    
    /// Extract the reason for deletion if provided
    var deletionReason: String? {
        guard isDeletionEvent else { return nil }
        
        // Look for a tag with "reason" as the first element
        let reasonTag = tags.first { $0.count >= 2 && $0[0] == "reason" }
        return reasonTag?[1]
    }
    
    /// Get deletion information for a specific event ID
    func deletionInfo(for eventId: String) -> (isDeleted: Bool, reason: String?) {
        guard isDeletionEvent else { return (false, nil) }
        
        let isDeleted = deletedEventIds.contains(eventId)
        return (isDeleted, isDeleted ? deletionReason : nil)
    }
}

public extension CoreNostr {
    /// Create a deletion event for the specified event IDs
    /// - Parameters:
    ///   - eventIds: Array of event IDs to request deletion for
    ///   - reason: Optional reason for the deletion
    ///   - keyPair: The key pair to sign the deletion event with (must be the author of the events being deleted)
    /// - Returns: A signed deletion event
    /// - Throws: NostrError if the event creation or signing fails
    static func createDeletionEvent(
        eventIds: [String],
        reason: String? = nil,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        guard !eventIds.isEmpty else {
            throw NostrError.invalidEvent("Cannot create deletion event with no event IDs")
        }
        
        var tags: [[String]] = []
        
        // Add e tags for each event to delete
        for eventId in eventIds {
            tags.append(["e", eventId])
        }
        
        // Add reason tag if provided
        if let reason = reason {
            tags.append(["reason", reason])
        }
        
        // Create the deletion event
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.deletion.rawValue,
            tags: tags,
            content: reason ?? ""  // Content can also contain the reason
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Create a deletion event for a single event
    /// - Parameters:
    ///   - eventId: The event ID to request deletion for
    ///   - reason: Optional reason for the deletion
    ///   - keyPair: The key pair to sign the deletion event with
    /// - Returns: A signed deletion event
    /// - Throws: NostrError if the event creation or signing fails
    static func createDeletionEvent(
        for eventId: String,
        reason: String? = nil,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        try createDeletionEvent(
            eventIds: [eventId],
            reason: reason,
            keyPair: keyPair
        )
    }
}

/// Filter extensions for deletion events
public extension Filter {
    /// Create a filter for deletion events
    /// - Parameters:
    ///   - authors: Optional array of authors to filter by
    ///   - deletedEventIds: Optional array of event IDs that are being deleted
    /// - Returns: A filter for deletion events
    static func deletionEvents(
        authors: [PublicKey]? = nil,
        deletedEventIds: [EventID]? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.deletion.rawValue],
            e: deletedEventIds
        )
    }
    
    /// Create a filter for deletion events that delete specific events
    /// - Parameter eventIds: The event IDs to find deletion events for
    /// - Returns: A filter for deletion events
    static func deletionsOf(eventIds: [EventID]) -> Filter {
        return Filter(
            kinds: [EventKind.deletion.rawValue],
            e: eventIds
        )
    }
}

/// Helper to track deletion status
public struct DeletionTracker: Sendable {
    private var deletions: [EventID: DeletionInfo] = [:]
    
    public struct DeletionInfo: Sendable {
        public let deletionEventId: EventID
        public let deletionTimestamp: Date
        public let reason: String?
        public let authorPubkey: PublicKey
    }
    
    public init() {}
    
    /// Process a deletion event and track its deletions
    public mutating func processDeletionEvent(_ event: NostrEvent) {
        guard event.isDeletionEvent else { return }
        
        let reason = event.deletionReason
        let timestamp = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        
        for eventId in event.deletedEventIds {
            deletions[eventId] = DeletionInfo(
                deletionEventId: event.id,
                deletionTimestamp: timestamp,
                reason: reason,
                authorPubkey: event.pubkey
            )
        }
    }
    
    /// Check if an event has been deleted
    public func isDeleted(_ eventId: EventID) -> Bool {
        deletions[eventId] != nil
    }
    
    /// Get deletion info for an event
    public func deletionInfo(for eventId: EventID) -> DeletionInfo? {
        deletions[eventId]
    }
    
    /// Remove deletion tracking for an event
    public mutating func untrack(_ eventId: EventID) {
        deletions.removeValue(forKey: eventId)
    }
    
    /// Clear all deletion tracking
    public mutating func clear() {
        deletions.removeAll()
    }
}