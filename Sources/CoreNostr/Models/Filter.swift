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
    
    /// Search filter for full-text search across event content (NIP-50)
    public var search: String?
    
    private enum CodingKeys: String, CodingKey {
        case ids, authors, kinds, since, until, limit, search
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
    ///   - search: Full-text search query (NIP-50)
    public init(
        ids: [EventID]? = nil,
        authors: [PublicKey]? = nil,
        kinds: [Int]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil,
        e: [String]? = nil,
        p: [String]? = nil,
        search: String? = nil
    ) {
        self.ids = ids
        self.authors = authors
        self.kinds = kinds
        self.since = since.map { Int64($0.timeIntervalSince1970) }
        self.until = until.map { Int64($0.timeIntervalSince1970) }
        self.limit = limit
        self.e = e
        self.p = p
        self.search = search
    }
}

// MARK: - NIP-50 Search Extensions

extension Filter {
    /// Creates a search filter for full-text search.
    ///
    /// This implements NIP-50 search capability specification.
    /// Relays that support NIP-50 will search the content field of events.
    ///
    /// - Parameters:
    ///   - query: The search query string
    ///   - kinds: Optional event kinds to restrict search to
    ///   - authors: Optional authors to restrict search to
    ///   - limit: Maximum number of results
    /// - Returns: A filter configured for search
    public static func search(
        query: String,
        kinds: [Int]? = nil,
        authors: [PublicKey]? = nil,
        limit: Int? = 100
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: kinds,
            limit: limit,
            search: query
        )
    }
    
    /// Creates a search filter for text notes (kind 1).
    ///
    /// - Parameters:
    ///   - query: The search query string
    ///   - authors: Optional authors to restrict search to
    ///   - limit: Maximum number of results
    /// - Returns: A filter for searching text notes
    public static func searchTextNotes(
        query: String,
        authors: [PublicKey]? = nil,
        limit: Int? = 100
    ) -> Filter {
        return search(
            query: query,
            kinds: [EventKind.textNote.rawValue],
            authors: authors,
            limit: limit
        )
    }
    
    /// Creates a search filter for long-form content (kind 30023).
    ///
    /// - Parameters:
    ///   - query: The search query string
    ///   - authors: Optional authors to restrict search to
    ///   - limit: Maximum number of results
    /// - Returns: A filter for searching articles
    public static func searchArticles(
        query: String,
        authors: [PublicKey]? = nil,
        limit: Int? = 50
    ) -> Filter {
        return search(
            query: query,
            kinds: [EventKind.longFormContent.rawValue],
            authors: authors,
            limit: limit
        )
    }
}

// MARK: - Search Query Helpers

extension Filter {
    /// Helper struct for building complex search queries with NIP-50 extensions.
    public struct SearchQuery {
        private var components: [String] = []
        
        /// Creates a new search query builder.
        public init() {}
        
        /// Adds a search term to the query.
        public mutating func add(term: String) {
            components.append(term)
        }
        
        /// Includes spam results in search (default is to exclude).
        public mutating func includeSpam() {
            components.append("include:spam")
        }
        
        /// Filters results by domain.
        public mutating func domain(_ domain: String) {
            components.append("domain:\(domain)")
        }
        
        /// Filters results by language code.
        public mutating func language(_ code: String) {
            components.append("language:\(code)")
        }
        
        /// Filters results by sentiment.
        public mutating func sentiment(_ sentiment: Sentiment) {
            components.append("sentiment:\(sentiment.rawValue)")
        }
        
        /// Filters NSFW content.
        public mutating func nsfw(_ include: Bool) {
            components.append("nsfw:\(include)")
        }
        
        /// Builds the final search query string.
        public func build() -> String {
            return components.joined(separator: " ")
        }
        
        /// Sentiment options for search filtering.
        public enum Sentiment: String, Sendable {
            case negative
            case neutral
            case positive
        }
    }
}
