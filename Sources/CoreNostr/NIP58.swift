//
//  NIP58.swift
//  CoreNostr
//
//  NIP-58: Badges
//  https://github.com/nostr-protocol/nips/blob/master/58.md
//

import Foundation

/// NIP-58: Badges
///
/// This NIP defines a system for creating, awarding, and displaying badges.
/// Badges are a way to recognize users for achievements, participation, or
/// other acknowledgments in a decentralized manner.
///
/// ## Example Usage
/// ```swift
/// // Create a badge definition
/// let badgeDefinition = try NIP58.createBadgeDefinition(
///     identifier: "contributor-2024",
///     name: "2024 Contributor",
///     description: "Contributed to the project in 2024",
///     image: "https://example.com/badge.png",
///     keyPair: issuerKeyPair
/// )
/// 
/// // Award the badge to users
/// let award = try NIP58.createBadgeAward(
///     badgeDefinition: badgeDefinition,
///     awardedTo: ["user-pubkey-1", "user-pubkey-2"],
///     keyPair: issuerKeyPair
/// )
/// ```
public enum NIP58 {
    
    // MARK: - Event Kinds
    
    /// Badge Definition event kind (parameterized replaceable)
    public static let badgeDefinitionKind = 30009
    
    /// Badge Award event kind
    public static let badgeAwardKind = 8
    
    /// Profile Badges event kind (parameterized replaceable)
    public static let profileBadgesKind = 30008
    
    // MARK: - Badge Definition
    
