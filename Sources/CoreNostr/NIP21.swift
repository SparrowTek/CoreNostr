import Foundation

/// NIP-21: nostr: URI scheme
/// https://github.com/nostr-protocol/nips/blob/master/21.md
///
/// NostrURI provides a standard way to create shareable links to NOSTR content.
/// These URIs can be used in web browsers, QR codes, and other applications
/// to reference profiles, events, and other NOSTR entities.
///
/// ## URI Format
/// - `nostr:npub1...` - Links to a profile
/// - `nostr:note1...` - Links to an event
/// - `nostr:nevent1...` - Links to an event with metadata
/// - `nostr:nprofile1...` - Links to a profile with relay hints
/// - `nostr:naddr1...` - Links to a replaceable event
/// - `nostr:nrelay1...` - Links to a relay
///
/// ## Example Usage
/// ```swift
/// // Parse a URI
/// if let uri = NostrURI(from: "nostr:npub1...") {
///     print(uri.uriString) // "nostr:npub1..."
/// }
///
/// // Create a URI from a public key
/// if let uri = NostrURIBuilder.fromPublicKey(pubkey) {
///     shareLink(uri.uriString)
/// }
/// ```
public enum NostrURI: Sendable, Equatable {
    case profile(String)     // nostr:npub1...
    case event(String)       // nostr:note1...
    case relay(String)       // nostr:nrelay1...
    case pubkey(String)      // nostr:nprofile1...
    case eventId(String)     // nostr:nevent1...
    case addr(String)        // nostr:naddr1...
    
    /// Creates a NostrURI by parsing a string.
    ///
    /// This initializer accepts various URI formats:
    /// - With prefix: `nostr:npub1...`
    /// - Without prefix: `npub1...`
    /// - Web format: `web+nostr:npub1...`
    /// - URL format: `nostr://npub1...`
    ///
    /// - Parameter string: The URI string to parse
    /// - Returns: A NostrURI if parsing succeeds, nil otherwise
    /// - Note: Private keys (nsec) are explicitly rejected for security
    public init?(from string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove nostr: prefix if present
        let content: String
        if trimmed.hasPrefix("nostr:") {
            content = String(trimmed.dropFirst(6))
        } else if trimmed.hasPrefix("web+nostr:") {
            content = String(trimmed.dropFirst(10))
        } else if trimmed.hasPrefix("nostr://") {
            content = String(trimmed.dropFirst(8))
        } else {
            content = trimmed
        }
        
        // Try to decode as bech32 entity
        if let entity = try? Bech32Entity(from: content) {
            switch entity {
            case .npub(_):
                self = .profile(content)
            case .note(_):
                self = .event(content)
            case .nrelay(_):
                self = .relay(content)
            case .nprofile(_):
                self = .pubkey(content)
            case .nevent(_):
                self = .eventId(content)
            case .naddr(_):
                self = .addr(content)
            case .nsec(_):
                // nsec should not be shared in URIs
                return nil
            }
        } else {
            // Not a valid bech32 entity
            return nil
        }
    }
    
    /// The standard nostr: URI string representation.
    ///
    /// ## Example
    /// ```swift
    /// let uri = NostrURI.profile("npub1...")
    /// print(uri.uriString) // "nostr:npub1..."
    /// ```
    public var uriString: String {
        switch self {
        case .profile(let bech32),
             .event(let bech32),
             .relay(let bech32),
             .pubkey(let bech32),
             .eventId(let bech32),
             .addr(let bech32):
            return "nostr:\(bech32)"
        }
    }
    
    /// The raw bech32 string without the nostr: prefix.
    ///
    /// Use this when you need just the bech32 identifier without
    /// the URI scheme prefix.
    ///
    /// ## Example
    /// ```swift
    /// let uri = NostrURI.profile("npub1...")
    /// print(uri.bech32String) // "npub1..."
    /// ```
    public var bech32String: String {
        switch self {
        case .profile(let bech32),
             .event(let bech32),
             .relay(let bech32),
             .pubkey(let bech32),
             .eventId(let bech32),
             .addr(let bech32):
            return bech32
        }
    }
    
