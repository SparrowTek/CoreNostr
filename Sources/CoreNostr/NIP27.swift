//
//  NIP27.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// NIP-27: Text Note References
/// https://github.com/nostr-protocol/nips/blob/master/27.md
///
/// Defines how to reference events and profiles within text content
/// using nostr: URIs.

// MARK: - Reference Types

/// A reference found within text content
public struct NostrReference: Sendable, Equatable {
    /// The type of reference
    public enum ReferenceType: Sendable, Equatable {
        /// Reference to a profile
        case profile(pubkey: String, relays: [String])
        
        /// Reference to an event
        case event(id: String, relays: [String], author: String?)
        
        /// Reference to a parameterized replaceable event
        case address(identifier: String, pubkey: String, kind: Int, relays: [String])
    }
    
    /// The reference type
    public let type: ReferenceType
    
    /// The original nostr: URI string
    public let uri: String
    
    /// Initialize from a nostr: URI string
    public init?(uri: String) {
        guard let nostrURI = NostrURI(from: uri),
              let entity = nostrURI.entity else {
            return nil
        }
        
        self.uri = nostrURI.uriString
        
        switch entity {
        case .npub(let pubkey):
            self.type = .profile(pubkey: pubkey, relays: [])
        case .nprofile(let profile):
            self.type = .profile(pubkey: profile.pubkey, relays: profile.relays)
        case .note(let eventId):
            self.type = .event(id: eventId, relays: [], author: nil)
        case .nevent(let event):
            self.type = .event(id: event.eventId, relays: event.relays ?? [], author: event.author)
        case .naddr(let addr):
            self.type = .address(
                identifier: addr.identifier,
                pubkey: addr.pubkey,
                kind: addr.kind,
                relays: addr.relays ?? []
            )
        case .nsec, .nrelay:
            return nil
        }
    }
    
    /// Create appropriate tags for this reference
    public func toTags() -> [[String]] {
        switch type {
        case .profile(let pubkey, _):
            return [["p", pubkey]]
        case .event(let id, _, _):
            return [["e", id]]
        case .address(let identifier, let pubkey, let kind, _):
            return [["a", "\(kind):\(pubkey):\(identifier)"]]
        }
    }
}

// MARK: - Text Processing

/// Utilities for processing text with nostr: references
public struct NostrTextProcessor {
    /// Regular expression to find nostr: URIs in text
    private static let nostrURIPattern = #"nostr:(npub|nsec|note|nprofile|nevent|nrelay|naddr)1[023456789acdefghjklmnpqrstuvwxyz]+"#
    
    /// Find all nostr: references in text
    public static func findReferences(in text: String) -> [(reference: NostrReference, range: Range<String.Index>)] {
        guard let regex = try? NSRegularExpression(pattern: nostrURIPattern, options: []) else {
            return []
        }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        
        var references: [(NostrReference, Range<String.Index>)] = []
        
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let uri = String(text[range])
            
            if let reference = NostrReference(uri: uri) {
                references.append((reference, range))
            }
        }
        
        return references
    }
    
    /// Extract all profile references from text
    public static func extractProfileReferences(from text: String) -> [(pubkey: String, relays: [String])] {
        findReferences(in: text).compactMap { ref, _ in
            if case .profile(let pubkey, let relays) = ref.type {
                return (pubkey, relays)
            }
            return nil
        }
    }
    
    /// Extract all event references from text
    public static func extractEventReferences(from text: String) -> [(id: String, relays: [String], author: String?)] {
        findReferences(in: text).compactMap { ref, _ in
            if case .event(let id, let relays, let author) = ref.type {
                return (id, relays, author)
            }
            return nil
        }
    }
    
    /// Replace profile mentions (@username) with nostr: URIs
    /// This is a helper for clients implementing autocomplete
    public static func replaceMention(
        in text: String,
        mention: String,
        with profile: NProfile
    ) -> String? {
        guard let uri = profile.nostrURI?.uriString else { return nil }
        return text.replacingOccurrences(of: mention, with: uri)
    }
    
    /// Create tags from all references in text
    public static func createTags(from text: String) -> [[String]] {
        let references = findReferences(in: text)
        return references.flatMap { $0.reference.toTags() }
    }
}

