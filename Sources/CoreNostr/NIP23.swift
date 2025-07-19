//
//  NIP23.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// NIP-23: Long-form Content
/// https://github.com/nostr-protocol/nips/blob/master/23.md
///
/// Defines long-form text content (articles/blog posts) as addressable events.

// MARK: - Long-form Content

/// A long-form article or blog post
public struct LongFormContent: Sendable {
    /// Unique identifier for the article
    public let identifier: String
    
    /// Article title
    public let title: String
    
    /// Markdown content
    public let content: String
    
    /// Optional article summary
    public let summary: String?
    
    /// Optional header image URL
    public let image: String?
    
    /// Optional first publication timestamp
    public let publishedAt: Date?
    
    /// Hashtags/topics
    public let hashtags: [String]
    
    /// References to other Nostr entities
    public let references: [NostrReference]
    
    /// Whether this is a draft
    public let isDraft: Bool
    
    /// Additional custom tags
    public let customTags: [[String]]
    
    /// Initialize a long-form content article
    public init(
        identifier: String,
        title: String,
        content: String,
        summary: String? = nil,
        image: String? = nil,
        publishedAt: Date? = nil,
        hashtags: [String] = [],
        references: [NostrReference] = [],
        isDraft: Bool = false,
        customTags: [[String]] = []
    ) {
        self.identifier = identifier
        self.title = title
        self.content = content
        self.summary = summary
        self.image = image
        self.publishedAt = publishedAt
        self.hashtags = hashtags
        self.references = references
        self.isDraft = isDraft
        self.customTags = customTags
    }
    
    /// Create tags for the event
    public func toTags() -> [[String]] {
        var tags: [[String]] = []
        
        // Required identifier tag
        tags.append(["d", identifier])
        
        // Title tag
        tags.append(["title", title])
        
        // Optional metadata tags
        if let summary = summary {
            tags.append(["summary", summary])
        }
        
        if let image = image {
            tags.append(["image", image])
        }
        
        if let publishedAt = publishedAt {
            tags.append(["published_at", String(Int64(publishedAt.timeIntervalSince1970))])
        }
        
        // Hashtags
        for hashtag in hashtags {
            let cleanHashtag = hashtag.hasPrefix("#") ? String(hashtag.dropFirst()) : hashtag
            tags.append(["t", cleanHashtag])
        }
        
        // Add reference tags from content
        for reference in references {
            switch reference.type {
            case .event(let id, let relays, let author):
                var eventTag = ["e", id]
                if let firstRelay = relays.first {
                    eventTag.append(firstRelay)
                }
                if let author = author {
                    eventTag.append(author)
                }
                tags.append(eventTag)
                
            case .profile(let pubkey, let relays):
                var profileTag = ["p", pubkey]
                if let firstRelay = relays.first {
                    profileTag.append(firstRelay)
                }
                tags.append(profileTag)
                
            case .address(let identifier, let pubkey, let kind, let relays):
                var addressTag = ["a", "\(kind):\(pubkey):\(identifier)"]
                if let firstRelay = relays.first {
                    addressTag.append(firstRelay)
                }
                tags.append(addressTag)
            }
        }
        
        // Custom tags
        tags.append(contentsOf: customTags)
        
        return tags
    }
    
    /// Parse from a NostrEvent
    public init?(from event: NostrEvent) {
        guard event.kind == EventKind.longFormContent.rawValue || 
              event.kind == EventKind.longFormDraft.rawValue else { return nil }
        
        // Extract required fields
        guard let dTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "d" }),
              let titleTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "title" }) else {
            return nil
        }
        
        self.identifier = dTag[1]
        self.title = titleTag[1]
        self.content = event.content
        self.isDraft = event.kind == EventKind.longFormDraft.rawValue
        
        // Extract optional metadata
        self.summary = event.tags.first(where: { $0.count >= 2 && $0[0] == "summary" })?[1]
        self.image = event.tags.first(where: { $0.count >= 2 && $0[0] == "image" })?[1]
        
        if let publishedAtTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "published_at" }),
           let timestamp = Int64(publishedAtTag[1]) {
            self.publishedAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            self.publishedAt = nil
        }
        
        // Extract hashtags
        self.hashtags = event.tags
            .filter { $0.count >= 2 && $0[0] == "t" }
            .map { $0[1] }
        
        // Parse references from content
        self.references = NostrReference.parseFromText(content)
        
        // Extract custom tags (excluding standard ones)
        let standardTags = ["d", "title", "summary", "image", "published_at", "t", "e", "p", "a"]
        self.customTags = event.tags.filter { tag in
            !tag.isEmpty && !standardTags.contains(tag[0])
        }
    }
}

// MARK: - Article Metadata

/// Metadata for discovering and displaying articles
public struct ArticleMetadata: Sendable {
    public let identifier: String
    public let title: String
    public let summary: String?
    public let image: String?
    public let publishedAt: Date?
    public let author: String
    public let lastUpdated: Date
    public let hashtags: [String]
    
    /// Initialize from a NostrEvent
    public init?(from event: NostrEvent) {
        guard let article = LongFormContent(from: event) else { return nil }
        
        self.identifier = article.identifier
        self.title = article.title
        self.summary = article.summary
        self.image = article.image
        self.publishedAt = article.publishedAt
        self.author = event.pubkey
        self.lastUpdated = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        self.hashtags = article.hashtags
    }
}