    /// Attempts to decode the underlying bech32 entity.
    ///
    /// This provides access to the full entity data, including
    /// any metadata like relay hints or event kinds.
    ///
    /// ## Example
    /// ```swift
    /// if let entity = uri.entity {
    ///     switch entity {
    ///     case .npub(let pubkey):
    ///         print("Public key: \(pubkey)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    public var entity: Bech32Entity? {
        try? Bech32Entity(from: bech32String)
    }
    
    /// The web-compatible URI format using web+nostr: scheme.
    ///
    /// This format is useful for web applications that need to
    /// register protocol handlers for nostr: links.
    ///
    /// ## Example
    /// ```swift
    /// let uri = NostrURI.profile("npub1...")
    /// print(uri.webUriString) // "web+nostr:npub1..."
    /// ```
    public var webUriString: String {
        switch self {
        case .profile(let bech32),
             .event(let bech32),
             .relay(let bech32),
             .pubkey(let bech32),
             .eventId(let bech32),
             .addr(let bech32):
            return "web+nostr:\(bech32)"
        }
    }
}

/// Builder for creating NostrURI instances from various NOSTR entities.
///
/// NostrURIBuilder provides convenience methods for creating URIs
/// from public keys, event IDs, and other NOSTR identifiers without
/// manually encoding to bech32 format.
///
/// ## Example
/// ```swift
/// let pubkey = "abc123..."
/// if let uri = NostrURIBuilder.fromPublicKey(pubkey) {
///     shareLink(uri.uriString)
/// }
/// ```
public struct NostrURIBuilder: Sendable {
    /// Creates a nostr: URI for a public key.
    ///
    /// Encodes the public key as npub and creates a profile URI.
    ///
    /// - Parameter publicKey: The public key in hex format
    /// - Returns: A NostrURI for the profile, or nil if encoding fails
    public static func fromPublicKey(_ publicKey: PublicKey) -> NostrURI? {
        guard let npub = try? publicKey.npub else { return nil }
        return NostrURI.profile(npub)
    }
    
    /// Creates a nostr: URI for an event ID.
    ///
    /// Encodes the event ID as note and creates an event URI.
    ///
    /// - Parameter eventId: The event ID in hex format
    /// - Returns: A NostrURI for the event, or nil if encoding fails
    public static func fromEventID(_ eventId: EventID) -> NostrURI? {
        guard let note = try? eventId.note else { return nil }
        return NostrURI.event(note)
    }
}

public extension NProfile {
    /// Creates a nostr: URI for this profile with relay hints.
    ///
    /// The resulting URI includes the profile's public key and
    /// relay URLs, helping clients find the user's content.
    ///
    /// ## Example
    /// ```swift
    /// let profile = try NProfile(pubkey: "...", relays: ["wss://relay.com"])
    /// if let uri = profile.nostrURI {
    ///     print(uri.uriString) // "nostr:nprofile1..."
    /// }
    /// ```
    var nostrURI: NostrURI? {
        guard let nprofile = try? Bech32Entity.nprofile(self).encoded else { return nil }
        return NostrURI.pubkey(nprofile)
    }
}

public extension NEvent {
    /// Creates a nostr: URI for this event with metadata.
    ///
    /// The resulting URI includes the event ID and optional metadata
    /// like relay hints, author, and event kind.
    ///
    /// ## Example
    /// ```swift
    /// let event = try NEvent(eventId: "...", relays: ["wss://relay.com"])
    /// if let uri = event.nostrURI {
    ///     print(uri.uriString) // "nostr:nevent1..."
    /// }
    /// ```
    var nostrURI: NostrURI? {
        guard let nevent = try? Bech32Entity.nevent(self).encoded else { return nil }
        return NostrURI.eventId(nevent)
    }
}

public extension NAddr {
    /// Creates a nostr: URI for this replaceable event address.
    ///
    /// The resulting URI includes the event coordinates (identifier,
    /// pubkey, kind) and optional relay hints.
    ///
    /// ## Example
    /// ```swift
    /// let addr = try NAddr(identifier: "article", pubkey: "...", kind: 30023)
    /// if let uri = addr.nostrURI {
    ///     print(uri.uriString) // "nostr:naddr1..."
    /// }
    /// ```
    var nostrURI: NostrURI? {
        guard let naddr = try? Bech32Entity.naddr(self).encoded else { return nil }
        return NostrURI.addr(naddr)
    }
}

// MARK: - String Extension

public extension String {
    /// Attempts to parse this string as a nostr: URI.
    ///
    /// This is a convenience method equivalent to `NostrURI(from:)`.
    ///
    /// ## Example
    /// ```swift
    /// if let uri = "nostr:npub1...".parseNostrURI() {
    ///     print("Valid URI: \(uri.uriString)")
    /// }
    /// ```
    ///
    /// - Returns: A NostrURI if parsing succeeds, nil otherwise
    func parseNostrURI() -> NostrURI? {
        NostrURI(from: self)
    }
}