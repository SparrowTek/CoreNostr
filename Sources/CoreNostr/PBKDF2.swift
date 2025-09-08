import Foundation
import CryptoKit

/// PBKDF2 implementation using swift-crypto
enum PBKDF2 {
    /// Derives a key from a password using PBKDF2 with HMAC-SHA512
    /// - Parameters:
    ///   - password: The password bytes
    ///   - salt: The salt bytes
    ///   - iterations: Number of iterations (default: 2048 for BIP39)
    ///   - keyLength: Desired output key length in bytes
    /// - Returns: Derived key data
    /// - Throws: NostrError if derivation fails
    static func pbkdf2SHA512(
        password: Data,
        salt: Data,
        iterations: Int = 2048,
        keyLength: Int = 64
    ) throws -> Data {
        guard iterations > 0 else {
            throw NostrError.cryptographyError(operation: .keyDerivation, reason: "Iterations must be positive")
        }
        
        guard keyLength > 0 else {
            throw NostrError.cryptographyError(operation: .keyDerivation, reason: "Key length must be positive")
        }
        
        let hashLen = 64 // SHA512 output length
        let blocks = (keyLength + hashLen - 1) / hashLen
        var derivedKey = Data()
        
        for blockIndex in 1...blocks {
            var block = Data()
            
            // First iteration: HMAC(password, salt || Int32BE(i))
            var saltWithIndex = salt
            withUnsafeBytes(of: UInt32(blockIndex).bigEndian) { bytes in
                saltWithIndex.append(contentsOf: bytes)
            }
            
            let key = SymmetricKey(data: password)
            var u = Data(HMAC<SHA512>.authenticationCode(for: saltWithIndex, using: key))
            block = u
            
            // Remaining iterations
            for _ in 2...iterations {
                u = Data(HMAC<SHA512>.authenticationCode(for: u, using: key))
                
                // XOR with previous result
                for i in 0..<block.count {
                    block[i] ^= u[i]
                }
            }
            
            derivedKey.append(block)
        }
        
        return Data(derivedKey.prefix(keyLength))
    }
}