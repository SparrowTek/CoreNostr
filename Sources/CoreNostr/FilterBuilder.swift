import Foundation

/// A fluent builder for creating Nostr filters
///
/// FilterBuilder provides a chainable API for constructing filters
/// with better ergonomics and type safety.
///
/// Example usage:
/// ```swift
/// let filter = FilterBuilder()
///     .kinds([1, 6, 7])
///     .author(pubkey)
///     .since(.now.addingTimeInterval(-3600))
///     .limit(50)
///     .build()
/// ```
public struct FilterBuilder: Sendable {
    private var filter: Filter
    
    /// Creates a new filter builder
    public init() {
        self.filter = Filter()
    }
    
    /// Creates a filter builder from an existing filter
    /// - Parameter filter: The filter to start with
    public init(from filter: Filter) {
        self.filter = filter
    }
    
    // MARK: - ID Filtering
    
    /// Filters by specific event IDs
    /// - Parameter ids: Array of event IDs
    /// - Returns: The builder for chaining
    public func ids(_ ids: [String]) -> FilterBuilder {
        var builder = self
        builder.filter.ids = ids
        return builder
    }
    
    /// Filters by a single event ID
    /// - Parameter id: The event ID
    /// - Returns: The builder for chaining
    public func id(_ id: String) -> FilterBuilder {
        return ids([id])
    }
    
    // MARK: - Author Filtering
    
    /// Filters by author public keys
    /// - Parameter authors: Array of public keys
    /// - Returns: The builder for chaining
    public func authors(_ authors: [String]) -> FilterBuilder {
        var builder = self
        builder.filter.authors = authors
        return builder
    }
    
    /// Filters by a single author
    /// - Parameter author: The author's public key
    /// - Returns: The builder for chaining
    public func author(_ author: String) -> FilterBuilder {
        return authors([author])
    }
    
    // MARK: - Kind Filtering
    
    /// Filters by event kinds
    /// - Parameter kinds: Array of event kinds
    /// - Returns: The builder for chaining
    public func kinds(_ kinds: [Int]) -> FilterBuilder {
        var builder = self
        builder.filter.kinds = kinds
        return builder
    }
    
    /// Filters by a single event kind
    /// - Parameter kind: The event kind
    /// - Returns: The builder for chaining
    public func kind(_ kind: Int) -> FilterBuilder {
        return kinds([kind])
    }
    
    /// Filters for text notes (kind 1)
    /// - Returns: The builder for chaining
    public func textNotes() -> FilterBuilder {
        return kind(1)
    }
    
    /// Filters for metadata events (kind 0)
    /// - Returns: The builder for chaining
    public func metadata() -> FilterBuilder {
        return kind(0)
    }
    
    /// Filters for contact lists (kind 3)
    /// - Returns: The builder for chaining
    public func contactLists() -> FilterBuilder {
        return kind(3)
    }
    
    /// Filters for encrypted direct messages (kind 4)
    /// - Returns: The builder for chaining
    public func directMessages() -> FilterBuilder {
        return kind(4)
    }
    
    /// Filters for deletion events (kind 5)
    /// - Returns: The builder for chaining
    public func deletions() -> FilterBuilder {
        return kind(5)
    }
    
    /// Filters for reposts (kind 6)
    /// - Returns: The builder for chaining
    public func reposts() -> FilterBuilder {
        return kind(6)
    }
    
    /// Filters for reactions (kind 7)
    /// - Returns: The builder for chaining
    public func reactions() -> FilterBuilder {
        return kind(7)
    }
    
    /// Filters for long-form content (kind 30023)
    /// - Returns: The builder for chaining
    public func articles() -> FilterBuilder {
        return kind(30023)
    }
    
    // MARK: - Time Filtering
    
    /// Filters events created after a certain time
    /// - Parameter date: The minimum creation date
    /// - Returns: The builder for chaining
    public func since(_ date: Date) -> FilterBuilder {
        var builder = self
        builder.filter.since = Int64(date.timeIntervalSince1970)
        return builder
    }
    
