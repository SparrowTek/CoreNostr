import Foundation
import Crypto

// MARK: - Type Aliases
public typealias EventID = String
public typealias PublicKey = String
public typealias PrivateKey = String
public typealias Signature = String

// MARK: - NostrEvent
public struct NostrEvent: Codable, Hashable, Sendable {
    public let id: EventID
    public let pubkey: PublicKey
    public let createdAt: Int64
    public let kind: Int
    public let tags: [[String]]
    public let content: String
    public let sig: Signature
    
    private enum CodingKeys: String, CodingKey {
        case id, pubkey, kind, tags, content, sig
        case createdAt = "created_at"
    }
    
    public init(
        id: EventID,
        pubkey: PublicKey,
        createdAt: Int64,
        kind: Int,
        tags: [[String]],
        content: String,
        sig: Signature
    ) {
        self.id = id
        self.pubkey = pubkey
        self.createdAt = createdAt
        self.kind = kind
        self.tags = tags
        self.content = content
        self.sig = sig
    }
    
    public init(
        pubkey: PublicKey,
        createdAt: Date = Date(),
        kind: Int,
        tags: [[String]] = [],
        content: String
    ) {
        self.pubkey = pubkey
        self.createdAt = Int64(createdAt.timeIntervalSince1970)
        self.kind = kind
        self.tags = tags
        self.content = content
        self.id = ""
        self.sig = ""
    }
    
    public func serializedForSigning() -> String {
        let array: [Any] = [
            0,
            pubkey,
            createdAt,
            kind,
            tags,
            content
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: array, options: [.withoutEscapingSlashes]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        
        return jsonString
    }
    
    public func calculateId() -> EventID {
        let serialized = serializedForSigning()
        let data = Data(serialized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public func withSignature(_ signature: Signature) -> NostrEvent {
        let id = calculateId()
        return NostrEvent(
            id: id,
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content,
            sig: signature
        )
    }
}

// MARK: - Event Kinds
public enum EventKind: Int, CaseIterable, Sendable {
    case setMetadata = 0
    case textNote = 1
    case recommendServer = 2
    
    public var description: String {
        switch self {
        case .setMetadata: return "Set Metadata"
        case .textNote: return "Text Note"
        case .recommendServer: return "Recommend Server"
        }
    }
}

// MARK: - Filter
public struct Filter: Codable, Sendable {
    public var ids: [EventID]?
    public var authors: [PublicKey]?
    public var kinds: [Int]?
    public var since: Int64?
    public var until: Int64?
    public var limit: Int?
    public var e: [String]?
    public var p: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case ids, authors, kinds, since, until, limit
        case e = "#e"
        case p = "#p"
    }
    
    public init(
        ids: [EventID]? = nil,
        authors: [PublicKey]? = nil,
        kinds: [Int]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil,
        e: [String]? = nil,
        p: [String]? = nil
    ) {
        self.ids = ids
        self.authors = authors
        self.kinds = kinds
        self.since = since.map { Int64($0.timeIntervalSince1970) }
        self.until = until.map { Int64($0.timeIntervalSince1970) }
        self.limit = limit
        self.e = e
        self.p = p
    }
}

// MARK: - Errors
public enum NostrError: Error, LocalizedError, Sendable {
    case invalidEvent(String)
    case cryptographyError(String)
    case networkError(String)
    case serializationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidEvent(let message):
            return "Invalid event: \(message)"
        case .cryptographyError(let message):
            return "Cryptography error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serializationError(let message):
            return "Serialization error: \(message)"
        }
    }
}