    /// Creates a badge definition event.
    ///
    /// - Parameters:
    ///   - identifier: Unique identifier for the badge
    ///   - name: Short name for the badge
    ///   - description: What the badge represents
    ///   - image: High-resolution badge image URL
    ///   - thumbnails: Optional thumbnail URLs at various sizes
    ///   - keyPair: The issuer's key pair
    /// - Returns: A signed badge definition event
    /// - Throws: NostrError if signing fails
    public static func createBadgeDefinition(
        identifier: String,
        name: String? = nil,
        description: String? = nil,
        image: String? = nil,
        thumbnails: [ThumbnailSize: String]? = nil,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Required: d tag with unique identifier
        tags.append(["d", identifier])
        
        // Optional: name
        if let name = name {
            tags.append(["name", name])
        }
        
        // Optional: description
        if let description = description {
            tags.append(["description", description])
        }
        
        // Optional: image
        if let image = image {
            tags.append(["image", image])
        }
        
        // Optional: thumbnails
        if let thumbnails = thumbnails {
            for (size, url) in thumbnails.sorted(by: { $0.key.pixels < $1.key.pixels }) {
                tags.append(["thumb", "\(size.pixels)x\(size.pixels)", url])
            }
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: badgeDefinitionKind,
            tags: tags,
            content: ""
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Thumbnail sizes for badge images
    public enum ThumbnailSize: Int, CaseIterable {
        case tiny = 16
        case small = 32
        case medium = 64
        case large = 128
        case xlarge = 256
        case xxlarge = 512
        
        /// Size in pixels (square)
        public var pixels: Int { rawValue }
    }
    
    // MARK: - Badge Award
    
    /// Creates a badge award event.
    ///
    /// - Parameters:
    ///   - badgeDefinition: The badge definition event being awarded
    ///   - awardedTo: Public keys of users receiving the badge
    ///   - content: Optional award message
    ///   - keyPair: The issuer's key pair
    /// - Returns: A signed badge award event
    /// - Throws: NostrError if signing fails
    public static func createBadgeAward(
        badgeDefinition: NostrEvent,
        awardedTo: [PublicKey],
        content: String = "",
        keyPair: KeyPair
    ) throws -> NostrEvent {
        guard badgeDefinition.kind == badgeDefinitionKind else {
            throw NostrError.invalidEvent("Event is not a badge definition")
        }
        
        // Extract d tag value from badge definition
        guard let dTag = badgeDefinition.tags.first(where: { $0.count >= 2 && $0[0] == "d" }),
              let identifier = dTag.count >= 2 ? dTag[1] : nil else {
            throw NostrError.invalidEvent("Badge definition missing d tag")
        }
        
        var tags: [[String]] = []
        
        // Required: a tag referencing the badge definition
        let aTag = "\(badgeDefinitionKind):\(badgeDefinition.pubkey):\(identifier)"
        tags.append(["a", aTag])
        
        // Required: p tags for each awarded user
        for pubkey in awardedTo {
            tags.append(["p", pubkey])
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: badgeAwardKind,
            tags: tags,
            content: content
        )
        
        return try keyPair.signEvent(event)
    }
    
    // MARK: - Profile Badges
    
    /// Creates a profile badges event displaying selected badges.
    ///
    /// - Parameters:
    ///   - badges: Array of badge display items
    ///   - keyPair: The user's key pair
    /// - Returns: A signed profile badges event
    /// - Throws: NostrError if signing fails
    public static func createProfileBadges(
        badges: [BadgeDisplay],
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Required: d tag with "profile_badges"
        tags.append(["d", "profile_badges"])
        
        // Add ordered pairs of a and e tags
        for badge in badges {
            tags.append(["a", badge.badgeDefinitionTag])
            tags.append(["e", badge.badgeAwardEventId])
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: profileBadgesKind,
            tags: tags,
            content: ""
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Represents a badge to display on a profile
    public struct BadgeDisplay {
        /// The "a" tag value for the badge definition
        public let badgeDefinitionTag: String
        
        /// The event ID of the badge award
        public let badgeAwardEventId: EventID
        
        /// Creates a badge display from a badge definition and award
        public init(definition: NostrEvent, award: NostrEvent) throws {
            guard definition.kind == badgeDefinitionKind else {
                throw NostrError.invalidEvent("Not a badge definition event")
            }
            
            guard award.kind == badgeAwardKind else {
                throw NostrError.invalidEvent("Not a badge award event")
            }
            
            // Extract d tag from definition
            guard let dTag = definition.tags.first(where: { $0.count >= 2 && $0[0] == "d" }),
                  let identifier = dTag.count >= 2 ? dTag[1] : nil else {
                throw NostrError.invalidEvent("Badge definition missing d tag")
            }
            
            self.badgeDefinitionTag = "\(badgeDefinitionKind):\(definition.pubkey):\(identifier)"
            self.badgeAwardEventId = award.id
        }
        
        /// Creates a badge display with explicit values
        public init(badgeDefinitionTag: String, badgeAwardEventId: EventID) {
            self.badgeDefinitionTag = badgeDefinitionTag
            self.badgeAwardEventId = badgeAwardEventId
        }
    }
    
    // MARK: - Badge Parsing
    
    /// Parses a badge definition from an event.
    public static func parseBadgeDefinition(from event: NostrEvent) -> BadgeDefinition? {
        guard event.kind == badgeDefinitionKind else {
            return nil
        }
        
        guard let dTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "d" }),
              let identifier = dTag.count >= 2 ? dTag[1] : nil else {
            return nil
        }
        
        let name = event.tags.first(where: { $0.count >= 2 && $0[0] == "name" })?[1]
        let description = event.tags.first(where: { $0.count >= 2 && $0[0] == "description" })?[1]
        let image = event.tags.first(where: { $0.count >= 2 && $0[0] == "image" })?[1]
        
        var thumbnails: [String: String] = [:]
        for tag in event.tags where tag.count >= 3 && tag[0] == "thumb" {
            thumbnails[tag[1]] = tag[2]
        }
        
        return BadgeDefinition(
            event: event,
            identifier: identifier,
            name: name,
            description: description,
            image: image,
            thumbnails: thumbnails.isEmpty ? nil : thumbnails
        )
    }
    
    /// Parsed badge definition
    public struct BadgeDefinition {
        public let event: NostrEvent
        public let identifier: String
        public let name: String?
        public let description: String?
        public let image: String?
        public let thumbnails: [String: String]?
        
        /// The issuer's public key
        public var issuer: PublicKey {
            event.pubkey
        }
        
        /// When the badge was defined
        public var createdAt: Date {
            Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        }
    }
    
    /// Parses a badge award from an event.
    public static func parseBadgeAward(from event: NostrEvent) -> BadgeAward? {
        guard event.kind == badgeAwardKind else {
            return nil
        }
        
        guard let aTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "a" }) else {
            return nil
        }
        
        let awardedTo = event.tags
            .filter { $0.count >= 2 && $0[0] == "p" }
            .map { $0[1] }
        
        guard !awardedTo.isEmpty else {
            return nil
        }
        
        return BadgeAward(
            event: event,
            badgeReference: aTag[1],
            awardedTo: awardedTo,
            message: event.content.isEmpty ? nil : event.content
        )
    }
    
