//
//  NostrError.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// Errors that can occur when working with NOSTR events and networking.
public enum NostrError: Error, LocalizedError, Sendable {
    /// An event failed validation or contains invalid data
    case invalidEvent(String)
    
    /// A cryptographic operation failed
    case cryptographyError(String)
    
    /// A network operation failed
    case networkError(String)
    
    /// JSON serialization or deserialization failed
    case serializationError(String)
    
    /// Localized description of the error.
    public var errorDescription: String? {
        switch self {
        case .invalidEvent(let message):
            return "Invalid event: \(message)"
        case .cryptographyError(let message):
            return "Cryptography error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serializationError(let message):
            return "Serialization error: \(message)"
        }
    }
}
