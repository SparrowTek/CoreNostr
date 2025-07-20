//
//  NIP40.swift
//  CoreNostr
//
//  NIP-40: Expiration Timestamp
//  https://github.com/nostr-protocol/nips/blob/master/40.md
//

import Foundation

/// NIP-40: Expiration Timestamp
///
/// This NIP defines a standard for adding expiration timestamps to events.
/// Events with expiration timestamps should be treated as ephemeral after
/// the specified time has passed.
///
/// ## Example Usage
/// ```swift
/// // Create an event that expires in 24 hours
/// let event = NostrEvent(
///     pubkey: keyPair.publicKey,
///     kind: 1,
///     tags: NIP40.expirationTag(after: .hours(24)),
///     content: "This message will expire in 24 hours"
/// )
/// 
/// // Check if an event has expired
/// if NIP40.isExpired(event) {
///     print("Event has expired")
/// }
/// ```
public enum NIP40 {
    
    /// The tag name used for expiration timestamps
    public static let tagName = "expiration"
    
    /// Time interval options for creating expiration timestamps
    public enum ExpirationInterval {
        case seconds(Int)
        case minutes(Int)
        case hours(Int)
        case days(Int)
        case custom(TimeInterval)
        
        /// Converts the interval to seconds
        public var timeInterval: TimeInterval {
            switch self {
            case .seconds(let s):
                return TimeInterval(s)
            case .minutes(let m):
                return TimeInterval(m * 60)
            case .hours(let h):
                return TimeInterval(h * 3600)
            case .days(let d):
                return TimeInterval(d * 86400)
            case .custom(let t):
                return t
            }
        }
    }
    
    /// Creates an expiration tag with the specified timestamp.
    ///
    /// - Parameter timestamp: The Unix timestamp when the event expires
    /// - Returns: A tag array ready to be added to an event
    public static func expirationTag(at timestamp: Int64) -> [String] {
        return [tagName, String(timestamp)]
    }
    
    /// Creates an expiration tag for a specific date.
    ///
    /// - Parameter date: The date when the event expires
    /// - Returns: A tag array ready to be added to an event
    public static func expirationTag(at date: Date) -> [String] {
        return expirationTag(at: Int64(date.timeIntervalSince1970))
    }
    
    /// Creates an expiration tag for a time interval from now.
    ///
    /// - Parameter interval: The time interval after which the event expires
    /// - Returns: A tag array ready to be added to an event
    public static func expirationTag(after interval: ExpirationInterval) -> [String] {
        let expirationDate = Date().addingTimeInterval(interval.timeInterval)
        return expirationTag(at: expirationDate)
    }
    
    /// Extracts the expiration timestamp from an event.
    ///
    /// - Parameter event: The event to check
    /// - Returns: The expiration timestamp if present, nil otherwise
    public static func expirationTimestamp(from event: NostrEvent) -> Int64? {
        guard let expirationTag = event.tags.first(where: { 
            $0.count >= 2 && $0[0] == tagName 
        }) else {
            return nil
        }
        
        return Int64(expirationTag[1])
    }
    
    /// Extracts the expiration date from an event.
    ///
    /// - Parameter event: The event to check
    /// - Returns: The expiration date if present, nil otherwise
    public static func expirationDate(from event: NostrEvent) -> Date? {
        guard let timestamp = expirationTimestamp(from: event) else {
            return nil
        }
        
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
    
    /// Checks if an event has expired.
    ///
    /// - Parameter event: The event to check
    /// - Returns: True if the event has an expiration timestamp and has expired
    public static func isExpired(_ event: NostrEvent) -> Bool {
        guard let expirationDate = expirationDate(from: event) else {
            return false
        }
        
        return Date() > expirationDate
    }
    
    /// Checks if an event expires within a given time interval.
    ///
    /// - Parameters:
    ///   - event: The event to check
    ///   - interval: The time interval to check
    /// - Returns: True if the event expires within the interval
    public static func expiresWithin(_ event: NostrEvent, interval: ExpirationInterval) -> Bool {
        guard let expirationDate = expirationDate(from: event) else {
            return false
        }
        
        let checkDate = Date().addingTimeInterval(interval.timeInterval)
        return expirationDate <= checkDate
    }
    
    /// Filters out expired events from a collection.
    ///
    /// - Parameter events: The events to filter
    /// - Returns: Only the events that have not expired
    public static func filterExpired(_ events: [NostrEvent]) -> [NostrEvent] {
        return events.filter { !isExpired($0) }
    }
    
    /// Sorts events by expiration date (earliest first).
    ///
    /// - Parameter events: The events to sort
    /// - Returns: Events sorted by expiration date, with non-expiring events at the end
    public static func sortByExpiration(_ events: [NostrEvent]) -> [NostrEvent] {
        return events.sorted { event1, event2 in
            let exp1 = expirationTimestamp(from: event1)
            let exp2 = expirationTimestamp(from: event2)
            
            switch (exp1, exp2) {
            case (nil, nil):
                return false
            case (nil, _):
                return false
            case (_, nil):
                return true
            case let (t1?, t2?):
                return t1 < t2
            }
        }
    }
}

// MARK: - NostrEvent Extension

extension NostrEvent {
    /// The expiration timestamp of this event (NIP-40).
    public var expirationTimestamp: Int64? {
        return NIP40.expirationTimestamp(from: self)
    }
    
    /// The expiration date of this event (NIP-40).
    public var expirationDate: Date? {
        return NIP40.expirationDate(from: self)
    }
    
    /// Whether this event has expired (NIP-40).
    public var isExpired: Bool {
        return NIP40.isExpired(self)
    }
    
    /// Adds an expiration timestamp to this event.
    ///
    /// - Parameter interval: The time interval after which the event expires
    /// - Returns: A new event with the expiration tag added
    public func withExpiration(after interval: NIP40.ExpirationInterval) -> NostrEvent {
        var newTags = self.tags
        
        // Remove any existing expiration tags
        newTags.removeAll { $0.count >= 1 && $0[0] == NIP40.tagName }
        
        // Add new expiration tag
        newTags.append(NIP40.expirationTag(after: interval))
        
        return NostrEvent(
            unvalidatedId: self.id,
            pubkey: self.pubkey,
            createdAt: self.createdAt,
            kind: self.kind,
            tags: newTags,
            content: self.content,
            sig: self.sig
        )
    }
}

// MARK: - Filter Extension

extension Filter {
    /// Creates a filter that excludes expired events.
    ///
    /// Note: This relies on relays respecting NIP-40 and not sending expired events.
    /// Clients should still check expiration client-side.
    ///
    /// - Parameters:
    ///   - base: The base filter to modify
    ///   - buffer: Optional buffer time to exclude events expiring soon
    /// - Returns: A filter for non-expired events
    public static func excludingExpired(
        base: Filter,
        buffer: NIP40.ExpirationInterval? = nil
    ) -> Filter {
        // Since filters can't directly exclude expired events,
        // we can only rely on relay behavior. This is a convenience
        // method that documents the intent.
        return base
    }
}