//
//  Validation.swift
//  CoreNostr
//
//  Validation helpers for Nostr protocol entities
//

import Foundation

/// Validation utilities for Nostr protocol entities
public enum Validation {
    
    // MARK: - Public Key Validation
    
    /// Validates a public key format.
    ///
    /// - Parameter publicKey: The public key to validate
    /// - Returns: True if the public key is valid
    public static func isValidPublicKey(_ publicKey: String) -> Bool {
        // Public keys should be 64 hex characters (32 bytes)
        guard publicKey.count == 64 else { return false }
        return publicKey.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates a public key format, throwing if invalid.
    ///
    /// - Parameter publicKey: The public key to validate
    /// - Throws: NostrError if the public key is invalid
    public static func validatePublicKey(_ publicKey: String) throws {
        guard isValidPublicKey(publicKey) else {
            throw NostrError.invalidPublicKey(reason: "Must be 64 hexadecimal characters, got \(publicKey.count)")
        }
    }
    
    // MARK: - Private Key Validation
    
    /// Validates a private key format.
    ///
    /// - Parameter privateKey: The private key to validate
    /// - Returns: True if the private key is valid
    public static func isValidPrivateKey(_ privateKey: String) -> Bool {
        // Private keys should be 64 hex characters (32 bytes)
        guard privateKey.count == 64 else { return false }
        return privateKey.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates a private key format, throwing if invalid.
    ///
    /// - Parameter privateKey: The private key to validate
    /// - Throws: NostrError if the private key is invalid
    public static func validatePrivateKey(_ privateKey: String) throws {
        guard isValidPrivateKey(privateKey) else {
            throw NostrError.invalidPrivateKey(reason: "Must be 64 hexadecimal characters, got \(privateKey.count)")
        }
    }
    
    // MARK: - Event ID Validation
    
    /// Validates an event ID format.
    ///
    /// - Parameter eventId: The event ID to validate
    /// - Returns: True if the event ID is valid
    public static func isValidEventId(_ eventId: String) -> Bool {
        // Event IDs should be 64 hex characters (32 bytes SHA-256)
        guard eventId.count == 64 else { return false }
        return eventId.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates an event ID format, throwing if invalid.
    ///
    /// - Parameter eventId: The event ID to validate
    /// - Throws: NostrError if the event ID is invalid
    public static func validateEventId(_ eventId: String) throws {
        guard isValidEventId(eventId) else {
            throw NostrError.validationError(field: "eventId", reason: "Must be 64 hexadecimal characters, got \(eventId.count)")
        }
    }
    
    // MARK: - Signature Validation
    
    /// Validates a signature format.
    ///
    /// - Parameter signature: The signature to validate
    /// - Returns: True if the signature is valid
    public static func isValidSignature(_ signature: String) -> Bool {
        // Signatures should be 128 hex characters (64 bytes)
        guard signature.count == 128 else { return false }
        return signature.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates a signature format, throwing if invalid.
    ///
    /// - Parameter signature: The signature to validate
    /// - Throws: NostrError if the signature is invalid
    public static func validateSignature(_ signature: String) throws {
        guard isValidSignature(signature) else {
            throw NostrError.validationError(field: "signature", reason: "Must be 128 hexadecimal characters, got \(signature.count)")
        }
    }
    
    // MARK: - Tag Validation
    
    /// Safely accesses a tag value at the specified index.
    ///
    /// - Parameters:
    ///   - tag: The tag array
    ///   - index: The index to access
    /// - Returns: The value at the index, or nil if out of bounds
    public static func tagValue(from tag: [String], at index: Int) -> String? {
        guard index >= 0 && index < tag.count else { return nil }
        return tag[index]
    }
    
    /// Validates that a tag has the minimum required elements.
    ///
    /// - Parameters:
    ///   - tag: The tag to validate
    ///   - minimumCount: The minimum number of elements required
    /// - Returns: True if the tag has at least the minimum count
    public static func isValidTag(_ tag: [String], minimumCount: Int = 2) -> Bool {
        return tag.count >= minimumCount
    }
    
    /// Finds the first tag with the specified name and minimum element count.
    ///
    /// - Parameters:
    ///   - tags: The tags to search
    ///   - name: The tag name (first element)
    ///   - minimumCount: Minimum elements required
    /// - Returns: The first matching tag, or nil if not found
    public static func findTag(in tags: [[String]], name: String, minimumCount: Int = 2) -> [String]? {
        return tags.first { tag in
            tag.count >= minimumCount && tag[0] == name
        }
    }
    
    /// Validates tag schema based on event kind
    ///
    /// - Parameters:
    ///   - tags: The tags to validate
    ///   - kind: The event kind
    /// - Throws: NostrError if tags don't match expected schema
    public static func validateTagSchema(tags: [[String]], for kind: Int) throws {
        for tag in tags {
            guard !tag.isEmpty else {
                throw NostrError.invalidTag(tag: tag, reason: "Tag cannot be empty")
            }
            
            let tagName = tag[0]
            
            // Validate common tag types
            switch tagName {
            case "e": // Event reference
                guard tag.count >= 2 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Event tag 'e' requires at least event ID")
                }
                // Validate event ID format
                let eventId = tag[1]
                guard isValidEventId(eventId) else {
                    throw NostrError.invalidTag(tag: tag, reason: "Invalid event ID in 'e' tag: \(eventId)")
                }
                // Optional relay URL at index 2
                if tag.count > 2 && !tag[2].isEmpty {
                    try validateRelayURL(tag[2])
                }
                // Optional marker at index 3 (reply, root, mention)
                if tag.count > 3 {
                    let validMarkers = ["reply", "root", "mention"]
                    guard validMarkers.contains(tag[3]) else {
                        throw NostrError.invalidTag(tag: tag, reason: "Invalid marker '\(tag[3])' in 'e' tag")
                    }
                }
                
            case "p": // Pubkey reference
                guard tag.count >= 2 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Pubkey tag 'p' requires at least public key")
                }
                let pubkey = tag[1]
                guard isValidPublicKey(pubkey) else {
                    throw NostrError.invalidTag(tag: tag, reason: "Invalid public key in 'p' tag: \(pubkey)")
                }
                // Optional relay URL at index 2
                if tag.count > 2 && !tag[2].isEmpty {
                    try validateRelayURL(tag[2])
                }
                
            case "a": // Parameterized replaceable event reference
                guard tag.count >= 2 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Address tag 'a' requires coordinate")
                }
                // Format: kind:pubkey:d-tag
                let coordinate = tag[1]
                let parts = coordinate.split(separator: ":", maxSplits: 2)
                guard parts.count == 3 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Invalid coordinate format in 'a' tag")
                }
                
            case "d": // Identifier for parameterized replaceable events
                if kind >= 30000 && kind < 40000 {
                    guard tag.count >= 2 else {
                        throw NostrError.invalidTag(tag: tag, reason: "Identifier tag 'd' requires value for kind \(kind)")
                    }
                }
                
            case "r": // Reference/URL
                guard tag.count >= 2 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Reference tag 'r' requires URL")
                }
                
            case "t": // Hashtag
                guard tag.count >= 2 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Hashtag tag 't' requires value")
                }
                
            case "g": // Geohash
                guard tag.count >= 2 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Geohash tag 'g' requires value")
                }
                
