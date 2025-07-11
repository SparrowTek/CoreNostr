//
//  Filter.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// A filter for requesting specific events from relays.
///
/// Filters allow clients to request only events that match certain criteria,
/// such as specific authors, event kinds, or time ranges.
///
/// ## Example
/// ```swift
/// let filter = Filter(
///     authors: ["user-pubkey"],
///     kinds: [1], // Text notes only
///     limit: 20
/// )
/// ```
public struct Filter: Codable, Sendable {
    /// Filter by specific event IDs
    public var ids: [EventID]?
    
    /// Filter by author public keys
    public var authors: [PublicKey]?
    
    /// Filter by event kinds
    public var kinds: [Int]?
    
    /// Filter events created after this timestamp
    public var since: Int64?
    
    /// Filter events created before this timestamp
    public var until: Int64?
    
    /// Maximum number of events to return
    public var limit: Int?
    
    /// Filter by referenced event IDs ("e" tags)
    public var e: [String]?
    
    /// Filter by referenced public keys ("p" tags)
    public var p: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case ids, authors, kinds, since, until, limit
        case e = "#e"
        case p = "#p"
    }
    
    /// Creates a filter with the specified criteria.
    ///
    /// - Parameters:
    ///   - ids: Specific event IDs to match
    ///   - authors: Author public keys to match
    ///   - kinds: Event kinds to match
    ///   - since: Minimum creation time
    ///   - until: Maximum creation time
    ///   - limit: Maximum number of events to return
    ///   - e: Referenced event IDs to match
    ///   - p: Referenced public keys to match
    public init(
        ids: [EventID]? = nil,
        authors: [PublicKey]? = nil,
        kinds: [Int]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil,
        e: [String]? = nil,
        p: [String]? = nil
    ) {
        self.ids = ids
        self.authors = authors
        self.kinds = kinds
        self.since = since.map { Int64($0.timeIntervalSince1970) }
        self.until = until.map { Int64($0.timeIntervalSince1970) }
        self.limit = limit
        self.e = e
        self.p = p
    }
}
