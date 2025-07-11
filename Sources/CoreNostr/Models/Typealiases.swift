import Foundation

/// A unique identifier for a NOSTR event, represented as a 64-character hexadecimal string.
/// 
/// Event IDs are calculated by taking the SHA256 hash of the serialized event data
/// according to NIP-01 specification.
public typealias EventID = String

/// A NOSTR public key, represented as a 64-character hexadecimal string.
/// 
/// Public keys are derived from secp256k1 private keys and serve as user identities
/// in the NOSTR protocol.
public typealias PublicKey = String

/// A NOSTR private key, represented as a 64-character hexadecimal string.
/// 
/// Private keys are used to sign events and should be kept secret.
public typealias PrivateKey = String

/// A Schnorr signature over secp256k1, represented as a 128-character hexadecimal string.
/// 
/// Signatures are created by signing the serialized event data with the corresponding private key.
public typealias Signature = String

