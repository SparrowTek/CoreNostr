//
//  NIP50.swift
//  CoreNostr
//
//  NIP-50: Search Capability Specification
//  https://github.com/nostr-protocol/nips/blob/master/50.md
//

import Foundation

/// NIP-50: Search Capability Specification
///
/// This NIP defines a search framework for Nostr that allows clients to perform
/// full-text searches across event content. Relays that support NIP-50 should
/// interpret search queries and return relevant results.
///
/// ## Example Usage
/// ```swift
/// // Simple search
/// let filter = Filter.search(query: "bitcoin conference 2024")
/// 
/// // Search with query builder
/// var query = Filter.SearchQuery()
/// query.add(term: "nostr development")
/// query.language("en")
/// query.sentiment(.positive)
/// let complexFilter = Filter.search(query: query.build())
/// ```
public enum NIP50 {
    
    /// Creates a filter for searching events.
    ///
    /// - Parameters:
    ///   - query: The search query string
    ///   - kinds: Optional event kinds to restrict search to
    ///   - authors: Optional authors to restrict search to
    ///   - since: Optional minimum creation time
    ///   - until: Optional maximum creation time
    ///   - limit: Maximum number of results
    /// - Returns: A filter configured for search
    public static func searchFilter(
        query: String,
        kinds: [Int]? = nil,
        authors: [PublicKey]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = 100
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: kinds,
            since: since,
            until: until,
            limit: limit,
            search: query
        )
    }
    
    /// Parses a search query string to check for NIP-50 extensions.
    ///
    /// - Parameter query: The search query to parse
    /// - Returns: A tuple containing the base query and detected extensions
    public static func parseSearchQuery(_ query: String) -> (baseQuery: String, extensions: SearchExtensions) {
        var extensions = SearchExtensions()
        var baseTerms: [String] = []
        
        let components = query.split(separator: " ")
        
        for component in components {
            let term = String(component)
            
            if term.hasPrefix("include:") {
                let value = String(term.dropFirst("include:".count))
                if value == "spam" {
                    extensions.includeSpam = true
                }
            } else if term.hasPrefix("domain:") {
                extensions.domain = String(term.dropFirst("domain:".count))
            } else if term.hasPrefix("language:") {
                extensions.language = String(term.dropFirst("language:".count))
            } else if term.hasPrefix("sentiment:") {
                let value = String(term.dropFirst("sentiment:".count))
                extensions.sentiment = SearchExtensions.Sentiment(rawValue: value)
            } else if term.hasPrefix("nsfw:") {
                let value = String(term.dropFirst("nsfw:".count))
                extensions.nsfw = (value == "true")
            } else {
                baseTerms.append(term)
            }
        }
        
        return (baseTerms.joined(separator: " "), extensions)
    }
    
    /// Search extensions that can be included in queries.
    public struct SearchExtensions {
        /// Whether to include spam results
        public var includeSpam: Bool = false
        
        /// Domain filter
        public var domain: String?
        
        /// Language code filter
        public var language: String?
        
        /// Sentiment filter
        public var sentiment: Sentiment?
        
        /// NSFW content filter
        public var nsfw: Bool?
        
        /// Sentiment options for filtering
        public enum Sentiment: String {
            case negative
            case neutral
            case positive
        }
    }
}

// MARK: - CoreNostr Integration

extension CoreNostr {
    /// Creates a search request message for relays.
    ///
    /// - Parameters:
    ///   - subscriptionId: Unique subscription identifier
    ///   - query: The search query
    ///   - kinds: Optional event kinds to search
    ///   - authors: Optional authors to search
    ///   - limit: Maximum number of results
    /// - Returns: A properly formatted REQ message
    public static func createSearchRequest(
        subscriptionId: String,
        query: String,
        kinds: [Int]? = nil,
        authors: [PublicKey]? = nil,
        limit: Int? = 100
    ) -> String {
        let filter = NIP50.searchFilter(
            query: query,
            kinds: kinds,
            authors: authors,
            limit: limit
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        do {
            let filterData = try encoder.encode(filter)
            let filterJSON = String(data: filterData, encoding: .utf8) ?? "{}"
            return "[\"REQ\",\"\(subscriptionId)\",\(filterJSON)]"
        } catch {
            return "[\"REQ\",\"\(subscriptionId)\",{}]"
        }
    }
}