            case "nonce": // Proof of work
                guard tag.count >= 3 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Nonce tag requires [nonce, commitment, difficulty]")
                }
                
            case "delegation": // Event delegation
                guard tag.count >= 4 else {
                    throw NostrError.invalidTag(tag: tag, reason: "Delegation tag requires [pubkey, conditions, sig]")
                }
                let delegatorPubkey = tag[1]
                guard isValidPublicKey(delegatorPubkey) else {
                    throw NostrError.invalidTag(tag: tag, reason: "Invalid delegator pubkey in delegation tag")
                }
                
            default:
                // Unknown tags are allowed per protocol
                break
            }
        }
        
        // Kind-specific validation
        switch kind {
        case 0: // Metadata
            // No specific tag requirements
            break
            
        case 1: // Text note
            // Can have e and p tags for replies/mentions
            break
            
        case 3: // Contact list
            // Should have p tags for contacts
            let hasPTags = tags.contains { $0.first == "p" }
            if tags.isEmpty || !hasPTags {
                // Warning: Contact list typically has p tags, but not required
            }
            
        case 4: // Encrypted DM
            // Must have exactly one p tag for recipient
            let pTags = tags.filter { $0.first == "p" }
            guard pTags.count == 1 else {
                throw NostrError.invalidTag(tag: [], reason: "Kind 4 must have exactly one 'p' tag for recipient")
            }
            
        case 30000...39999: // Parameterized replaceable
            // Must have a d tag
            let hasDTag = tags.contains { $0.first == "d" }
            guard hasDTag else {
                throw NostrError.invalidTag(tag: [], reason: "Parameterized replaceable events (kind \(kind)) must have a 'd' tag")
            }
            
        default:
            break
        }
    }
    
    // MARK: - Relay URL Validation
    
    /// Validates a relay URL format.
    ///
    /// - Parameter urlString: The URL string to validate
    /// - Returns: True if the URL is valid for a relay
    public static func isValidRelayURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "ws" || scheme == "wss"
    }
    
    /// Validates a relay URL format, throwing if invalid.
    ///
    /// - Parameter urlString: The URL string to validate
    /// - Throws: NostrError if the URL is invalid
    public static func validateRelayURL(_ urlString: String) throws {
        guard isValidRelayURL(urlString) else {
            throw NostrError.invalidURI(uri: urlString, reason: "Relay URL must use ws:// or wss:// scheme")
        }
    }
    
    // MARK: - Event Kind Validation
    
    /// Validates that an event kind is within the valid range.
    ///
    /// - Parameter kind: The event kind to validate
    /// - Returns: True if the kind is valid
    public static func isValidEventKind(_ kind: Int) -> Bool {
        // According to NIP-01, kinds 0-65535 are defined
        return kind >= 0 && kind <= 65535
    }
    
    /// Gets the event kind range type.
    ///
    /// - Parameter kind: The event kind
    /// - Returns: The range type
    public static func eventKindRange(_ kind: Int) -> EventKindRange {
        switch kind {
        case 0..<1000:
            return .regular
        case 1000..<10000:
            return .replaceable
        case 10000..<20000:
            return .ephemeral
        case 20000..<30000:
            return .parameterizedReplaceable
        case 30000..<40000:
            return .parameterizedReplaceable
        default:
            return .unknown
        }
    }
    
    /// Event kind range types
    public enum EventKindRange: Sendable {
        case regular
        case replaceable
        case ephemeral
        case parameterizedReplaceable
        case unknown
    }
    
    // MARK: - Content Validation
    
    /// Validates that content is within reasonable size limits.
    ///
    /// - Parameters:
    ///   - content: The content to validate
    ///   - maxSize: Maximum size in bytes (default: 256KB)
    /// - Returns: True if content is within limits
    public static func isValidContent(_ content: String, maxSize: Int = 256 * 1024) -> Bool {
        return content.utf8.count <= maxSize
    }
    
    /// Validates content size, throwing if too large.
    ///
    /// - Parameters:
    ///   - content: The content to validate
    ///   - maxSize: Maximum size in bytes
    /// - Throws: NostrError if content is too large
    public static func validateContent(_ content: String, maxSize: Int = 256 * 1024) throws {
        guard isValidContent(content, maxSize: maxSize) else {
            throw NostrError.invalidEvent(reason: .eventTooLarge)
        }
    }
    
    /// Validates content size (alias for validateContent).
    ///
    /// - Parameters:
    ///   - content: The content to validate
    ///   - maxSize: Maximum size in bytes
    /// - Throws: NostrError if content is too large
    public static func validateContentSize(_ content: String, maxSize: Int = 256 * 1024) throws {
        try validateContent(content, maxSize: maxSize)
    }
    
    // MARK: - Timestamp Validation
    
    /// Validates a timestamp is within acceptable range
    ///
    /// - Parameters:
    ///   - timestamp: Unix timestamp in seconds
    ///   - maxFutureSkew: Maximum seconds into the future (default: 900 = 15 minutes)
    ///   - maxPastSkew: Maximum seconds into the past (default: 31536000 = 1 year)
    /// - Returns: True if timestamp is valid
    public static func isValidTimestamp(_ timestamp: Int64, maxFutureSkew: TimeInterval = 900, maxPastSkew: TimeInterval = 31536000) -> Bool {
        let now = Date().timeIntervalSince1970
        let timestampInterval = TimeInterval(timestamp)
        
        // Check not too far in future
        if timestampInterval > now + maxFutureSkew {
            return false
        }
        
        // Check not too far in past
        if timestampInterval < now - maxPastSkew {
            return false
        }
        
        return true
    }
    
    /// Validates a timestamp, throwing if invalid
    ///
    /// - Parameters:
    ///   - timestamp: Unix timestamp in seconds
    ///   - maxFutureSkew: Maximum seconds into the future
    ///   - maxPastSkew: Maximum seconds into the past
    /// - Throws: NostrError if timestamp is invalid
    public static func validateTimestamp(_ timestamp: Int64, maxFutureSkew: TimeInterval = 900, maxPastSkew: TimeInterval = 31536000) throws {
        let now = Date().timeIntervalSince1970
        let timestampInterval = TimeInterval(timestamp)
        
        if timestampInterval > now + maxFutureSkew {
            throw NostrError.invalidTimestamp(reason: "Timestamp is too far in the future (more than \(Int(maxFutureSkew)) seconds)")
        }
        
        if timestampInterval < now - maxPastSkew {
            throw NostrError.invalidTimestamp(reason: "Timestamp is too far in the past (more than \(Int(maxPastSkew)) seconds)")
        }
    }
    
    // MARK: - Hex Validation
    
    /// Validates a hex string has the expected length
    ///
    /// - Parameters:
    ///   - hex: The hex string to validate
    ///   - expectedLength: Expected character count
    /// - Returns: True if valid
    public static func isValidHex(_ hex: String, length expectedLength: Int) -> Bool {
        guard hex.count == expectedLength else { return false }
        return hex.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates a hex string, throwing if invalid
    ///
    /// - Parameters:
    ///   - hex: The hex string to validate
    ///   - expectedLength: Expected character count
    ///   - field: Field name for error message
    /// - Throws: NostrError if invalid
    public static func validateHex(_ hex: String, length expectedLength: Int, field: String) throws {
        guard hex.count == expectedLength else {
            throw NostrError.invalidHex(hex: String(hex.prefix(20)) + "...", expectedLength: expectedLength)
        }
        guard hex.allSatisfy({ $0.isHexDigit }) else {
            throw NostrError.invalidHex(hex: String(hex.prefix(20)) + "...", expectedLength: expectedLength)
        }
    }
    
    // MARK: - Event Validation
    
    /// Validates a NostrEvent structure.
    ///
    /// - Parameter event: The event to validate
    /// - Throws: NostrError if validation fails
    public static func validateNostrEvent(_ event: NostrEvent) throws {
        // Validate pubkey
        try validatePublicKey(event.pubkey)
        
        // Validate event ID if present
        if !event.id.isEmpty {
            try validateEventId(event.id)
        }
        
        // Validate signature if present
        if !event.sig.isEmpty {
            try validateSignature(event.sig)
        }
        
        // Validate event kind
        guard isValidEventKind(event.kind) else {
            throw NostrError.unsupportedEventKind(kind: event.kind)
        }
        
        // Validate content size
        try validateContent(event.content)
        
        // Validate timestamp
        try validateTimestamp(event.createdAt)
        
        // Validate tag schema for the specific kind
        try validateTagSchema(tags: event.tags, for: event.kind)
    }
}

// MARK: - Character Extensions

extension Character {
    /// Whether this character is a valid hexadecimal digit
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safely accesses an element at the given index.
    ///
    /// - Parameter index: The index to access
    /// - Returns: The element if the index is valid, nil otherwise
    public subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

