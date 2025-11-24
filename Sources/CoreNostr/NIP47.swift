//
//  NIP47.swift
//  CoreNostr
//
//  Created by Nostr Team on 1/12/25.
//

import Foundation

// MARK: - NWC Methods

/// Supported wallet methods in NIP-47
public enum NWCMethod: String, CaseIterable, Codable, Sendable {
    case payInvoice = "pay_invoice"
    case multiPayInvoice = "multi_pay_invoice"
    case payKeysend = "pay_keysend"
    case multiPayKeysend = "multi_pay_keysend"
    case makeInvoice = "make_invoice"
    case lookupInvoice = "lookup_invoice"
    case listTransactions = "list_transactions"
    case getBalance = "get_balance"
    case getInfo = "get_info"
}

// MARK: - Error Codes

/// Standard error codes defined by NIP-47
public enum NWCErrorCode: String, Codable, Sendable {
    case rateLimited = "RATE_LIMITED"
    case notImplemented = "NOT_IMPLEMENTED"
    case insufficientBalance = "INSUFFICIENT_BALANCE"
    case quotaExceeded = "QUOTA_EXCEEDED"
    case restricted = "RESTRICTED"
    case unauthorized = "UNAUTHORIZED"
    case internalError = "INTERNAL"
    case unsupportedEncryption = "UNSUPPORTED_ENCRYPTION"
    case paymentFailed = "PAYMENT_FAILED"
    case notFound = "NOT_FOUND"
    case other = "OTHER"
}

/// Error structure for NWC responses
public struct NWCError: Codable, Sendable, Error, LocalizedError {
    public let code: NWCErrorCode
    public let message: String
    
    public init(code: NWCErrorCode, message: String) {
        self.code = code
        self.message = message
    }
    
    public var errorDescription: String? {
        return "\(code.rawValue): \(message)"
    }
}

// MARK: - Notification Types

/// Supported notification types in NIP-47
public enum NWCNotificationType: String, Codable, Sendable {
    case paymentReceived = "payment_received"
    case paymentSent = "payment_sent"
}

// MARK: - Encryption Types

/// Supported encryption schemes for NWC
public enum NWCEncryption: String, Codable, Sendable {
    case nip44 = "nip44_v2"
    case nip04 = "nip04"
}

// MARK: - Transaction Types

/// Transaction type (incoming/outgoing)
public enum NWCTransactionType: String, Codable, Sendable {
    case incoming
    case outgoing
}

/// Transaction state
public enum NWCTransactionState: String, Codable, Sendable {
    case pending
    case settled
    case expired
    case failed
}

// MARK: - Request/Response Models

/// Base request structure for NWC
public struct NWCRequest: Codable {
    public let method: NWCMethod
    public let params: [String: AnyCodable]?
    
    public init(method: NWCMethod, params: [String: AnyCodable]? = nil) {
        self.method = method
        self.params = params
    }
}

/// Base response structure for NWC
public struct NWCResponse: Codable {
    public let resultType: String
    public let error: NWCError?
    public let result: [String: AnyCodable]?
    
    public init(resultType: String, error: NWCError? = nil, result: [String: AnyCodable]? = nil) {
        self.resultType = resultType
        self.error = error
        self.result = result
    }
    
    private enum CodingKeys: String, CodingKey {
        case resultType = "result_type"
        case error
        case result
    }
}

/// Notification structure
public struct NWCNotification: Codable {
    public let notificationType: NWCNotificationType
    public let notification: [String: AnyCodable]
    
    public init(notificationType: NWCNotificationType, notification: [String: AnyCodable]) {
        self.notificationType = notificationType
        self.notification = notification
    }
    
    private enum CodingKeys: String, CodingKey {
        case notificationType = "notification_type"
        case notification
    }
}

// MARK: - Transaction Model

/// Transaction/Invoice structure
public struct NWCTransaction: Codable {
    public let type: NWCTransactionType
    public let state: NWCTransactionState?
    public let invoice: String?
    public let description: String?
    public let descriptionHash: String?
    public let preimage: String?
    public let paymentHash: String
    public let amount: Int64 // millisats
    public let feesPaid: Int64?
    public let createdAt: TimeInterval
    public let expiresAt: TimeInterval?
    public let settledAt: TimeInterval?
    public let metadata: [String: AnyCodable]?
    