    /// Filters events created before a certain time
    /// - Parameter date: The maximum creation date
    /// - Returns: The builder for chaining
    public func until(_ date: Date) -> FilterBuilder {
        var builder = self
        builder.filter.until = Int64(date.timeIntervalSince1970)
        return builder
    }
    
    /// Filters events within a time range
    /// - Parameters:
    ///   - from: Start of the time range
    ///   - to: End of the time range
    /// - Returns: The builder for chaining
    public func between(_ from: Date, and to: Date) -> FilterBuilder {
        return since(from).until(to)
    }
    
    /// Filters events from the last N seconds
    /// - Parameter seconds: Number of seconds ago
    /// - Returns: The builder for chaining
    public func lastSeconds(_ seconds: TimeInterval) -> FilterBuilder {
        return since(Date().addingTimeInterval(-seconds))
    }
    
    /// Filters events from the last N minutes
    /// - Parameter minutes: Number of minutes ago
    /// - Returns: The builder for chaining
    public func lastMinutes(_ minutes: Double) -> FilterBuilder {
        return lastSeconds(minutes * 60)
    }
    
    /// Filters events from the last N hours
    /// - Parameter hours: Number of hours ago
    /// - Returns: The builder for chaining
    public func lastHours(_ hours: Double) -> FilterBuilder {
        return lastMinutes(hours * 60)
    }
    
    /// Filters events from the last N days
    /// - Parameter days: Number of days ago
    /// - Returns: The builder for chaining
    public func lastDays(_ days: Double) -> FilterBuilder {
        return lastHours(days * 24)
    }
    
    // MARK: - Tag Filtering
    
    /// Filters by referenced event IDs (e tags)
    /// - Parameter eventIds: Array of event IDs
    /// - Returns: The builder for chaining
    public func referencingEvents(_ eventIds: [String]) -> FilterBuilder {
        var builder = self
        builder.filter.e = eventIds
        return builder
    }
    
    /// Filters by a single referenced event
    /// - Parameter eventId: The event ID
    /// - Returns: The builder for chaining
    public func referencingEvent(_ eventId: String) -> FilterBuilder {
        return referencingEvents([eventId])
    }
    
    /// Filters by referenced public keys (p tags)
    /// - Parameter pubkeys: Array of public keys
    /// - Returns: The builder for chaining
    public func mentioning(_ pubkeys: [String]) -> FilterBuilder {
        var builder = self
        builder.filter.p = pubkeys
        return builder
    }
    
    /// Filters by a single mentioned user
    /// - Parameter pubkey: The public key
    /// - Returns: The builder for chaining
    public func mentioning(user pubkey: String) -> FilterBuilder {
        return mentioning([pubkey])
    }
    
    // MARK: - Search
    
    /// Adds a search query (NIP-50)
    /// - Parameter query: The search query
    /// - Returns: The builder for chaining
    public func search(_ query: String) -> FilterBuilder {
        var builder = self
        builder.filter.search = query
        return builder
    }
    
    // MARK: - Limit
    
    /// Sets the maximum number of events to return
    /// - Parameter limit: The maximum number
    /// - Returns: The builder for chaining
    public func limit(_ limit: Int) -> FilterBuilder {
        var builder = self
        builder.filter.limit = limit
        return builder
    }
    
    // MARK: - Building
    
    /// Builds the filter
    /// - Returns: The constructed Filter
    public func build() -> Filter {
        return filter
    }
}

// MARK: - Static Factory Methods

public extension FilterBuilder {
    
    /// Creates a filter for a user's recent posts
    /// - Parameters:
    ///   - pubkey: The user's public key
    ///   - limit: Maximum number of posts
    /// - Returns: A configured FilterBuilder
    static func userPosts(_ pubkey: String, limit: Int = 20) -> FilterBuilder {
        return FilterBuilder()
            .author(pubkey)
            .kinds([1, 6, 7]) // Text notes, reposts, reactions
            .limit(limit)
    }
    
