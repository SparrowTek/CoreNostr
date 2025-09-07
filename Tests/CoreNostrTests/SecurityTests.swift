import Testing
import Foundation
@testable import CoreNostr

@Suite("Security: Constant-Time Operations and Secret Handling")
struct SecurityTests {
    
    // MARK: - Constant-Time Comparison Tests
    
    @Test("Constant-time string comparison")
    func testConstantTimeStringComparison() {
        // Test equal strings
        #expect(Security.constantTimeCompare("hello", "hello") == true)
        
        // Test different strings
        #expect(Security.constantTimeCompare("hello", "world") == false)
        
        // Test empty strings
        #expect(Security.constantTimeCompare("", "") == true)
        
        // Test different lengths
        #expect(Security.constantTimeCompare("short", "much longer string") == false)
        
        // Test unicode
        #expect(Security.constantTimeCompare("Hello 👋", "Hello 👋") == true)
        #expect(Security.constantTimeCompare("Hello 👋", "Hello 🌍") == false)
    }
    
    @Test("Constant-time hex comparison (case-insensitive)")
    func testConstantTimeHexComparison() {
        let hex1 = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let hex2 = "3BF0C63FCB93463407AF97A5E5EE64FA883D107EF9E558472C4EB9AAAEFA459D"
        let hex3 = "0000000000000000000000000000000000000000000000000000000000000000"
        
        // Same hex, different case
        #expect(Security.constantTimeHexCompare(hex1, hex2) == true)
        
        // Different hex values
        #expect(Security.constantTimeHexCompare(hex1, hex3) == false)
        
        // Same hex, same case
        #expect(Security.constantTimeHexCompare(hex1, hex1) == true)
    }
    
    @Test("Data constant-time equality")
    func testDataConstantTimeEquality() {
        let data1 = Data([1, 2, 3, 4, 5])
        let data2 = Data([1, 2, 3, 4, 5])
        let data3 = Data([1, 2, 3, 4, 6])
        let data4 = Data([1, 2, 3])
        
        // Equal data
        #expect(data1.constantTimeEquals(data2) == true)
        
        // Different data, same length
        #expect(data1.constantTimeEquals(data3) == false)
        
        // Different lengths
        #expect(data1.constantTimeEquals(data4) == false)
        
        // Empty data
        #expect(Data().constantTimeEquals(Data()) == true)
    }
    
    // MARK: - Secret Detection Tests
    
    @Test("Validate no secrets in strings")
    func testValidateNoSecrets() {
        // Safe strings
        #expect(Security.validateNoSecrets("Hello, World!") == true)
        #expect(Security.validateNoSecrets("This is a normal message") == true)
        #expect(Security.validateNoSecrets("npub1234567890") == true)  // Public keys are OK
        
        // Strings that look like private keys (64 hex chars)
        let privateKeyHex = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        #expect(Security.validateNoSecrets(privateKeyHex) == false)
        
        // Strings that look like signatures (128 hex chars)
        let signatureHex = privateKeyHex + privateKeyHex
        #expect(Security.validateNoSecrets(signatureHex) == false)
        
        // Strings containing secret indicators
        #expect(Security.validateNoSecrets("My privatekey is...") == false)
        #expect(Security.validateNoSecrets("nsec1abc123...") == false)
        #expect(Security.validateNoSecrets("seed phrase here") == false)
        #expect(Security.validateNoSecrets("password: 12345") == false)
    }
    
    @Test("Redact sensitive information from errors")
    func testRedactedErrorDescription() {
        // Test redacting hex keys
        let errorWithKey = NSError(
            domain: "Test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid key: 3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]
        )
        let redacted1 = Security.redactedErrorDescription(errorWithKey)
        #expect(redacted1.contains("[REDACTED]"))
        #expect(!redacted1.contains("3bf0c63fcb93463407af97a5e5ee64fa"))
        
        // Test redacting nsec bech32
        let errorWithNsec = NSError(
            domain: "Test",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"]
        )
        let redacted2 = Security.redactedErrorDescription(errorWithNsec)
        #expect(redacted2.contains("[REDACTED_PRIVATE_KEY]"))
        #expect(!redacted2.contains("nsec1"))
        
        // Test that normal errors are not modified
        let normalError = NSError(
            domain: "Test",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Connection failed"]
        )
        let redacted3 = Security.redactedErrorDescription(normalError)
        #expect(redacted3 == "Connection failed")
    }
    
    // MARK: - Secure Clear Tests
    
    @Test("Secure clear data")
    func testSecureClearData() {
        var sensitiveData = Data("sensitive information".utf8)
        let originalCount = sensitiveData.count
        
        Security.secureClear(&sensitiveData)
        
        // Data should be zeroed
        #expect(sensitiveData.allSatisfy { $0 == 0 })
        #expect(sensitiveData.count == originalCount)
    }
    
    @Test("Secure clear string")
    func testSecureClearString() {
        var sensitiveString = "sensitive private key"
        
        Security.secureClear(&sensitiveString)
        
        // String should be empty after clearing
        #expect(sensitiveString.isEmpty)
    }
    
