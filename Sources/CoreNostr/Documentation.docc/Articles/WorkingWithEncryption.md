# Working with Encryption in CoreNostr

Learn how to use CoreNostr's encryption features for secure communication.

## Overview

CoreNostr provides multiple encryption mechanisms for different use cases:
- **NIP-04**: Legacy direct messages (deprecated but still supported)
- **NIP-44**: Modern encrypted payloads with versioning
- **NIP-17**: Private direct messages with metadata privacy
- **NIP-59**: Gift wrap for hiding sender/recipient metadata

## NIP-44: Encrypted Payloads

NIP-44 provides a modern, versioned encryption scheme using ChaCha20 and HMAC-SHA256.

### Basic Encryption

```swift
import CoreNostr

// Encrypt a message
let encrypted = try NIP44.encrypt(
    plaintext: "Secret message",
    senderPrivateKey: senderKeyPair.privateKey,
    recipientPublicKey: recipientPublicKey
)

print("Encrypted payload: \(encrypted)")
```

### Decryption

```swift
// Decrypt a message
let decrypted = try NIP44.decrypt(
    payload: encrypted,
    recipientPrivateKey: recipientKeyPair.privateKey,
    senderPublicKey: senderPublicKey
)

print("Decrypted message: \(decrypted)")
```

### Understanding NIP-44 Format

NIP-44 payloads are base64-encoded and contain:
- Version byte (0x02)
- 32-byte nonce
- Encrypted ciphertext
- 32-byte HMAC

The encryption uses:
- **Key derivation**: HKDF-SHA256
- **Encryption**: ChaCha20
- **Authentication**: HMAC-SHA256

## NIP-17: Private Direct Messages

NIP-17 builds on NIP-44 to provide metadata-private messaging.

### Sending a Private Message

```swift
// Create a private direct message
let privateMessage = try NIP17.createDirectMessage(
    content: "This is completely private",
    recipientPubkey: recipientPubkey,
    senderKeyPair: senderKeyPair,
    subject: "Optional subject line",
    previousEventId: nil // For threading
)

// The message is automatically gift-wrapped for privacy
```

### Understanding Gift Wrap

Gift wrap (NIP-59) hides metadata by:
1. Creating the actual message (rumor)
2. Sealing it with the recipient's public key
3. Wrapping it with an ephemeral key

```swift
// Manual gift wrapping (usually done automatically)
let rumor = NostrEvent(
    pubkey: senderKeyPair.publicKey,
    kind: 14, // DM kind
    tags: [["p", recipientPubkey]],
    content: "Secret message"
)

let giftWrapped = try NIP59.giftWrap(
    rumor: rumor,
    recipientPubkey: recipientPubkey,
    senderKeyPair: senderKeyPair
)
```

## NIP-04: Legacy Direct Messages

While deprecated, NIP-04 is still widely used for backward compatibility.

### Creating a Legacy DM

```swift
// Create a NIP-04 direct message
let legacyDM = try NostrDirectMessage.createDirectMessageEvent(
    keyPair: senderKeyPair,
    recipientPubkey: recipientPubkey,
    message: "Legacy encrypted message"
)

// Decrypt a received legacy DM
if let dm = NostrDirectMessage(from: event, privateKey: recipientPrivateKey) {
    print("Sender: \(dm.senderPubkey)")
    print("Message: \(dm.content)")
}
```

### Migration Path

When implementing direct messages:
1. Send using NIP-17 (gift-wrapped)
2. Fall back to NIP-04 for older clients
3. Always support reading both formats

## Best Practices

### Key Management

```swift
// Never hardcode private keys
let privateKey = getPrivateKeyFromSecureStorage()

// Validate keys before use
do {
    try Validation.validatePrivateKey(privateKey)
    try Validation.validatePublicKey(recipientPubkey)
} catch {
    print("Invalid keys: \(error)")
}
```

### Error Handling

```swift
do {
    let encrypted = try NIP44.encrypt(
        plaintext: message,
        senderPrivateKey: privateKey,
        recipientPublicKey: recipientKey
    )
} catch NIP44.NIP44Error.invalidPublicKey {
    print("Invalid recipient public key")
} catch NIP44.NIP44Error.encryptionFailed {
    print("Encryption failed")
} catch {
    print("Unexpected error: \(error)")
}
```

### Content Size Limits

```swift
// NIP-44 has a maximum plaintext size
let maxSize = 65535 // 64KB - 1

if message.utf8.count > maxSize {
    // Split into multiple messages or compress
}
```

## Security Considerations

1. **Forward Secrecy**: NIP-44 doesn't provide forward secrecy. Consider ephemeral keys for sensitive data.

2. **Metadata Privacy**: Use NIP-17/NIP-59 to hide sender/recipient information.

3. **Key Rotation**: Implement regular key rotation for long-term security.

4. **Validation**: Always validate decrypted content:

```swift
let decrypted = try NIP44.decrypt(payload: encrypted, ...)

// Validate the decrypted content
guard decrypted.utf8.count < 1_000_000 else {
    throw NostrError.invalidEvent("Decrypted content too large")
}
```

## Performance Tips

1. **Batch Operations**: When encrypting for multiple recipients:

```swift
let recipients = ["pubkey1", "pubkey2", "pubkey3"]
let encrypted = try recipients.map { recipient in
    try NIP44.encrypt(
        plaintext: message,
        senderPrivateKey: senderKey,
        recipientPublicKey: recipient
    )
}
```

2. **Caching**: Cache ECDH shared secrets for frequently contacted users (with appropriate security measures).

3. **Async Operations**: Use async/await for large encryption operations:

```swift
func encryptLargeData() async throws -> String {
    return try await Task {
        try NIP44.encrypt(
            plaintext: largeContent,
            senderPrivateKey: privateKey,
            recipientPublicKey: publicKey
        )
    }.value
}
```

## Debugging Encryption Issues

Common issues and solutions:

1. **"Invalid payload format"**: Check base64 encoding
2. **"HMAC verification failed"**: Keys might be swapped
3. **"Decryption failed"**: Ensure using correct NIP version

```swift
// Debug helper
func debugEncryption(payload: String) {
    guard let data = Data(base64Encoded: payload) else {
        print("Invalid base64")
        return
    }
    
    print("Payload size: \(data.count)")
    print("Version: \(data[0])")
    print("Has valid structure: \(data.count >= 82)")
}
```

## Summary

CoreNostr provides comprehensive encryption support:
- Use NIP-44 for general encryption needs
- Use NIP-17 for private direct messages
- Support NIP-04 for backward compatibility
- Always validate inputs and handle errors
- Consider metadata privacy with gift wrapping