// MARK: - CoreNostr Extensions

public extension CoreNostr {
    /// Create a long-form content event
    static func createLongFormContent(
        _ article: LongFormContent,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let kind = article.isDraft ? EventKind.longFormDraft : EventKind.longFormContent
        
        // If no references were provided, parse them from content
        var articleToUse = article
        if article.references.isEmpty {
            articleToUse = LongFormContent(
                identifier: article.identifier,
                title: article.title,
                content: article.content,
                summary: article.summary,
                image: article.image,
                publishedAt: article.publishedAt,
                hashtags: article.hashtags,
                references: NostrReference.parseFromText(article.content),
                isDraft: article.isDraft,
                customTags: article.customTags
            )
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: kind.rawValue,
            tags: articleToUse.toTags(),
            content: articleToUse.content
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Create a new article
    static func createArticle(
        identifier: String,
        title: String,
        content: String,
        summary: String? = nil,
        image: String? = nil,
        hashtags: [String] = [],
        isDraft: Bool = false,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let article = LongFormContent(
            identifier: identifier,
            title: title,
            content: content,
            summary: summary,
            image: image,
            publishedAt: isDraft ? nil : Date(),
            hashtags: hashtags,
            isDraft: isDraft
        )
        
        return try createLongFormContent(article, keyPair: keyPair)
    }
    
    /// Update an existing article
    static func updateArticle(
        identifier: String,
        title: String,
        content: String,
        summary: String? = nil,
        image: String? = nil,
        hashtags: [String] = [],
        originalPublishedAt: Date? = nil,
        isDraft: Bool = false,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let article = LongFormContent(
            identifier: identifier,
            title: title,
            content: content,
            summary: summary,
            image: image,
            publishedAt: originalPublishedAt,
            hashtags: hashtags,
            isDraft: isDraft
        )
        
        return try createLongFormContent(article, keyPair: keyPair)
    }
    
    /// Publish a draft (convert draft to published article)
    static func publishDraft(
        _ draft: LongFormContent,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        let publishedArticle = LongFormContent(
            identifier: draft.identifier,
            title: draft.title,
            content: draft.content,
            summary: draft.summary,
            image: draft.image,
            publishedAt: draft.publishedAt ?? Date(),
            hashtags: draft.hashtags,
            references: draft.references,
            isDraft: false,
            customTags: draft.customTags
        )
        
        return try createLongFormContent(publishedArticle, keyPair: keyPair)
    }
}

// MARK: - NostrEvent Extensions

public extension NostrEvent {
    /// Check if this is a long-form content event
    var isLongFormContent: Bool {
        kind == EventKind.longFormContent.rawValue
    }
    
    /// Check if this is a long-form draft event
    var isLongFormDraft: Bool {
        kind == EventKind.longFormDraft.rawValue
    }
    
    /// Check if this is any long-form event
    var isLongForm: Bool {
        isLongFormContent || isLongFormDraft
    }
    
    /// Parse long-form content from this event
    func parseLongFormContent() -> LongFormContent? {
        LongFormContent(from: self)
    }
    
    /// Get article metadata
    func getArticleMetadata() -> ArticleMetadata? {
        ArticleMetadata(from: self)
    }
}

// MARK: - Filter Extensions

public extension Filter {
    /// Create a filter for long-form content
    static func longFormContent(
        authors: [String]? = nil,
        identifiers: [String]? = nil,
        hashtags: [String]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil,
        includeDrafts: Bool = false
    ) -> Filter {
        var kinds = [EventKind.longFormContent.rawValue]
        if includeDrafts {
            kinds.append(EventKind.longFormDraft.rawValue)
        }
        
        // Note: Filter doesn't support d-tags and t-tags directly
        // These would need to be filtered client-side
        // For now, just filter by author and kind
        
        return Filter(
            authors: authors,
            kinds: kinds,
            since: since,
            until: until,
            limit: limit
        )
    }
    
    /// Create a filter for a specific article
    static func article(
        identifier: String,
        author: String,
        kind: EventKind = .longFormContent
    ) -> Filter {
        return Filter(
            authors: [author],
            kinds: [kind.rawValue]
        )
        // Note: d-tag filtering would need to be done client-side
    }
}

// MARK: - Article Discovery Helpers

public struct ArticleDiscovery {
    /// Find all articles by hashtag
    public static func byHashtag(
        _ hashtag: String,
        limit: Int = 20
    ) -> Filter {
        Filter.longFormContent(
            hashtags: [hashtag],
            limit: limit
        )
    }
    
    /// Find all articles by author
    public static func byAuthor(
        _ author: String,
        includeDrafts: Bool = false,
        limit: Int = 20
    ) -> Filter {
        Filter.longFormContent(
            authors: [author],
            limit: limit,
            includeDrafts: includeDrafts
        )
    }
    
    /// Find recent articles
    public static func recent(
        since: Date? = nil,
        limit: Int = 50
    ) -> Filter {
        Filter.longFormContent(
            since: since,
            limit: limit
        )
    }
}