import Foundation
import Crypto
import CryptoKit
import P256K

/// BIP32 hierarchical deterministic key derivation.
///
/// Supports both hardened and non-hardened child derivation as required by
/// NIP-06 (path `m/44'/1237'/<account>'/0/0` — last two indexes are NOT
/// hardened).
public struct BIP32: Sendable {
    /// Key used by BIP32 master-key derivation (`HMAC-SHA512("Bitcoin seed", seed)`).
    fileprivate static let masterKeySalt = "Bitcoin seed"

    /// Offset that marks a derivation index as *hardened* (BIP32).
    /// Indices `>= hardenedOffset` produce hardened child keys.
    public static let hardenedOffset: UInt32 = 0x80000000

    /// Return the hardened version of a BIP32 child index.
    public static func hardened(_ index: UInt32) -> UInt32 {
        index + hardenedOffset
    }

    /// Extended key structure
    public struct ExtendedKey: Sendable {
        public let key: Data
        public let chainCode: Data
        public let depth: UInt8
        public let fingerprint: UInt32
        public let childNumber: UInt32

        public init(key: Data, chainCode: Data, depth: UInt8 = 0, fingerprint: UInt32 = 0, childNumber: UInt32 = 0) {
            self.key = key
            self.chainCode = chainCode
            self.depth = depth
            self.fingerprint = fingerprint
            self.childNumber = childNumber
        }
    }

    /// Creates master key from seed
    /// - Parameter seed: 16-64 byte seed (typically a BIP39 64-byte seed)
    /// - Returns: Master extended key
    /// - Throws: ``NostrError`` if derivation fails or the master private key
    ///   is outside the valid secp256k1 range
    public static func createMasterKey(from seed: Data) throws -> ExtendedKey {
        guard seed.count >= 16 && seed.count <= 64 else {
            throw NostrError.keyDerivationFailed(path: nil, reason: "Invalid seed length: \(seed.count) bytes. Expected 16-64 bytes")
        }

        // HMAC-SHA512 with the BIP32 "Bitcoin seed" salt.
        let hmacKey = SymmetricKey(data: Data(BIP32.masterKeySalt.utf8))
        let hmac = HMAC<CryptoKit.SHA512>.authenticationCode(for: seed, using: hmacKey)
        let result = Data(hmac)

        let masterKey = Data(result[0..<32])
        let chainCode = Data(result[32..<64])

        // BIP32 requires the master private key to be in (0, n). P256K's
        // `secp256k1_ec_seckey_verify` runs as part of `PrivateKey.init`, so
        // a failure here means I_L was 0 or ≥ n.
        do {
            _ = try P256K.Signing.PrivateKey(dataRepresentation: masterKey)
        } catch {
            throw NostrError.keyDerivationFailed(
                path: "m",
                reason: "Master key is outside the valid secp256k1 range"
            )
        }

        return ExtendedKey(key: masterKey, chainCode: chainCode)
    }

    /// Derives a child extended key from its parent per BIP32 §"Child key derivation".
    ///
    /// - Hardened (`index ≥ 0x80000000`):
    ///   `I = HMAC-SHA512(parent.chain_code, 0x00 ‖ parent.priv ‖ ser32(index))`
    /// - Non-hardened (`index < 0x80000000`):
    ///   `I = HMAC-SHA512(parent.chain_code, parent.compressed_pub ‖ ser32(index))`
    ///
    /// In both cases `I_L` (left 32 bytes) is added to the parent private key
    /// modulo the secp256k1 group order to form the child private key, and
    /// `I_R` (right 32 bytes) becomes the child chain code. If `I_L ≥ n` or
    /// the resulting child key is `0` the spec says to retry with the next
    /// index; the probability is ~2⁻¹²⁷, so for the bounded NIP-06 path we
    /// surface a clear error instead of silently bumping `childNumber`.
    public static func deriveChild(_ parent: ExtendedKey, index: UInt32) throws -> ExtendedKey {
        let isHardened = index >= Self.hardenedOffset

        // Build the HMAC input.
        var data = Data()
        if isHardened {
            data.append(0x00)
            data.append(parent.key)
        } else {
            let parentSigningKey: P256K.Signing.PrivateKey
            do {
                parentSigningKey = try P256K.Signing.PrivateKey(
                    dataRepresentation: parent.key,
                    format: .compressed
                )
            } catch {
                throw NostrError.keyDerivationFailed(
                    path: "child index \(index)",
                    reason: "Parent private key is invalid"
                )
            }

            let compressedPub = parentSigningKey.publicKey.dataRepresentation
            guard compressedPub.count == 33 else {
                throw NostrError.keyDerivationFailed(
                    path: "child index \(index)",
                    reason: "Compressed parent public key has unexpected length \(compressedPub.count)"
                )
            }
            data.append(compressedPub)
        }
        data.append(contentsOf: withUnsafeBytes(of: index.bigEndian) { Array($0) })

        // HMAC-SHA512 with parent chain code as the key.
        let hmacKey = SymmetricKey(data: parent.chainCode)
        let hmac = HMAC<CryptoKit.SHA512>.authenticationCode(for: data, using: hmacKey)
        let result = Data(hmac)

        let il = Data(result[0..<32])
        let ir = Data(result[32..<64])

        // child_priv = (I_L + parent_priv) mod n via libsecp256k1's
        // `secp256k1_ec_seckey_tweak_add` (validated). A throw here means
        // the BIP32 retry condition (I_L ≥ n or sum = 0) was hit.
        let parentSigningKey: P256K.Signing.PrivateKey
        do {
            parentSigningKey = try P256K.Signing.PrivateKey(dataRepresentation: parent.key)
        } catch {
            throw NostrError.keyDerivationFailed(
                path: "child index \(index)",
                reason: "Parent private key is invalid"
            )
        }

        let tweaked: P256K.Signing.PrivateKey
        do {
            tweaked = try parentSigningKey.add(Array(il))
        } catch {
            throw NostrError.keyDerivationFailed(
                path: "child index \(index)",
                reason: "Tweak addition produced an invalid private key (I_L ≥ n or sum = 0)"
            )
        }

        let childKey = tweaked.dataRepresentation
        guard childKey.count == 32 else {
            throw NostrError.keyDerivationFailed(
                path: "child index \(index)",
                reason: "Derived private key has unexpected length \(childKey.count)"
            )
        }

        return ExtendedKey(
            key: childKey,
            chainCode: ir,
            depth: parent.depth + 1,
            fingerprint: 0,
            childNumber: index
        )
    }
}
