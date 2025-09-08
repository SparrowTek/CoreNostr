import Foundation

/// A builder for creating Nostr events with a fluent API
///
/// EventBuilder provides an ergonomic way to construct Nostr events
/// with proper validation and type safety.
///
/// Example usage:
/// ```swift
/// let event = try EventBuilder.text("Hello, Nostr!")
///     .mention(pubkey: "abc123...")
///     .hashtag("nostr")
///     .build(with: keyPair)
/// ```
public struct EventBuilder: Sendable {
    private var kind: Int
    private var content: String
    private var tags: [[String]]
    private var createdAt: Date?
    
    // MARK: - Initialization
    
    /// Creates a new event builder
    /// - Parameters:
    ///   - kind: The event kind
    ///   - content: The event content
    private init(kind: Int, content: String = "") {
        self.kind = kind
        self.content = content
        self.tags = []
        self.createdAt = nil
    }
    
    // MARK: - Factory Methods
    
    /// Creates a text note event (kind 1)
    /// - Parameter text: The text content
    /// - Returns: An EventBuilder configured for a text note
    public static func text(_ text: String) -> EventBuilder {
        return EventBuilder(kind: 1, content: text)
    }
    
    /// Creates a metadata event (kind 0)
    /// - Parameters:
    ///   - name: Display name
    ///   - about: About/bio text
    ///   - picture: Profile picture URL
    ///   - nip05: NIP-05 identifier
    ///   - banner: Banner image URL
    ///   - website: Website URL
    ///   - lud06: Lightning address (LNURL)
    ///   - lud16: Lightning address (email format)
    /// - Returns: An EventBuilder configured for metadata
    public static func metadata(
        name: String? = nil,
        about: String? = nil,
        picture: String? = nil,
        nip05: String? = nil,
        banner: String? = nil,
        website: String? = nil,
        lud06: String? = nil,
        lud16: String? = nil
    ) -> EventBuilder {
        var metadata: [String: String] = [:]
        
        if let name = name { metadata["name"] = name }
        if let about = about { metadata["about"] = about }
        if let picture = picture { metadata["picture"] = picture }
        if let nip05 = nip05 { metadata["nip05"] = nip05 }
        if let banner = banner { metadata["banner"] = banner }
        if let website = website { metadata["website"] = website }
        if let lud06 = lud06 { metadata["lud06"] = lud06 }
        if let lud16 = lud16 { metadata["lud16"] = lud16 }
        
        let content = try! String(data: JSONSerialization.data(withJSONObject: metadata), encoding: .utf8)!
        return EventBuilder(kind: 0, content: content)
    }
    
    /// Creates a contact list event (kind 3)
    /// - Parameter contacts: Array of public keys to follow
    /// - Returns: An EventBuilder configured for a contact list
    public static func contactList(_ contacts: [String] = []) -> EventBuilder {
        var builder = EventBuilder(kind: 3)
        for contact in contacts {
            builder = builder.contact(pubkey: contact)
        }
        return builder
    }
    
    /// Creates a deletion event (kind 5)
    /// - Parameter eventIds: IDs of events to delete
    /// - Returns: An EventBuilder configured for deletion
    public static func deletion(_ eventIds: [String]) -> EventBuilder {
        var builder = EventBuilder(kind: 5, content: "Deleted")
        for eventId in eventIds {
            builder.tags.append(["e", eventId])
        }
        return builder
    }
    
    /// Creates a repost event (kind 6)
    /// - Parameters:
    ///   - eventId: The event ID to repost
    ///   - relay: Optional relay URL where the event was seen
    /// - Returns: An EventBuilder configured for a repost
    public static func repost(eventId: String, relay: String? = nil) -> EventBuilder {
        var builder = EventBuilder(kind: 6)
        var tag = ["e", eventId]
        if let relay = relay {
            tag.append(relay)
        }
        builder.tags.append(tag)
        return builder
    }
    
    /// Creates a reaction event (kind 7)
    /// - Parameters:
    ///   - eventId: The event ID to react to
    ///   - reaction: The reaction content (e.g., "+", "❤️")
    /// - Returns: An EventBuilder configured for a reaction
    public static func reaction(to eventId: String, reaction: String = "+") -> EventBuilder {
        var builder = EventBuilder(kind: 7, content: reaction)
        builder.tags.append(["e", eventId])
        return builder
    }
    
