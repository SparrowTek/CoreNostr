//
//  NostrError.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// Errors that can occur when working with NOSTR events and networking.
/// 
/// This enum provides comprehensive error cases for all operations in the NostrKit SDK,
/// with detailed error messages and recovery suggestions.
public enum NostrError: Error, LocalizedError, Sendable {
    
    // MARK: - Event Errors
    
    /// An event failed validation
    case invalidEvent(reason: EventError)
    
    /// Event signature verification failed
    case invalidSignature(eventId: String, reason: String)
    
    /// Event ID calculation failed or mismatched
    case invalidEventId(expected: String, actual: String)
    
    /// Event timestamp is invalid
    case invalidTimestamp(reason: String)
    
    /// Event kind is not supported
    case unsupportedEventKind(kind: Int)
    
    // MARK: - Cryptography Errors
    
    /// A cryptographic operation failed
    case cryptographyError(operation: CryptoOperation, reason: String)
    
    /// Invalid private key format or value
    case invalidPrivateKey(reason: String)
    
    /// Invalid public key format or value
    case invalidPublicKey(reason: String)
    
    /// Key derivation failed
    case keyDerivationFailed(path: String?, reason: String)
    
    /// Encryption or decryption failed
    case encryptionError(operation: EncryptionOperation, reason: String)
    
    // MARK: - Network Errors
    
    /// A network operation failed
    case networkError(operation: NetworkOperation, reason: String)
    
    /// WebSocket connection failed
    case connectionFailed(url: String, reason: String)
    
    /// Relay rejected the operation
    case relayError(relay: String, message: String)
    
    /// Request timed out
    case timeout(operation: String, duration: TimeInterval)
    
    // MARK: - Serialization Errors
    
    /// JSON serialization or deserialization failed
    case serializationError(type: String, reason: String)
    
    /// Invalid JSON structure
    case invalidJSON(json: String, reason: String)
    
    /// Missing required field in JSON
    case missingField(field: String, in: String)
    
    // MARK: - Format Errors
    
    /// Bech32 encoding or decoding failed
    case invalidBech32(entity: String, reason: String)
    
    /// Invalid NIP-05 identifier format
    case invalidNIP05(identifier: String, reason: String)
    
    /// Invalid hex string format
    case invalidHex(hex: String, expectedLength: Int?)
    
    /// Invalid URI format
    case invalidURI(uri: String, reason: String)
    
    // MARK: - Validation Errors
    
    /// Content validation failed
    case validationError(field: String, reason: String)
    
    /// Filter validation failed
    case invalidFilter(reason: String)
    
    /// Tag validation failed
    case invalidTag(tag: [String], reason: String)
    
    // MARK: - Protocol Errors
    
    /// NIP implementation error
    case nipError(nip: Int, reason: String)
    
    /// Protocol violation
    case protocolViolation(reason: String)
    
    /// Feature not implemented
    case notImplemented(feature: String)
    
    // MARK: - Resource Errors
    
    /// Resource not found
    case notFound(resource: String)
    
    /// Operation not permitted
    case notPermitted(operation: String, reason: String)
    
    /// Rate limit exceeded
    case rateLimited(limit: Int, resetTime: Date?)
    
    // MARK: - Supporting Types
    
    /// Specific event-related errors
    public enum EventError: String, Sendable {
        case missingId = "Event ID is missing"
        case missingSignature = "Event signature is missing"
        case invalidKind = "Event kind is invalid"
        case invalidContent = "Event content is invalid"
        case invalidTags = "Event tags are malformed"
        case eventTooLarge = "Event exceeds maximum size"
        case eventExpired = "Event has expired"
    }
    
    /// Cryptographic operations
    public enum CryptoOperation: String, Sendable {
        case signing = "signing"
        case verification = "verification"
        case keyGeneration = "key generation"
        case keyDerivation = "key derivation"
        case hashing = "hashing"
        case randomGeneration = "random number generation"
    }
    
    /// Encryption operations
    public enum EncryptionOperation: String, Sendable {
        case encrypt = "encryption"
        case decrypt = "decryption"
        case keyExchange = "key exchange"
    }
    
