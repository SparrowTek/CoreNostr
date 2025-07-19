//
//  NIP25.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// NIP-25: Reactions
/// https://github.com/nostr-protocol/nips/blob/master/25.md
///
/// Defines reactions as a way of reacting to other events.

/// Represents the content of a reaction event
public enum ReactionContent: Sendable, Equatable {
    /// A positive reaction (like/upvote)
    case plus
    
    /// A negative reaction (dislike/downvote)
    case minus
    
    /// An emoji reaction
    case emoji(String)
    
    /// A custom emoji reaction with shortcode
    case customEmoji(shortcode: String)
    
    /// Initialize from the content string of a reaction event
    public init(from content: String) {
        switch content {
        case "+":
            self = .plus
        case "-":
            self = .minus
        case let emoji where emoji.hasPrefix(":") && emoji.hasSuffix(":"):
            let shortcode = String(emoji.dropFirst().dropLast())
            self = .customEmoji(shortcode: shortcode)
        default:
            self = .emoji(content)
        }
    }
    
    /// The content string representation
    public var content: String {
        switch self {
        case .plus:
            return "+"
        case .minus:
            return "-"
        case .emoji(let emoji):
            return emoji
        case .customEmoji(let shortcode):
            return ":\(shortcode):"
        }
    }
    
    /// Whether this reaction should be interpreted as a like
    public var isLike: Bool {
        self == .plus
    }
    
    /// Whether this reaction should be interpreted as a dislike
    public var isDislike: Bool {
        self == .minus
    }
}

/// Represents a reaction to a Nostr event
public struct NostrReaction: Sendable {
    /// The event being reacted to
    public let eventId: String
    
    /// The pubkey of the event author being reacted to
    public let eventPubkey: String
    
    /// The kind of the event being reacted to (optional)
    public let eventKind: EventKind?
    
    /// The reaction content
    public let reaction: ReactionContent
    
    /// Custom emoji information if this is a custom emoji reaction
    public let customEmojiURL: URL?
    
    /// Relay hint for the event being reacted to
    public let relayHint: String?
    
    /// Initialize a reaction to an event
    public init(
        eventId: String,
        eventPubkey: String,
        eventKind: EventKind? = nil,
        reaction: ReactionContent,
        customEmojiURL: URL? = nil,
        relayHint: String? = nil
    ) {
        self.eventId = eventId
        self.eventPubkey = eventPubkey
        self.eventKind = eventKind
        self.reaction = reaction
        self.customEmojiURL = customEmojiURL
        self.relayHint = relayHint
    }
}

/// Represents a reaction to a website
public struct NostrWebsiteReaction: Sendable {
    /// The normalized URL being reacted to
    public let url: URL
    
    /// The reaction content
    public let reaction: ReactionContent
    
    /// Custom emoji information if this is a custom emoji reaction
    public let customEmojiURL: URL?
    
    /// Initialize a reaction to a website
    public init(
        url: URL,
        reaction: ReactionContent,
        customEmojiURL: URL? = nil
    ) {
        self.url = url
        self.reaction = reaction
        self.customEmojiURL = customEmojiURL
    }
}

// MARK: - CoreNostr Extensions for Reactions

public extension CoreNostr {
    /// Create a reaction event to another event
    static func createReaction(
        to eventId: String,
        eventPubkey: String,
        eventKind: EventKind? = nil,
        reaction: ReactionContent,
        customEmojiURL: URL? = nil,
        relayHint: String? = nil,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Add event tag
        var eventTag = ["e", eventId]
        if let relayHint = relayHint {
            eventTag.append(relayHint)
        }
        tags.append(eventTag)
        
        // Add pubkey tag
        tags.append(["p", eventPubkey])
        
        // Add kind tag if provided
        if let eventKind = eventKind {
            tags.append(["k", String(eventKind.rawValue)])
        }
        
        // Add emoji tag for custom emoji
        if case .customEmoji(let shortcode) = reaction,
           let customEmojiURL = customEmojiURL {
            tags.append(["emoji", shortcode, customEmojiURL.absoluteString])
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.reaction.rawValue,
            tags: tags,
            content: reaction.content
        )
        return try keyPair.signEvent(event)
    }
    