    /// Creates a long-form content event (kind 30023)
    /// - Parameters:
    ///   - identifier: Unique identifier for the article
    ///   - title: Article title
    ///   - content: Article content (markdown supported)
    ///   - summary: Optional article summary
    ///   - image: Optional header image URL
    ///   - publishedAt: Optional published timestamp
    /// - Returns: An EventBuilder configured for long-form content
    public static func article(
        identifier: String,
        title: String,
        content: String,
        summary: String? = nil,
        image: String? = nil,
        publishedAt: Date? = nil
    ) -> EventBuilder {
        var builder = EventBuilder(kind: 30023, content: content)
        builder.tags.append(["d", identifier])
        builder.tags.append(["title", title])
        
        if let summary = summary {
            builder.tags.append(["summary", summary])
        }
        if let image = image {
            builder.tags.append(["image", image])
        }
        if let publishedAt = publishedAt {
            builder.tags.append(["published_at", String(Int64(publishedAt.timeIntervalSince1970))])
        }
        
        return builder
    }
    
    /// Creates a channel creation event (kind 40)
    /// - Parameters:
    ///   - name: Channel name
    ///   - about: Channel description
    ///   - picture: Optional channel picture URL
    /// - Returns: An EventBuilder configured for channel creation
    public static func channel(name: String, about: String, picture: String? = nil) -> EventBuilder {
        var metadata: [String: String] = [
            "name": name,
            "about": about
        ]
        if let picture = picture {
            metadata["picture"] = picture
        }
        
        let content = try! String(data: JSONSerialization.data(withJSONObject: metadata), encoding: .utf8)!
        return EventBuilder(kind: 40, content: content)
    }
    
    /// Creates a channel message event (kind 42)
    /// - Parameters:
    ///   - channelId: The channel event ID
    ///   - message: The message content
    ///   - replyTo: Optional message ID to reply to
    /// - Returns: An EventBuilder configured for a channel message
    public static func channelMessage(in channelId: String, message: String, replyTo: String? = nil) -> EventBuilder {
        var builder = EventBuilder(kind: 42, content: message)
        builder.tags.append(["e", channelId, "", "root"])
        
        if let replyTo = replyTo {
            builder.tags.append(["e", replyTo, "", "reply"])
        }
        
        return builder
    }
    
    // MARK: - Builder Methods
    
    /// Sets a custom timestamp for the event
    /// - Parameter date: The timestamp to use
    /// - Returns: The builder for chaining
    public func timestamp(_ date: Date) -> EventBuilder {
        var builder = self
        builder.createdAt = date
        return builder
    }
    
    /// Adds a reply to an event
    /// - Parameters:
    ///   - eventId: The event ID to reply to
    ///   - relay: Optional relay URL
    /// - Returns: The builder for chaining
    public func reply(to eventId: String, relay: String? = nil) -> EventBuilder {
        var builder = self
        var tag = ["e", eventId]
        if let relay = relay {
            tag.append(relay)
            tag.append("reply")
        } else {
            // When no relay is specified, add empty string for relay position
            tag.append("")
            tag.append("reply")
        }
        builder.tags.append(tag)
        return builder
    }
    
    /// Adds a root event reference
    /// - Parameters:
    ///   - eventId: The root event ID
    ///   - relay: Optional relay URL
    /// - Returns: The builder for chaining
    public func root(_ eventId: String, relay: String? = nil) -> EventBuilder {
        var builder = self
        var tag = ["e", eventId]
        if let relay = relay {
            tag.append(relay)
            tag.append("root")
        } else {
            // When no relay is specified, add empty string for relay position
            tag.append("")
            tag.append("root")
        }
        builder.tags.append(tag)
        return builder
    }
    
    /// Mentions a user
    /// - Parameters:
    ///   - pubkey: The public key to mention
    ///   - relay: Optional relay URL
    /// - Returns: The builder for chaining
    public func mention(pubkey: String, relay: String? = nil) -> EventBuilder {
        var builder = self
        var tag = ["p", pubkey]
        if let relay = relay {
            tag.append(relay)
        }
        builder.tags.append(tag)
        return builder
    }
    
    /// Adds a contact to a contact list
    /// - Parameters:
    ///   - pubkey: The public key to add
    ///   - relay: Optional relay URL
    ///   - petname: Optional pet name
    /// - Returns: The builder for chaining
    public func contact(pubkey: String, relay: String? = nil, petname: String? = nil) -> EventBuilder {
        var builder = self
        var tag = ["p", pubkey]
        if let relay = relay {
            tag.append(relay)
        }
        if let petname = petname {
            tag.append(petname)
        }
        builder.tags.append(tag)
        return builder
    }
    
    /// Adds a hashtag
    /// - Parameter tag: The hashtag (without #)
    /// - Returns: The builder for chaining
    public func hashtag(_ tag: String) -> EventBuilder {
        var builder = self
        let cleanTag = tag.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        builder.tags.append(["t", cleanTag])
        return builder
    }
    