    public init(
        type: NWCTransactionType,
        state: NWCTransactionState? = nil,
        invoice: String? = nil,
        description: String? = nil,
        descriptionHash: String? = nil,
        preimage: String? = nil,
        paymentHash: String,
        amount: Int64,
        feesPaid: Int64? = nil,
        createdAt: TimeInterval,
        expiresAt: TimeInterval? = nil,
        settledAt: TimeInterval? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.type = type
        self.state = state
        self.invoice = invoice
        self.description = description
        self.descriptionHash = descriptionHash
        self.preimage = preimage
        self.paymentHash = paymentHash
        self.amount = amount
        self.feesPaid = feesPaid
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.settledAt = settledAt
        self.metadata = metadata
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case state
        case invoice
        case description
        case descriptionHash = "description_hash"
        case preimage
        case paymentHash = "payment_hash"
        case amount
        case feesPaid = "fees_paid"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case settledAt = "settled_at"
        case metadata
    }
}

// MARK: - Connection URI

/// NWC Connection URI parser and generator
public struct NWCConnectionURI: Sendable, Codable {
    public let walletPubkey: String
    public let relays: [String]
    public let secret: String
    public let lud16: String?
    
    private static let scheme = "nostr+walletconnect"
    
    public init(walletPubkey: String, relays: [String], secret: String, lud16: String? = nil) {
        self.walletPubkey = walletPubkey
        self.relays = relays
        self.secret = secret
        self.lud16 = lud16
    }
    
    /// Parse a NWC URI string
    public init?(from uriString: String) {
        guard let url = URL(string: uriString),
              url.scheme == Self.scheme,
              let host = url.host else {
            return nil
        }
        
        // The host is the wallet pubkey
        guard host.count == 64, host.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil else {
            return nil
        }
        self.walletPubkey = host.lowercased()
        
        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        var relays: [String] = []
        var secret: String?
        var lud16: String?
        
        for item in queryItems {
            switch item.name {
            case "relay":
                if let value = item.value,
                   let relayURL = URL(string: value),
                   let scheme = relayURL.scheme,
                   scheme == "wss" || scheme == "ws" {
                    relays.append(relayURL.absoluteString)
                }
            case "secret":
                secret = item.value
            case "lud16":
                lud16 = item.value
            default:
                break
            }
        }
        
        // Validate required parameters
        guard !relays.isEmpty,
              let secret = secret,
              secret.count == 64,
              secret.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil else { // 32 bytes hex = 64 chars
            return nil
        }
        
        // Deduplicate relays while preserving order
        var seen: Set<String> = []
        self.relays = relays.filter { seen.insert($0).inserted }
        self.secret = secret.lowercased()
        self.lud16 = lud16
    }
    
    /// Generate URI string from components
    public func toURI() -> String {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = walletPubkey
        
        var queryItems: [URLQueryItem] = []
        
        // Add relays
        for relay in relays {
            queryItems.append(URLQueryItem(name: "relay", value: relay))
        }
        
        // Add secret
        queryItems.append(URLQueryItem(name: "secret", value: secret))
        
        // Add lud16 if present
        if let lud16 = lud16 {
            queryItems.append(URLQueryItem(name: "lud16", value: lud16))
        }
        
        components.queryItems = queryItems
        
        return components.string ?? ""
    }
}

// MARK: - Info Event Helpers

/// Wallet capabilities info
public struct NWCInfo: Sendable, Codable {
    public let methods: Set<NWCMethod>
    public let notifications: Set<NWCNotificationType>
    public let encryptionSchemes: Set<NWCEncryption>
    
    public init(methods: Set<NWCMethod>, 
                notifications: Set<NWCNotificationType> = [],
                encryptionSchemes: Set<NWCEncryption> = [.nip44]) {
        self.methods = methods
        self.notifications = notifications
        self.encryptionSchemes = encryptionSchemes
    }
    
    /// Parse from info event content and tags
    public init?(content: String, tags: [[String]]) {
        // Parse methods from content
        let methodStrings = content.split(separator: " ").map(String.init)
        self.methods = Set(methodStrings.compactMap { NWCMethod(rawValue: $0) })
        
        // Parse encryption schemes from tags
        var encryptionSchemes = Set<NWCEncryption>()
        var notifications = Set<NWCNotificationType>()
        
        for tag in tags {
            guard tag.count >= 2 else { continue }
            
            switch tag[0] {
            case "encryption":
                let schemes = tag[1].split(separator: " ").map(String.init)
                encryptionSchemes = Set(schemes.compactMap { NWCEncryption(rawValue: $0) })
            case "notifications":
                let types = tag[1].split(separator: " ").map(String.init)
                notifications = Set(types.compactMap { NWCNotificationType(rawValue: $0) })
            default:
                break
            }
        }
        
        // Default to NIP-04 if no encryption specified (legacy support)
        if encryptionSchemes.isEmpty {
            encryptionSchemes = [.nip04]
        }
        
        self.encryptionSchemes = encryptionSchemes
        self.notifications = notifications
    }
    
