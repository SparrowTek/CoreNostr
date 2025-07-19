import Foundation

/// NIP-21: nostr: URI scheme
/// https://github.com/nostr-protocol/nips/blob/master/21.md
public enum NostrURI: Sendable, Equatable {
    case profile(String)     // nostr:npub1...
    case event(String)       // nostr:note1...
    case relay(String)       // nostr:nrelay1...
    case pubkey(String)      // nostr:nprofile1...
    case eventId(String)     // nostr:nevent1...
    case addr(String)        // nostr:naddr1...
    
    /// Parse from a string (with or without the nostr: prefix)
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
    
    /// Get the URI string representation
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
    
    /// Get the raw bech32 string without the nostr: prefix
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
    
    /// Try to decode the underlying entity
    public var entity: Bech32Entity? {
        try? Bech32Entity(from: bech32String)
    }
    
    /// Get a web+nostr: URL for web compatibility
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

/// Convenience functions for creating URIs
public struct NostrURIBuilder {
    /// Create a nostr: URI for a public key
    public static func fromPublicKey(_ publicKey: PublicKey) -> NostrURI? {
        guard let npub = try? publicKey.npub else { return nil }
        return NostrURI.profile(npub)
    }
    
    /// Create a nostr: URI for an event ID
    public static func fromEventID(_ eventId: EventID) -> NostrURI? {
        guard let note = try? eventId.note else { return nil }
        return NostrURI.event(note)
    }
}

public extension NProfile {
    /// Create a nostr: URI for this profile
    var nostrURI: NostrURI? {
        guard let nprofile = try? Bech32Entity.nprofile(self).encoded else { return nil }
        return NostrURI.pubkey(nprofile)
    }
}

public extension NEvent {
    /// Create a nostr: URI for this event
    var nostrURI: NostrURI? {
        guard let nevent = try? Bech32Entity.nevent(self).encoded else { return nil }
        return NostrURI.eventId(nevent)
    }
}

public extension NAddr {
    /// Create a nostr: URI for this address
    var nostrURI: NostrURI? {
        guard let naddr = try? Bech32Entity.naddr(self).encoded else { return nil }
        return NostrURI.addr(naddr)
    }
}

/// String extension for URI parsing
public extension String {
    /// Try to parse as a nostr: URI
    func parseNostrURI() -> NostrURI? {
        NostrURI(from: self)
    }
}