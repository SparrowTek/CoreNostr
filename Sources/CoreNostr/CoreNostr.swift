import Foundation

// MARK: - CoreNostr Public API
public struct CoreNostr {
    public static let version = "1.0.0"
    
    public static func createKeyPair() throws -> KeyPair {
        return try KeyPair.generate()
    }
    
    public static func createEvent(
        keyPair: KeyPair,
        kind: EventKind,
        content: String,
        tags: [[String]] = []
    ) throws -> NostrEvent {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: kind.rawValue,
            tags: tags,
            content: content
        )
        return try keyPair.signEvent(event)
    }
    
    public static func verifyEvent(_ event: NostrEvent) throws -> Bool {
        return try KeyPair.verifyEvent(event)
    }
    
    public static func createTextNote(
        keyPair: KeyPair,
        content: String,
        replyTo: EventID? = nil,
        mentionedUsers: [PublicKey] = []
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        if let replyTo = replyTo {
            tags.append(["e", replyTo])
        }
        
        for user in mentionedUsers {
            tags.append(["p", user])
        }
        
        return try createEvent(
            keyPair: keyPair,
            kind: .textNote,
            content: content,
            tags: tags
        )
    }
    
    public static func createMetadataEvent(
        keyPair: KeyPair,
        name: String?,
        about: String?,
        picture: String?,
        nip05: String? = nil,
        lud06: String? = nil,
        lud16: String? = nil
    ) throws -> NostrEvent {
        var metadata: [String: Any] = [:]
        
        if let name = name { metadata["name"] = name }
        if let about = about { metadata["about"] = about }
        if let picture = picture { metadata["picture"] = picture }
        if let nip05 = nip05 { metadata["nip05"] = nip05 }
        if let lud06 = lud06 { metadata["lud06"] = lud06 }
        if let lud16 = lud16 { metadata["lud16"] = lud16 }
        
        let jsonData = try JSONSerialization.data(withJSONObject: metadata)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NostrError.serializationError("Failed to serialize metadata")
        }
        
        return try createEvent(
            keyPair: keyPair,
            kind: .setMetadata,
            content: jsonString
        )
    }
}

// MARK: - Convenience Extensions
extension NostrEvent {
    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(createdAt))
    }
    
    public var eventKind: EventKind? {
        return EventKind(rawValue: kind)
    }
    
    public var isTextNote: Bool {
        return kind == EventKind.textNote.rawValue
    }
    
    public var isMetadata: Bool {
        return kind == EventKind.setMetadata.rawValue
    }
    
    public var referencedEvents: [EventID] {
        return tags.compactMap { tag in
            guard tag.count >= 2 && tag[0] == "e" else { return nil }
            return tag[1]
        }
    }
    
    public var mentionedUsers: [PublicKey] {
        return tags.compactMap { tag in
            guard tag.count >= 2 && tag[0] == "p" else { return nil }
            return tag[1]
        }
    }
}

extension Filter {
    public static func textNotes(
        authors: [PublicKey]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.textNote.rawValue],
            since: since,
            until: until,
            limit: limit
        )
    }
    
    public static func metadata(
        authors: [PublicKey]? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.setMetadata.rawValue],
            limit: limit
        )
    }
    
    public static func replies(
        to eventId: EventID,
        since: Date? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            kinds: [EventKind.textNote.rawValue],
            since: since,
            limit: limit,
            e: [eventId]
        )
    }
}
