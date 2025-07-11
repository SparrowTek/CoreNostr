import Foundation
import Crypto
import P256K

// MARK: - KeyPair
public struct KeyPair: Sendable, Codable {
    public let privateKey: PrivateKey
    public let publicKey: PublicKey
    
    public init(privateKey: PrivateKey) throws {
        self.privateKey = privateKey
        
        guard let privateKeyData = Data(hex: privateKey) else {
            throw NostrError.cryptographyError("Invalid private key format")
        }
        
        let p256kPrivateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyData)
        let publicKeyData = Data(p256kPrivateKey.xonly.bytes)
        self.publicKey = publicKeyData.hex
    }
    
    public static func generate() throws -> KeyPair {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let privateKeyHex = privateKey.dataRepresentation.hex
        return try KeyPair(privateKey: privateKeyHex)
    }
    
    public func sign(_ data: Data) throws -> Signature {
        guard let privateKeyData = Data(hex: privateKey) else {
            throw NostrError.cryptographyError("Invalid private key format")
        }
        
        let p256kPrivateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyData)
        let signature = try p256kPrivateKey.signature(for: data)
        return signature.dataRepresentation.hex
    }
    
    public func signEvent(_ event: NostrEvent) throws -> NostrEvent {
        let serializedEvent = event.serializedForSigning()
        let eventData = Data(serializedEvent.utf8)
        let signature = try sign(eventData)
        return event.withSignature(signature)
    }
    
    public static func verify(signature: Signature, data: Data, publicKey: PublicKey) throws -> Bool {
        guard let publicKeyData = Data(hex: publicKey),
              let signatureData = Data(hex: signature) else {
            throw NostrError.cryptographyError("Invalid key or signature format")
        }
        
        let p256kPublicKey = P256K.Schnorr.XonlyKey(dataRepresentation: publicKeyData)
        let schnorrSignature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: signatureData)
        
        return p256kPublicKey.isValidSignature(schnorrSignature, for: data)
    }
    
    public static func verifyEvent(_ event: NostrEvent) throws -> Bool {
        let serializedEvent = event.serializedForSigning()
        let eventData = Data(serializedEvent.utf8)
        
        // Verify the event ID matches
        let calculatedId = event.calculateId()
        guard calculatedId == event.id else {
            throw NostrError.invalidEvent("Event ID mismatch")
        }
        
        // Verify the signature
        return try verify(signature: event.sig, data: eventData, publicKey: event.pubkey)
    }
}

// MARK: - Data Extensions
extension Data {
    init?(hex: String) {
        let cleanHex = hex.replacingOccurrences(of: " ", with: "")
        guard cleanHex.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: cleanHex.count / 2)
        var index = cleanHex.startIndex
        
        for _ in 0..<cleanHex.count / 2 {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    var hex: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Utility Functions
public struct NostrCrypto {
    public static func generateEventId(for event: NostrEvent) -> EventID {
        return event.calculateId()
    }
    
    public static func isValidEventId(_ id: EventID) -> Bool {
        return id.count == 64 && id.allSatisfy { $0.isHexDigit }
    }
    
    public static func isValidPublicKey(_ key: PublicKey) -> Bool {
        return key.count == 64 && key.allSatisfy { $0.isHexDigit }
    }
    
    public static func isValidPrivateKey(_ key: PrivateKey) -> Bool {
        return key.count == 64 && key.allSatisfy { $0.isHexDigit }
    }
    
    public static func isValidSignature(_ signature: Signature) -> Bool {
        return signature.count == 128 && signature.allSatisfy { $0.isHexDigit }
    }
}