// MARK: - Event Extensions

public extension NostrEvent {
    /// Extract all nostr: references from the event content
    var contentReferences: [(reference: NostrReference, range: Range<String.Index>)] {
        NostrTextProcessor.findReferences(in: content)
    }
    
    /// Get all profile references from content
    var profileReferences: [(pubkey: String, relays: [String])] {
        NostrTextProcessor.extractProfileReferences(from: content)
    }
    
    /// Get all event references from content
    var eventReferences: [(id: String, relays: [String], author: String?)] {
        NostrTextProcessor.extractEventReferences(from: content)
    }
    
    /// Check if the event content contains a reference to a specific profile
    func mentionsProfile(_ pubkey: String) -> Bool {
        profileReferences.contains { $0.pubkey == pubkey }
    }
    
    /// Check if the event content contains a reference to a specific event
    func referencesEvent(_ eventId: String) -> Bool {
        eventReferences.contains { $0.id == eventId }
    }
}

// MARK: - Mention Builder

/// Helper for building events with mentions
public struct MentionBuilder {
    private var content: String
    private var tags: [[String]]
    
    public init(content: String = "") {
        self.content = content
        self.tags = []
    }
    
    /// Add a profile mention
    public mutating func addProfileMention(_ profile: NProfile, displayName: String? = nil) {
        guard let uri = profile.nostrURI?.uriString else { return }
        
        // Add to content
        if let displayName = displayName {
            content += " \(displayName) (\(uri))"
        } else {
            content += " \(uri)"
        }
        
        // Add p tag
        tags.append(["p", profile.pubkey])
    }
    
    /// Add an event reference
    public mutating func addEventReference(_ event: NEvent, label: String? = nil) {
        guard let uri = event.nostrURI?.uriString else { return }
        
        // Add to content
        if let label = label {
            content += " \(label): \(uri)"
        } else {
            content += " \(uri)"
        }
        
        // Add e tag
        tags.append(["e", event.eventId])
    }
    
    /// Build the final content and tags
    public func build() -> (content: String, tags: [[String]]) {
        // Also extract any references that were manually added to content
        let additionalTags = NostrTextProcessor.createTags(from: content)
        let allTags = tags + additionalTags.filter { newTag in
            !tags.contains { existingTag in
                existingTag.count >= 2 && newTag.count >= 2 && 
                existingTag[0] == newTag[0] && existingTag[1] == newTag[1]
            }
        }
        
        return (content.trimmingCharacters(in: .whitespacesAndNewlines), allTags)
    }
}

// MARK: - Convenience Extensions

public extension String {
    /// Find all nostr: references in this string
    var nostrReferences: [(reference: NostrReference, range: Range<String.Index>)] {
        NostrTextProcessor.findReferences(in: self)
    }
    
    /// Check if this string contains any nostr: references
    var containsNostrReferences: Bool {
        !nostrReferences.isEmpty
    }
}

public extension NostrReference {
    /// Parse all references from text
    static func parseFromText(_ text: String) -> [NostrReference] {
        NostrTextProcessor.findReferences(in: text).map { $0.reference }
    }
}

// MARK: - CoreNostr Extensions

public extension CoreNostr {
    /// Create a text note with mentions
    static func createTextNoteWithMentions(
        content: String,
        additionalTags: [[String]] = [],
        keyPair: KeyPair
    ) throws -> NostrEvent {
        // Extract tags from content references
        let referenceTags = NostrTextProcessor.createTags(from: content)
        let allTags = referenceTags + additionalTags
        
        return try createEvent(
            keyPair: keyPair,
            kind: .textNote,
            content: content,
            tags: allTags
        )
    }
}