    /// Network operations
    public enum NetworkOperation: String, Sendable {
        case connect = "connection"
        case disconnect = "disconnection"
        case send = "sending"
        case receive = "receiving"
        case subscribe = "subscription"
        case unsubscribe = "unsubscription"
    }
    
    // MARK: - Error Descriptions
    
    /// Localized description of the error.
    public var errorDescription: String? {
        switch self {
        case .invalidEvent(let reason):
            return "Invalid event: \(reason.rawValue)"
            
        case .invalidSignature(let eventId, let reason):
            return "Invalid signature for event \(eventId): \(reason)"
            
        case .invalidEventId(let expected, let actual):
            return "Event ID mismatch. Expected: \(expected), Actual: \(actual)"
            
        case .invalidTimestamp(let reason):
            return "Invalid timestamp: \(reason)"
            
        case .unsupportedEventKind(let kind):
            return "Unsupported event kind: \(kind)"
            
        case .cryptographyError(let operation, let reason):
            return "Cryptography error during \(operation.rawValue): \(reason)"
            
        case .invalidPrivateKey(let reason):
            return "Invalid private key: \(reason)"
            
        case .invalidPublicKey(let reason):
            return "Invalid public key: \(reason)"
            
        case .keyDerivationFailed(let path, let reason):
            let pathInfo = path.map { " for path '\($0)'" } ?? ""
            return "Key derivation failed\(pathInfo): \(reason)"
            
        case .encryptionError(let operation, let reason):
            return "Encryption error during \(operation.rawValue): \(reason)"
            
        case .networkError(let operation, let reason):
            return "Network error during \(operation.rawValue): \(reason)"
            
        case .connectionFailed(let url, let reason):
            return "Connection to \(url) failed: \(reason)"
            
        case .relayError(let relay, let message):
            return "Relay \(relay) error: \(message)"
            
        case .timeout(let operation, let duration):
            return "\(operation) timed out after \(duration) seconds"
            
        case .serializationError(let type, let reason):
            return "Serialization error for \(type): \(reason)"
            
        case .invalidJSON(let json, let reason):
            let preview = String(json.prefix(100))
            return "Invalid JSON: \(reason). JSON: \(preview)..."
            
        case .missingField(let field, let context):
            return "Missing required field '\(field)' in \(context)"
            
        case .invalidBech32(let entity, let reason):
            return "Invalid Bech32 \(entity): \(reason)"
            
        case .invalidNIP05(let identifier, let reason):
            return "Invalid NIP-05 identifier '\(identifier)': \(reason)"
            
        case .invalidHex(let hex, let expectedLength):
            let lengthInfo = expectedLength.map { ". Expected length: \($0)" } ?? ""
            return "Invalid hex string: \(hex)\(lengthInfo)"
            
        case .invalidURI(let uri, let reason):
            return "Invalid URI '\(uri)': \(reason)"
            
        case .validationError(let field, let reason):
            return "Validation error for '\(field)': \(reason)"
            
        case .invalidFilter(let reason):
            return "Invalid filter: \(reason)"
            
        case .invalidTag(let tag, let reason):
            return "Invalid tag \(tag): \(reason)"
            
        case .nipError(let nip, let reason):
            return "NIP-\(String(format: "%02d", nip)) error: \(reason)"
            
        case .protocolViolation(let reason):
            return "Protocol violation: \(reason)"
            
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
            
        case .notFound(let resource):
            return "Resource not found: \(resource)"
            
        case .notPermitted(let operation, let reason):
            return "Operation '\(operation)' not permitted: \(reason)"
            
        case .rateLimited(let limit, let resetTime):
            let resetInfo = resetTime.map { ". Resets at: \($0)" } ?? ""
            return "Rate limit exceeded. Limit: \(limit)\(resetInfo)"
        }
    }
    