    /// Parsed badge award
    public struct BadgeAward {
        public let event: NostrEvent
        public let badgeReference: String
        public let awardedTo: [PublicKey]
        public let message: String?
        
        /// The awarder's public key
        public var awarder: PublicKey {
            event.pubkey
        }
        
        /// When the badge was awarded
        public var awardedAt: Date {
            Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        }
    }
    
    /// Parses profile badges from an event.
    public static func parseProfileBadges(from event: NostrEvent) -> [BadgeDisplay]? {
        guard event.kind == profileBadgesKind else {
            return nil
        }
        
        guard event.tags.contains(where: { $0.count >= 2 && $0[0] == "d" && $0[1] == "profile_badges" }) else {
            return nil
        }
        
        var badges: [BadgeDisplay] = []
        var currentATag: String?
        
        for tag in event.tags {
            if tag.count >= 2 {
                if tag[0] == "a" {
                    currentATag = tag[1]
                } else if tag[0] == "e", let aTag = currentATag {
                    badges.append(BadgeDisplay(
                        badgeDefinitionTag: aTag,
                        badgeAwardEventId: tag[1]
                    ))
                    currentATag = nil
                }
            }
        }
        
        return badges.isEmpty ? nil : badges
    }
}

// MARK: - Filter Extensions

extension Filter {
    /// Creates a filter for badge definition events.
    ///
    /// - Parameters:
    ///   - issuers: Only include badges from these issuers
    ///   - identifiers: Specific badge identifiers to fetch
    /// - Returns: A filter for badge definitions
    public static func badgeDefinitions(
        issuers: [PublicKey]? = nil,
        identifiers: [String]? = nil
    ) -> Filter {
        let filter = Filter(
            authors: issuers,
            kinds: [NIP58.badgeDefinitionKind]
        )
        
        // Note: d tag filtering would need relay support for #d tag filtering
        // which is not currently in the Filter model
        _ = identifiers
        
        return filter
    }
    
    /// Creates a filter for badge award events.
    ///
    /// - Parameters:
    ///   - awarders: Only include awards from these awarders
    ///   - recipients: Only include awards to these recipients
    ///   - limit: Maximum number of awards
    /// - Returns: A filter for badge awards
    public static func badgeAwards(
        awarders: [PublicKey]? = nil,
        recipients: [PublicKey]? = nil,
        limit: Int? = 100
    ) -> Filter {
        return Filter(
            authors: awarders,
            kinds: [NIP58.badgeAwardKind],
            limit: limit,
            p: recipients
        )
    }
    
    /// Creates a filter for profile badges events.
    ///
    /// - Parameters:
    ///   - pubkeys: Users whose profile badges to fetch
    /// - Returns: A filter for profile badges
    public static func profileBadges(
        pubkeys: [PublicKey]
    ) -> Filter {
        return Filter(
            authors: pubkeys,
            kinds: [NIP58.profileBadgesKind]
        )
    }
}