    /// Adds multiple hashtags
    /// - Parameter tags: Array of hashtags
    /// - Returns: The builder for chaining
    public func hashtags(_ tags: [String]) -> EventBuilder {
        var builder = self
        for tag in tags {
            builder = builder.hashtag(tag)
        }
        return builder
    }
    
    /// Adds a reference URL
    /// - Parameter url: The URL to reference
    /// - Returns: The builder for chaining
    public func reference(_ url: String) -> EventBuilder {
        var builder = self
        builder.tags.append(["r", url])
        return builder
    }
    
    /// Adds a subject/title tag
    /// - Parameter subject: The subject text
    /// - Returns: The builder for chaining
    public func subject(_ subject: String) -> EventBuilder {
        var builder = self
        builder.tags.append(["subject", subject])
        return builder
    }
    
    /// Adds a content warning
    /// - Parameter warning: The warning text
    /// - Returns: The builder for chaining
    public func contentWarning(_ warning: String) -> EventBuilder {
        var builder = self
        builder.tags.append(["content-warning", warning])
        return builder
    }
    
    /// Adds an expiration timestamp
    /// - Parameter date: When the event should expire
    /// - Returns: The builder for chaining
    public func expiration(_ date: Date) -> EventBuilder {
        var builder = self
        let timestamp = String(Int64(date.timeIntervalSince1970))
        builder.tags.append(["expiration", timestamp])
        return builder
    }
    
    /// Adds a custom tag
    /// - Parameter tag: The tag array to add
    /// - Returns: The builder for chaining
    public func tag(_ tag: [String]) -> EventBuilder {
        var builder = self
        builder.tags.append(tag)
        return builder
    }
    
    /// Adds multiple custom tags
    /// - Parameter tags: Array of tags to add
    /// - Returns: The builder for chaining
    public func tags(_ tags: [[String]]) -> EventBuilder {
        var builder = self
        builder.tags.append(contentsOf: tags)
        return builder
    }
    
    /// Sets the content (replaces existing content)
    /// - Parameter content: The new content
    /// - Returns: The builder for chaining
    public func content(_ content: String) -> EventBuilder {
        var builder = self
        builder.content = content
        return builder
    }
    
    /// Appends to the content
    /// - Parameter text: Text to append
    /// - Returns: The builder for chaining
    public func appendContent(_ text: String) -> EventBuilder {
        var builder = self
        builder.content += text
        return builder
    }
    
    // MARK: - Building
    
    /// Builds and signs the event
    /// - Parameter keyPair: The key pair to sign with
    /// - Returns: The signed NostrEvent
    /// - Throws: NostrError if building or signing fails
    public func build(with keyPair: KeyPair) throws -> NostrEvent {
        // Create the unsigned event
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: createdAt ?? Date(),
            kind: kind,
            tags: tags,
            content: content
        )
        
        // Validate the event
        try Validation.validateNostrEvent(event)
        
        // Sign and return
        return try keyPair.signEvent(event)
    }
    
    /// Builds an unsigned event (for preview/validation)
    /// - Parameter pubkey: The public key to use
    /// - Returns: The unsigned NostrEvent
    /// - Throws: NostrError if validation fails
    public func buildUnsigned(pubkey: String) throws -> NostrEvent {
        let event = NostrEvent(
            pubkey: pubkey,
            createdAt: createdAt ?? Date(),
            kind: kind,
            tags: tags,
            content: content
        )
        
        // Validate the event
        try Validation.validateNostrEvent(event)
        
        return event
    }
}

// MARK: - Convenience Extensions

public extension EventBuilder {
    
    /// Creates a text note with mentions and hashtags extracted from content
    /// - Parameter text: The text content with @mentions and #hashtags
    /// - Returns: An EventBuilder with extracted mentions and tags
    static func smartText(_ text: String) -> EventBuilder {
        var builder = EventBuilder.text(text)
        
        // Extract hashtags
        let hashtagPattern = #"#(\w+)"#
        if let regex = try? NSRegularExpression(pattern: hashtagPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let tag = String(text[range])
                    builder = builder.hashtag(tag)
                }
            }
        }
        
        // Note: Extracting @mentions would require a way to resolve names to pubkeys
        // This would typically be done at a higher level with access to a contact list
        
        return builder
    }
    
    /// Creates a thread of replies
    /// - Parameters:
    ///   - rootId: The root event ID
    ///   - replyTo: The immediate parent event ID
    ///   - content: The reply content
    /// - Returns: An EventBuilder configured for a threaded reply
    static func threadedReply(root rootId: String, replyTo: String, content: String) -> EventBuilder {
        return EventBuilder.text(content)
            .root(rootId)
            .reply(to: replyTo)
    }
}