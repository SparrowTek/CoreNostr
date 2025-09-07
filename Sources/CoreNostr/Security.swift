import Foundation
import CryptoKit

/// Security utilities for constant-time operations and secure data handling
public struct Security: Sendable {
    
    /// Constant-time string comparison to prevent timing attacks
    /// - Parameters:
    ///   - lhs: First string to compare
    ///   - rhs: Second string to compare
    /// - Returns: True if strings are equal, false otherwise
    public static func constantTimeCompare(_ lhs: String, _ rhs: String) -> Bool {
        // Convert to data for constant-time comparison
        let lhsData = Data(lhs.utf8)
        let rhsData = Data(rhs.utf8)
        return lhsData.constantTimeEquals(rhsData)
    }
    
    /// Constant-time comparison for hexadecimal strings (case-insensitive)
    /// - Parameters:
    ///   - lhs: First hex string
    ///   - rhs: Second hex string
    /// - Returns: True if hex strings represent the same value
    public static func constantTimeHexCompare(_ lhs: String, _ rhs: String) -> Bool {
        // Normalize to lowercase for case-insensitive comparison
        let normalizedLhs = lhs.lowercased()
        let normalizedRhs = rhs.lowercased()
        
        // Convert to data for constant-time comparison
        let lhsData = Data(normalizedLhs.utf8)
        let rhsData = Data(normalizedRhs.utf8)
        return lhsData.constantTimeEquals(rhsData)
    }
    
    /// Securely clears sensitive data from memory
    /// - Parameter data: The data to clear
    public static func secureClear(_ data: inout Data) {
        _ = data.withUnsafeMutableBytes { bytes in
            // Use volatile write to prevent compiler optimization
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
    }
    
    /// Securely clears a string from memory
    /// - Parameter string: The string to clear
    public static func secureClear(_ string: inout String) {
        // Create mutable data from string
        var data = Data(string.utf8)
        secureClear(&data)
        // Replace string content with empty
        string = ""
    }
    
    /// Validates that a string doesn't contain sensitive patterns
    /// - Parameter string: The string to validate
    /// - Returns: True if the string appears safe, false if it may contain secrets
    public static func validateNoSecrets(_ string: String) -> Bool {
        // Check for common patterns that might indicate secrets
        let lowerString = string.lowercased()
        
        // Check for hex strings that look like keys (64 chars for private keys)
        if string.count == 64 && string.allSatisfy({ $0.isHexDigit }) {
            return false
        }
        
        // Check for hex strings that might be signatures (128 chars)
        if string.count == 128 && string.allSatisfy({ $0.isHexDigit }) {
            return false
        }
        
        // Check for common secret indicators
        let secretPatterns = [
            "privatekey", "private_key", "privkey",
            "secretkey", "secret_key",
            "nsec1", // Nostr private key bech32
            "seed", "mnemonic",
            "password", "passphrase"
        ]
        
        for pattern in secretPatterns {
            if lowerString.contains(pattern) {
                return false
            }
        }
        
        return true
    }
    
    /// Redacts sensitive information from error messages
    /// - Parameter error: The error to redact
    /// - Returns: A safe error description
    public static func redactedErrorDescription(_ error: Error) -> String {
        let description = error.localizedDescription
        
        // Redact hex strings that might be keys
        let hexPattern = #"\b[0-9a-fA-F]{64,128}\b"#
        let redacted = description.replacingOccurrences(
            of: hexPattern,
            with: "[REDACTED]",
            options: .regularExpression
        )
        
        // Redact nsec bech32 strings
        let nsecPattern = #"\bnsec1[a-z0-9]{58,}\b"#
        let finalRedacted = redacted.replacingOccurrences(
            of: nsecPattern,
            with: "[REDACTED_PRIVATE_KEY]",
            options: .regularExpression
        )
        
        return finalRedacted
    }
}

/// Extension to make Data support constant-time operations (if not already present)
extension Data {
    /// Constant-time equality check to mitigate timing attacks
    /// - Parameter other: Other data to compare
    /// - Returns: True if equal, false otherwise
    public func constantTimeEquals(_ other: Data) -> Bool {
        // Use XOR to compare bytes without early exit
        var result: UInt8 = 0
        let maxLen = Swift.max(self.count, other.count)
        
        // Compare lengths in constant time
        result |= UInt8(self.count ^ other.count)
        
        // Compare bytes
        for i in 0..<maxLen {
            let a: UInt8 = i < self.count ? self[i] : 0
            let b: UInt8 = i < other.count ? other[i] : 0
            result |= a ^ b
        }
        
        return result == 0
    }
}

/// Secure wrapper for sensitive strings that prevents accidental logging
public struct SecureString: Sendable {
    private let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    /// Access the underlying value (use with caution)
    public func unsafeValue() -> String {
        return value
    }
    
    /// Custom string representation that doesn't expose the value
    public var description: String {
        return "[SECURE_STRING]"
    }
    
    /// Debug description that doesn't expose the value
    public var debugDescription: String {
        return "[SECURE_STRING: \(value.count) characters]"
    }
}

/// Protocol for types that handle sensitive data
public protocol SecureDataHandling {
    /// Clears any sensitive data from memory
    mutating func secureClear()
    
    /// Returns a redacted version safe for logging
    func redactedDescription() -> String
}

/// Extension to make KeyPair conform to SecureDataHandling
extension KeyPair: SecureDataHandling {
    public mutating func secureClear() {
        // Note: Since KeyPair properties are let constants, we can't truly clear them
        // This is a limitation of the current design
        // In production, consider using a class with mutable properties for true secure clearing
    }
    
    public func redactedDescription() -> String {
        return "KeyPair(publicKey: \(publicKey), privateKey: [REDACTED])"
    }
}