    /// Create a reaction event to a website
    static func createWebsiteReaction(
        to url: URL,
        reaction: ReactionContent,
        customEmojiURL: URL? = nil,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Add normalized URL tag
        let normalizedURL = normalizeURL(url)
        tags.append(["r", normalizedURL])
        
        // Add emoji tag for custom emoji
        if case .customEmoji(let shortcode) = reaction,
           let customEmojiURL = customEmojiURL {
            tags.append(["emoji", shortcode, customEmojiURL.absoluteString])
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.websiteReaction.rawValue,
            tags: tags,
            content: reaction.content
        )
        return try keyPair.signEvent(event)
    }
}

// MARK: - NostrEvent Extensions for Parsing

public extension NostrEvent {
    /// Parse a reaction from this event
    func parseReaction() -> NostrReaction? {
        guard kind == EventKind.reaction.rawValue else { return nil }
        
        // Find required tags
        let eTags = tags.filter { $0.count >= 2 && $0[0] == "e" }
        let pTags = tags.filter { $0.count >= 2 && $0[0] == "p" }
        
        guard let eTag = eTags.first,
              let pTag = pTags.first else {
            return nil
        }
        
        let eventId = eTag[1]
        let eventPubkey = pTag[1]
        let relayHint = eTag.count > 2 ? eTag[2] : nil
        
        // Parse optional kind tag
        let kTag = tags.first { $0.count >= 2 && $0[0] == "k" }
        let eventKind = kTag.flatMap { Int($0[1]) }.flatMap { EventKind(rawValue: $0) }
        
        // Parse reaction content
        let reaction = ReactionContent(from: content)
        
        // Parse custom emoji URL if applicable
        var customEmojiURL: URL?
        if case .customEmoji(let shortcode) = reaction {
            let emojiTag = tags.first { $0.count >= 3 && $0[0] == "emoji" && $0[1] == shortcode }
            customEmojiURL = emojiTag.flatMap { URL(string: $0[2]) }
        }
        
        return NostrReaction(
            eventId: eventId,
            eventPubkey: eventPubkey,
            eventKind: eventKind,
            reaction: reaction,
            customEmojiURL: customEmojiURL,
            relayHint: relayHint
        )
    }
    
    /// Parse a website reaction from this event
    func parseWebsiteReaction() -> NostrWebsiteReaction? {
        guard kind == EventKind.websiteReaction.rawValue else { return nil }
        
        // Find required URL tag
        let rTag = tags.first { $0.count >= 2 && $0[0] == "r" }
        guard let rTag = rTag,
              let url = URL(string: rTag[1]) else {
            return nil
        }
        
        // Parse reaction content
        let reaction = ReactionContent(from: content)
        
        // Parse custom emoji URL if applicable
        var customEmojiURL: URL?
        if case .customEmoji(let shortcode) = reaction {
            let emojiTag = tags.first { $0.count >= 3 && $0[0] == "emoji" && $0[1] == shortcode }
            customEmojiURL = emojiTag.flatMap { URL(string: $0[2]) }
        }
        
        return NostrWebsiteReaction(
            url: url,
            reaction: reaction,
            customEmojiURL: customEmojiURL
        )
    }
}

// MARK: - URL Normalization

private func normalizeURL(_ url: URL) -> String {
    // Start with URL components for proper parsing
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url.absoluteString
    }
    
    // Lowercase scheme and host
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    
    // Remove fragment
    components.fragment = nil
    
    // Get the normalized URL
    guard let normalizedURL = components.url else {
        return url.absoluteString
    }
    
    var normalized = normalizedURL.absoluteString
    
    // Remove trailing slash from path (but not if it's just the root "/")
    if normalized.hasSuffix("/") && normalized != components.scheme! + "://" + (components.host ?? "") + "/" {
        normalized = String(normalized.dropLast())
    }
    
    return normalized
}