    // MARK: - SecureString Tests
    
    @Test("SecureString doesn't expose value in description")
    func testSecureStringDescription() {
        let privateKey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let secureString = SecureString(privateKey)
        
        // Description should not contain the actual value
        #expect(secureString.description == "[SECURE_STRING]")
        #expect(secureString.debugDescription == "[SECURE_STRING: 64 characters]")
        
        // But we can still access the value when needed
        #expect(secureString.unsafeValue() == privateKey)
    }
    
    // MARK: - KeyPair Security Tests
    
    @Test("KeyPair redacted description")
    func testKeyPairRedactedDescription() throws {
        let keyPair = try KeyPair(privateKey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")
        
        let redacted = keyPair.redactedDescription()
        
        // Should contain public key but not private key
        #expect(redacted.contains(keyPair.publicKey))
        #expect(redacted.contains("[REDACTED]"))
        #expect(!redacted.contains(keyPair.privateKey))
    }
    
    // MARK: - Error Message Security Tests
    
    @Test("NostrError doesn't leak sensitive data")
    func testNostrErrorNoLeak() throws {
        // Test that validation errors don't expose the actual invalid values
        let invalidPrivateKey = "not_a_valid_key"
        
        #expect(throws: NostrError.self) {
            _ = try KeyPair(privateKey: invalidPrivateKey)
        }
        
        // The error message should not contain the actual invalid key
        do {
            _ = try KeyPair(privateKey: invalidPrivateKey)
        } catch {
            let errorDescription = error.localizedDescription
            #expect(!errorDescription.contains(invalidPrivateKey))
        }
    }
    
    @Test("Event verification error doesn't leak IDs")
    func testEventVerificationErrorNoLeak() throws {
        // Create an event with mismatched ID
        let event = try NostrEvent(
            id: "0000000000000000000000000000000000000000000000000000000000000000",
            pubkey: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
            createdAt: 1000000,
            kind: 1,
            tags: [],
            content: "Test",
            sig: "0000000000000000000000000000000000000000000000000000000000000000" +
                 "0000000000000000000000000000000000000000000000000000000000000000"
        )
        
        do {
            _ = try KeyPair.verifyEvent(event)
        } catch let error as NostrError {
            if case .invalidEventId(let expected, let actual) = error {
                // The error should have redacted values
                #expect(expected == "[REDACTED]")
                #expect(actual == "[REDACTED]")
            }
        }
    }
    
    // MARK: - Timing Attack Resistance Tests
    
    @Test("Constant-time comparison is actually constant-time")
    func testConstantTimeComparisonTiming() {
        // This is a basic test - in production, you'd want more sophisticated timing analysis
        let testString1 = String(repeating: "a", count: 1000)
        let testString2 = String(repeating: "a", count: 999) + "b"  // Differs at the end
        let testString3 = "b" + String(repeating: "a", count: 999)  // Differs at the start
        
        // Both comparisons should take similar time regardless of where the difference is
        // (This is just a sanity check, not a rigorous timing analysis)
        
        let start1 = Date()
        for _ in 0..<1000 {
            _ = Security.constantTimeCompare(testString1, testString2)
        }
        let time1 = Date().timeIntervalSince(start1)
        
        let start2 = Date()
        for _ in 0..<1000 {
            _ = Security.constantTimeCompare(testString1, testString3)
        }
        let time2 = Date().timeIntervalSince(start2)
        
        // Times should be roughly similar (within 50% of each other)
        // This is a very loose bound - proper timing attack testing requires more sophisticated methods
        let ratio = max(time1, time2) / min(time1, time2)
        #expect(ratio < 1.5)
    }
    
    // MARK: - Integration Tests
    
    @Test("Encryption doesn't leak keys in errors")
    func testEncryptionErrorsNoLeak() throws {
        let keyPair = try KeyPair.generate()
        let invalidPublicKey = "invalid_public_key"
        
        do {
            _ = try keyPair.encrypt(message: "Test", to: invalidPublicKey)
        } catch {
            let errorMessage = error.localizedDescription
            // Error should not contain the private key
            #expect(!errorMessage.contains(keyPair.privateKey))
            // Error should not contain the invalid public key either
            #expect(!errorMessage.contains(invalidPublicKey))
        }
    }
    
    @Test("NIP-44 doesn't leak keys in errors")
    func testNIP44ErrorsNoLeak() throws {
        let invalidPayload = "not_valid_base64!"
        let keyPair = try KeyPair.generate()
        
        do {
            _ = try NIP44.decrypt(
                payload: invalidPayload,
                recipientPrivateKey: keyPair.privateKey,
                senderPublicKey: keyPair.publicKey
            )
        } catch {
            let errorMessage = error.localizedDescription
            // Error should not contain any keys
            #expect(!errorMessage.contains(keyPair.privateKey))
            #expect(!errorMessage.contains(keyPair.publicKey))
        }
    }
}