    /// Generate content string for info event
    public func toContent() -> String {
        methods.map { $0.rawValue }.sorted().joined(separator: " ")
    }
    
    /// Generate tags for info event
    public func toTags() -> [[String]] {
        var tags: [[String]] = []
        
        // Add encryption tag
        if !encryptionSchemes.isEmpty {
            let schemes = encryptionSchemes.map { $0.rawValue }.sorted().joined(separator: " ")
            tags.append(["encryption", schemes])
        }
        
        // Add notifications tag
        if !notifications.isEmpty {
            let types = notifications.map { $0.rawValue }.sorted().joined(separator: " ")
            tags.append(["notifications", types])
        }
        
        return tags
    }
}

// MARK: - Event Builders

public extension NostrEvent {
    
    /// Create an NWC info event
    static func nwcInfo(
        methods: Set<NWCMethod>,
        notifications: Set<NWCNotificationType> = [],
        encryptionSchemes: Set<NWCEncryption> = [.nip44],
        pubkey: String,
        privkey: String
    ) throws -> NostrEvent {
        let info = NWCInfo(methods: methods, notifications: notifications, encryptionSchemes: encryptionSchemes)
        
        let event = NostrEvent(
            pubkey: pubkey,
            createdAt: Date(),
            kind: EventKind.nwcInfo.rawValue,
            tags: info.toTags(),
            content: info.toContent()
        )
        
        // Sign the event
        let keyPair = try KeyPair(privateKey: privkey)
        return try keyPair.signEvent(event)
    }
    
    /// Create an NWC request event
    static func nwcRequest(
        method: NWCMethod,
        params: [String: AnyCodable]? = nil,
        walletPubkey: String,
        clientSecret: String,
        encryption: NWCEncryption = .nip44,
        expiration: Date? = nil
    ) throws -> NostrEvent {
        let request = NWCRequest(method: method, params: params)
        let jsonData = try JSONEncoder().encode(request)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Get client pubkey from secret
        let clientKeyPair = try KeyPair(privateKey: clientSecret)
        let clientPubkey = clientKeyPair.publicKey
        
        // Encrypt content based on encryption type
        let encryptedContent: String
        switch encryption {
        case .nip44:
            encryptedContent = try NIP44.encrypt(
                plaintext: jsonString,
                senderPrivateKey: clientSecret,
                recipientPublicKey: walletPubkey
            )
        case .nip04:
            // For legacy NIP-04 support
            encryptedContent = try clientKeyPair.encrypt(message: jsonString, to: walletPubkey)
        }
        
        var tags: [[String]] = [
            ["p", walletPubkey],
            ["encryption", encryption.rawValue]
        ]
        
        // Add expiration if specified
        if let expiration = expiration {
            tags.append(["expiration", String(Int(expiration.timeIntervalSince1970))])
        }
        
        let event = NostrEvent(
            pubkey: clientPubkey,
            createdAt: Date(),
            kind: EventKind.nwcRequest.rawValue,
            tags: tags,
            content: encryptedContent
        )
        
        // Sign the event
        return try clientKeyPair.signEvent(event)
    }
    
    /// Create an NWC response event
    static func nwcResponse(
        requestId: String,
        resultType: String,
        result: [String: AnyCodable]? = nil,
        error: NWCError? = nil,
        clientPubkey: String,
        walletSecret: String,
        encryption: NWCEncryption = .nip44
    ) throws -> NostrEvent {
        let response = NWCResponse(resultType: resultType, error: error, result: result)
        let jsonData = try JSONEncoder().encode(response)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Get wallet pubkey from secret
        let walletKeyPair = try KeyPair(privateKey: walletSecret)
        let walletPubkey = walletKeyPair.publicKey
        
        // Encrypt content
        let encryptedContent: String
        switch encryption {
        case .nip44:
            encryptedContent = try NIP44.encrypt(
                plaintext: jsonString,
                senderPrivateKey: walletSecret,
                recipientPublicKey: clientPubkey
            )
        case .nip04:
            encryptedContent = try walletKeyPair.encrypt(message: jsonString, to: clientPubkey)
        }
        
        var tags: [[String]] = [
            ["p", clientPubkey],
            ["e", requestId]
        ]
        
        if encryption == .nip44 {
            tags.append(["encryption", NWCEncryption.nip44.rawValue])
        } else {
            tags.append(["encryption", NWCEncryption.nip04.rawValue])
        }
        
        let event = NostrEvent(
            pubkey: walletPubkey,
            createdAt: Date(),
            kind: EventKind.nwcResponse.rawValue,
            tags: tags,
            content: encryptedContent
        )
        
        // Sign the event
        return try walletKeyPair.signEvent(event)
    }
    