    /// Detailed recovery suggestion for the error.
    public var recoverySuggestion: String? {
        switch self {
        case .invalidEvent:
            return "Ensure the event has all required fields and follows the NOSTR protocol specification."
            
        case .invalidSignature:
            return "Verify that the event was signed with the correct private key and hasn't been tampered with."
            
        case .invalidEventId:
            return "The event ID doesn't match the calculated hash. The event may have been modified."
            
        case .invalidTimestamp:
            return "Use a Unix timestamp in seconds. Ensure the timestamp is not in the future or too far in the past."
            
        case .unsupportedEventKind:
            return "Check if this event kind is supported by the SDK. You may need to update to a newer version."
            
        case .cryptographyError(.signing, _):
            return "Ensure you have a valid private key and the message data is not corrupted."
            
        case .cryptographyError(.verification, _):
            return "Check that the public key and signature are valid and match the signed data."
            
        case .cryptographyError(.keyGeneration, _):
            return "Try generating the key again. If the problem persists, check system entropy."
            
        case .invalidPrivateKey:
            return "Private keys must be 32 bytes (64 hex characters). Ensure the key is properly formatted."
            
        case .invalidPublicKey:
            return "Public keys must be 32 bytes (64 hex characters) for Nostr. Check the key format."
            
        case .keyDerivationFailed:
            return "Verify the derivation path format (e.g., 'm/44'/1237'/0'/0/0') and seed validity."
            
        case .encryptionError(.encrypt, _):
            return "Check that you have valid keys for both parties and the content is not too large."
            
        case .encryptionError(.decrypt, _):
            return "Ensure you're using the correct key pair and the encrypted content hasn't been corrupted."
            
        case .connectionFailed:
            return "Check your internet connection and verify the relay URL is correct and accessible."
            
        case .relayError:
            return "The relay rejected your request. Check relay policies and your event content."
            
        case .timeout:
            return "The operation took too long. Try again with a better connection or different relay."
            
        case .serializationError:
            return "Ensure the data is properly formatted JSON and all required fields are present."
            
        case .invalidJSON:
            return "The JSON is malformed. Check for syntax errors like missing quotes or brackets."
            
        case .missingField:
            return "Add the missing required field to your data structure."
            
        case .invalidBech32:
            return "Ensure the Bech32 string is properly formatted with the correct prefix (npub, nsec, etc.)."
            
        case .invalidNIP05:
            return "NIP-05 identifiers must be in the format 'name@domain.com' or '_@domain.com'."
            
        case .invalidHex:
            return "Hex strings must contain only 0-9 and a-f characters, with the correct length."
            
        case .invalidURI:
            return "URIs must follow the 'nostr:' scheme with a valid Bech32-encoded entity."
            
        case .validationError:
            return "Check the field constraints and ensure the value meets all requirements."
            
        case .invalidFilter:
            return "Review the filter parameters. Ensure arrays are not empty and values are valid."
            
        case .invalidTag:
            return "Tags must be arrays with at least one element. The first element is the tag name."
            
        case .nipError:
            return "Consult the specific NIP documentation for implementation requirements."
            
        case .protocolViolation:
            return "Review the NOSTR protocol specification to ensure compliance."
            
        case .notImplemented:
            return "This feature is not yet available. Check for SDK updates or use an alternative approach."
            
        case .notFound:
            return "Verify the resource identifier and ensure it exists."
            
        case .notPermitted:
            return "You don't have permission for this operation. Check authentication and access rights."
            
        case .rateLimited:
            return "You've made too many requests. Wait before trying again or use a different relay."
            
        default:
            return nil
        }
    }
    
    /// Whether this error is recoverable through retry
    public var isRecoverable: Bool {
        switch self {
        case .networkError, .connectionFailed, .timeout, .rateLimited:
            return true
        case .relayError(_, let message) where message.lowercased().contains("try again"):
            return true
        default:
            return false
        }
    }
    
    /// Suggested retry delay in seconds, if applicable
    public var suggestedRetryDelay: TimeInterval? {
        switch self {
        case .rateLimited(_, let resetTime):
            if let reset = resetTime {
                return max(0, reset.timeIntervalSinceNow)
            }
            return 60 // Default to 1 minute
        case .timeout:
            return 5 // Retry after 5 seconds
        case .networkError, .connectionFailed:
            return 2 // Retry after 2 seconds
        default:
            return nil
        }
    }
}
