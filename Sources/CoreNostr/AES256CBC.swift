import Foundation
import CommonCrypto

/// AES-256-CBC encryption/decryption using CommonCrypto
enum AES256CBC {
    
    enum AESError: Error {
        case invalidKeySize
        case invalidIVSize
        case encryptionFailed
        case decryptionFailed
    }
    
    /// Encrypt data using AES-256-CBC with PKCS7 padding
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - key: 32-byte encryption key
    ///   - iv: 16-byte initialization vector
    /// - Returns: Encrypted data
    /// - Throws: AESError if encryption fails
    static func encrypt(data: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == kCCKeySizeAES256 else {
            throw AESError.invalidKeySize
        }
        guard iv.count == kCCBlockSizeAES128 else {
            throw AESError.invalidIVSize
        }
        
        // Calculate output buffer size with padding
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesEncrypted = 0
        
        let status = buffer.withUnsafeMutableBytes { bufferBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress,
                            data.count,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &bytesEncrypted
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw AESError.encryptionFailed
        }
        
        return buffer.prefix(bytesEncrypted)
    }
    
    /// Decrypt data using AES-256-CBC with PKCS7 padding
    /// - Parameters:
    ///   - data: Data to decrypt
    ///   - key: 32-byte decryption key
    ///   - iv: 16-byte initialization vector
    /// - Returns: Decrypted data
    /// - Throws: AESError if decryption fails
    static func decrypt(data: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == kCCKeySizeAES256 else {
            throw AESError.invalidKeySize
        }
        guard iv.count == kCCBlockSizeAES128 else {
            throw AESError.invalidIVSize
        }
        
        // Output buffer size
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesDecrypted = 0
        
        let status = buffer.withUnsafeMutableBytes { bufferBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress,
                            data.count,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &bytesDecrypted
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw AESError.decryptionFailed
        }
        
        return buffer.prefix(bytesDecrypted)
    }
}