    /// Create an NWC notification event
    static func nwcNotification(
        type: NWCNotificationType,
        notification: [String: AnyCodable],
        clientPubkey: String,
        walletSecret: String,
        encryption: NWCEncryption = .nip44
    ) throws -> NostrEvent {
        let notif = NWCNotification(notificationType: type, notification: notification)
        let jsonData = try JSONEncoder().encode(notif)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Get wallet pubkey from secret
        let walletKeyPair = try KeyPair(privateKey: walletSecret)
        let walletPubkey = walletKeyPair.publicKey
        
        // Encrypt content
        let encryptedContent: String
        let eventKind: EventKind
        
        switch encryption {
        case .nip44:
            encryptedContent = try NIP44.encrypt(
                plaintext: jsonString,
                senderPrivateKey: walletSecret,
                recipientPublicKey: clientPubkey
            )
            eventKind = .nwcNotification
        case .nip04:
            encryptedContent = try walletKeyPair.encrypt(message: jsonString, to: clientPubkey)
            eventKind = .nwcNotificationLegacy
        }
        
        let tags: [[String]] = [
            ["p", clientPubkey]
        ]
        
        let event = NostrEvent(
            pubkey: walletPubkey,
            createdAt: Date(),
            kind: eventKind.rawValue,
            tags: tags,
            content: encryptedContent
        )
        
        // Sign the event
        return try walletKeyPair.signEvent(event)
    }
    
    /// Decrypt NWC event content
    func decryptNWCContent(with privateKey: String, peerPubkey: String) throws -> String {
        // Check if this is NIP-44 or NIP-04 encrypted
        let isNIP44 = kind == EventKind.nwcNotification.rawValue ||
                      tags.contains { $0.count >= 2 && $0[0] == "encryption" && $0[1] == NWCEncryption.nip44.rawValue }
        
        if isNIP44 {
            return try NIP44.decrypt(
                payload: content,
                recipientPrivateKey: privateKey,
                senderPublicKey: peerPubkey
            )
        } else {
            let keyPair = try KeyPair(privateKey: privateKey)
            return try keyPair.decrypt(message: content, from: peerPubkey)
        }
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for flexible JSON handling
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int64 as Int64:
            try container.encode(int64)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

// MARK: - Specific Request/Response Types

/// Pay invoice request parameters
public struct PayInvoiceParams: Codable, Sendable {
    public let invoice: String
    public let amount: Int64? // optional amount override in millisats
    
    public init(invoice: String, amount: Int64? = nil) {
        self.invoice = invoice
        self.amount = amount
    }
}

/// Pay invoice response result
public struct PayInvoiceResult: Codable, Sendable {
    public let preimage: String
    public let feesPaid: Int64? // millisats
    
    public init(preimage: String, feesPaid: Int64? = nil) {
        self.preimage = preimage
        self.feesPaid = feesPaid
    }
    
    private enum CodingKeys: String, CodingKey {
        case preimage
        case feesPaid = "fees_paid"
    }
}

/// Get balance response result
public struct GetBalanceResult: Codable, Sendable {
    public let balance: Int64 // millisats
    
    public init(balance: Int64) {
        self.balance = balance
    }
}

/// Get info response result
public struct GetInfoResult: Codable, Sendable {
    public let alias: String?
    public let color: String?
    public let pubkey: String?
    public let network: String?
    public let blockHeight: Int?
    public let blockHash: String?
    public let methods: [String]?
    public let notifications: [String]?
    
    public init(
        alias: String? = nil,
        color: String? = nil,
        pubkey: String? = nil,
        network: String? = nil,
        blockHeight: Int? = nil,
        blockHash: String? = nil,
        methods: [String]? = nil,
        notifications: [String]? = nil
    ) {
        self.alias = alias
        self.color = color
        self.pubkey = pubkey
        self.network = network
        self.blockHeight = blockHeight
        self.blockHash = blockHash
        self.methods = methods
        self.notifications = notifications
    }
    
    private enum CodingKeys: String, CodingKey {
        case alias
        case color
        case pubkey
        case network
        case blockHeight = "block_height"
        case blockHash = "block_hash"
        case methods
        case notifications
    }
}