    /// Creates a filter for a user's profile metadata
    /// - Parameter pubkey: The user's public key
    /// - Returns: A configured FilterBuilder
    static func userProfile(_ pubkey: String) -> FilterBuilder {
        return FilterBuilder()
            .author(pubkey)
            .metadata()
            .limit(1)
    }
    
    /// Creates a filter for replies to an event
    /// - Parameters:
    ///   - eventId: The event ID
    ///   - limit: Maximum number of replies
    /// - Returns: A configured FilterBuilder
    static func replies(to eventId: String, limit: Int = 50) -> FilterBuilder {
        return FilterBuilder()
            .textNotes()
            .referencingEvent(eventId)
            .limit(limit)
    }
    
    /// Creates a filter for a user's mentions
    /// - Parameters:
    ///   - pubkey: The user's public key
    ///   - limit: Maximum number of mentions
    /// - Returns: A configured FilterBuilder
    static func mentions(of pubkey: String, limit: Int = 50) -> FilterBuilder {
        return FilterBuilder()
            .mentioning(user: pubkey)
            .limit(limit)
    }
    
    /// Creates a filter for global feed
    /// - Parameters:
    ///   - limit: Maximum number of events
    ///   - since: Optional start time
    /// - Returns: A configured FilterBuilder
    static func globalFeed(limit: Int = 100, since: Date? = nil) -> FilterBuilder {
        var builder = FilterBuilder()
            .textNotes()
            .limit(limit)
        
        if let since = since {
            builder = builder.since(since)
        }
        
        return builder
    }
    
    /// Creates a filter for following feed
    /// - Parameters:
    ///   - following: Array of public keys being followed
    ///   - limit: Maximum number of events
    ///   - since: Optional start time
    /// - Returns: A configured FilterBuilder
    static func followingFeed(_ following: [String], limit: Int = 100, since: Date? = nil) -> FilterBuilder {
        var builder = FilterBuilder()
            .authors(following)
            .kinds([1, 6]) // Text notes and reposts
            .limit(limit)
        
        if let since = since {
            builder = builder.since(since)
        }
        
        return builder
    }
}

// MARK: - Filter Extension for Fluent API

public extension Filter {
    
    /// Creates a FilterBuilder from this filter
    /// - Returns: A FilterBuilder initialized with this filter
    func builder() -> FilterBuilder {
        return FilterBuilder(from: self)
    }
    
    /// Converts to a FilterBuilder for chaining
    var fluent: FilterBuilder {
        return builder()
    }
}

// MARK: - Convenience Initializers

public extension Filter {
    
    /// Creates a filter using a builder closure
    /// - Parameter build: Closure that configures the FilterBuilder
    /// - Returns: The built Filter
    static func build(_ build: (FilterBuilder) -> FilterBuilder) -> Filter {
        return build(FilterBuilder()).build()
    }
    
    /// Creates a filter for specific event kinds
    /// - Parameters:
    ///   - kinds: The event kinds to filter
    ///   - limit: Optional limit
    /// - Returns: A configured Filter
    static func kinds(_ kinds: [Int], limit: Int? = nil) -> Filter {
        var builder = FilterBuilder().kinds(kinds)
        if let limit = limit {
            builder = builder.limit(limit)
        }
        return builder.build()
    }
    
    /// Creates a filter for a specific author
    /// - Parameters:
    ///   - author: The author's public key
    ///   - kinds: Optional event kinds
    ///   - limit: Optional limit
    /// - Returns: A configured Filter
    static func author(_ author: String, kinds: [Int]? = nil, limit: Int? = nil) -> Filter {
        var builder = FilterBuilder().author(author)
        if let kinds = kinds {
            builder = builder.kinds(kinds)
        }
        if let limit = limit {
            builder = builder.limit(limit)
        }
        return builder.build()
    }
}