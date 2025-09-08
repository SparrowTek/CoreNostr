# Security Best Practices

Essential security guidelines for working with CoreNostr and the Nostr protocol.

## Overview

Security is paramount when working with cryptographic protocols. This guide covers best practices for key management, encryption, validation, and secure coding with CoreNostr.

## Key Management

### Private Key Security

**Never expose private keys:**

```swift
// ❌ WRONG - Never log private keys
print("Private key: \(keyPair.privateKey)")
logger.debug("User key: \(privateKey)")

// ✅ CORRECT - Log only public information
print("Public key: \(keyPair.publicKey)")
logger.debug("User npub: \(npub)")
```

**Secure storage:**

```swift
// Store keys securely (example using Keychain on iOS/macOS)
import Security

func storePrivateKey(_ privateKey: String, identifier: String) throws {
    let data = privateKey.data(using: .utf8)!
    
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: identifier,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.storeFailed
    }
}
```

**Clear sensitive data:**

```swift
// Clear sensitive data from memory when done
var privateKeyData = Data(privateKey.utf8)
defer {
    // Overwrite the memory
    privateKeyData.withUnsafeMutableBytes { bytes in
        memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
    }
}
```

### Key Derivation

Use proper key derivation for deterministic keys:

```swift
// Derive keys from seed phrase (NIP-06)
let mnemonic = try NIP06.generateMnemonic()
let seed = try NIP06.mnemonicToSeed(mnemonic: mnemonic)
let keyPair = try NIP06.deriveKeyPair(
    from: seed,
    accountIndex: 0
)

// Always use strong passphrases
let seedWithPassphrase = try NIP06.mnemonicToSeed(
    mnemonic: mnemonic,
    passphrase: "strong_passphrase_here"
)
```

## Encryption Best Practices

### Use Modern Encryption

**Prefer NIP-44 over NIP-04:**

```swift
// ❌ DEPRECATED - NIP-04 has known weaknesses
let encrypted = try NostrCrypto.encrypt(
    message: content,
    senderPrivateKey: sender.privateKey,
    recipientPublicKey: recipient.publicKey
)

// ✅ RECOMMENDED - NIP-44 with modern crypto
let encrypted = try NIP44.encrypt(
    plaintext: content,
    senderPrivateKey: sender.privateKey,
    recipientPublicKey: recipient.publicKey
)
```

### Metadata Protection

Use NIP-17 for private messages with metadata protection:

```swift
// Gift-wrapped messages hide metadata
let giftWrapped = try NIP17.createGiftWrap(
    content: sensitiveContent,
    senderKeyPair: senderKeyPair,
    recipientPubkey: recipientPubkey
)

// The outer wrapper uses ephemeral keys
// Real sender/recipient are hidden
```

## Input Validation

### Always Validate External Data

```swift
// Validate all inputs from relays
func processEvent(_ eventData: Data) throws {
    // Decode and validate
    let event = try JSONDecoder().decode(NostrEvent.self, from: eventData)
    
    // Verify signature
    guard try event.verify() else {
        throw ValidationError.invalidSignature
    }
    
    // Validate timestamp (prevent replay attacks)
    let now = Date().timeIntervalSince1970
    let skew: TimeInterval = 60 // 1 minute
    
    guard abs(event.createdAt - Int64(now)) < Int64(skew) else {
        throw ValidationError.timestampOutOfRange
    }
    
    // Validate content length
    guard event.content.utf8.count <= 64_000 else {
        throw ValidationError.contentTooLarge
    }
    
    // Now safe to process
    processValidatedEvent(event)
}
```

### Sanitize User Content

```swift
// Sanitize content before display
func sanitizeContent(_ content: String) -> String {
    // Remove potential XSS vectors
    let dangerous = ["<script", "javascript:", "onclick=", "onerror="]
    var sanitized = content
    
    for pattern in dangerous {
        sanitized = sanitized.replacingOccurrences(
            of: pattern,
            with: "",
            options: .caseInsensitive
        )
    }
    
    return sanitized
}
```

## Secure Communication

### Verify Relay Connections

```swift
// Use secure WebSocket connections
let relayURL = URL(string: "wss://relay.example.com")! // wss:// not ws://

// Optionally implement certificate pinning
func urlSession(_ session: URLSession,
                didReceive challenge: URLAuthenticationChallenge,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
          let serverTrust = challenge.protectionSpace.serverTrust else {
        completionHandler(.cancelAuthenticationChallenge, nil)
        return
    }
    
    // Verify certificate
    // ... certificate pinning logic ...
}
```

### Rate Limiting

Implement client-side rate limiting:

```swift
class RateLimiter {
    private var lastRequestTimes: [String: Date] = [:]
    private let minInterval: TimeInterval = 0.1 // 100ms between requests
    
    func shouldAllow(operation: String) -> Bool {
        let now = Date()
        
        if let lastTime = lastRequestTimes[operation] {
            guard now.timeIntervalSince(lastTime) >= minInterval else {
                return false
            }
        }
        
        lastRequestTimes[operation] = now
        return true
    }
}
```

## Cryptographic Safety

### Constant-Time Comparisons

Use constant-time comparisons for sensitive data:

```swift
// Comparing signatures or keys
let isEqual = Security.constantTimeCompare(signature1, signature2)
```

### Secure Random Generation

```swift
// Generate secure random data
func generateSecureRandom(bytes: Int) throws -> Data {
    var data = Data(count: bytes)
    let result = data.withUnsafeMutableBytes { buffer in
        SecRandomCopyBytes(kSecRandomDefault, bytes, buffer.baseAddress!)
    }
    
    guard result == errSecSuccess else {
        throw CryptoError.randomGenerationFailed
    }
    
    return data
}
```

## Error Handling

### Don't Leak Sensitive Information

```swift
// ❌ WRONG - Exposes implementation details
catch {
    print("Decryption failed: \(error)")
    // Could leak: wrong padding, invalid MAC, etc.
}

// ✅ CORRECT - Generic error messages
catch {
    logger.error("Failed to decrypt message")
    showUser("Unable to decrypt message")
}
```

## Proof of Work

Implement PoW for spam prevention:

```swift
// Add proof of work to events (NIP-13)
let targetDifficulty = 20 // Adjust based on requirements

let minedEvent = try NIP13.mine(
    event: event,
    targetDifficulty: targetDifficulty,
    timeout: 30.0 // Don't mine forever
)

// Verify PoW on received events
let difficulty = NIP13.calculateDifficulty(for: event.id)
guard difficulty >= minimumRequired else {
    throw ValidationError.insufficientProofOfWork
}
```

## Audit Checklist

- [ ] No private keys in logs or error messages
- [ ] All external inputs validated
- [ ] Using NIP-44/17 instead of NIP-04
- [ ] Secure WebSocket connections (wss://)
- [ ] Rate limiting implemented
- [ ] Proof of Work for spam prevention
- [ ] Constant-time comparisons for crypto
- [ ] Secure random number generation
- [ ] Keys stored securely (Keychain/equivalent)
- [ ] Memory cleared after using sensitive data
- [ ] Generic error messages (no info leakage)
- [ ] Content sanitized before display

## Security Resources

- [OWASP Cryptographic Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html)
- [Apple Security Framework](https://developer.apple.com/documentation/security)
- [Nostr Security Considerations](https://github.com/nostr-protocol/nips/blob/master/01.md#security-considerations)

## See Also

- <doc:WorkingWithNIPs>
- <doc:QuickStart>
- ``Security``
- ``NIP44``