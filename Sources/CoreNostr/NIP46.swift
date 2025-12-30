//
//  NIP46.swift
//  CoreNostr
//
//  NIP-46: Nostr Remote Signing
//  https://github.com/nostr-protocol/nips/blob/master/46.md
//

import Foundation

/// NIP-46: Nostr Remote Signing
///
/// This module provides types and utilities for implementing remote signing,
/// allowing applications to request cryptographic operations from a remote signer
/// (bunker) without exposing private keys to the client application.
public enum NIP46 {
    
    // MARK: - Connection URIs
    
    /// A bunker connection URI provided by a remote signer.
    ///
    /// Format: `bunker://<remote-signer-pubkey>?relay=<relay>&secret=<secret>`
    ///
    /// Used when the remote signer initiates the connection by providing
    /// credentials to the client.
    public struct BunkerURI: Sendable, Equatable {
        /// The remote signer's public key (hex format).
        public let signerPubkey: String
        
        /// Relay URLs for communication.
        public let relays: [String]
        
        /// Optional secret for connection authentication.
        public let secret: String?
        
        /// Initializes from a bunker:// URI string.
        ///
        /// - Parameter uri: The bunker URI string
        /// - Returns: nil if the URI is invalid
        public init?(from uri: String) {
            // Normalize the URI - handle both bunker:// and bunker: prefixes
            let normalized: String
            if uri.hasPrefix("bunker://") {
                normalized = uri
            } else if uri.hasPrefix("bunker:") {
                normalized = "bunker://" + uri.dropFirst("bunker:".count)
            } else {
                return nil
            }
            
            guard let components = URLComponents(string: normalized),
                  components.scheme == "bunker",
                  let host = components.host,
                  host.count == 64 else {
                return nil
            }
            
            self.signerPubkey = host
            
            // Parse relay URLs
            var relays: [String] = []
            if let queryItems = components.queryItems {
                for item in queryItems where item.name == "relay" {
                    if let relay = item.value, !relay.isEmpty {
                        relays.append(relay)
                    }
                }
                self.secret = queryItems.first { $0.name == "secret" }?.value
            } else {
                self.secret = nil
            }
            
            guard !relays.isEmpty else {
                return nil
            }
            
            self.relays = relays
        }
        
        /// Creates a BunkerURI directly.
        public init(signerPubkey: String, relays: [String], secret: String? = nil) {
            self.signerPubkey = signerPubkey
            self.relays = relays
            self.secret = secret
        }
    }
    
    /// A nostrconnect URI created by the client for the signer to connect to.
    ///
    /// Format: `nostrconnect://<client-pubkey>?relay=<relay>&secret=<secret>&name=<name>`
    ///
    /// Used when the client initiates the connection and waits for the signer
    /// to respond.
    public struct NostrConnectURI: Sendable, Equatable {
        /// The client's public key (hex format).
        public let clientPubkey: String
        
        /// Relay URLs where the client is listening.
        public let relays: [String]
        
        /// Required secret that the signer must return in its response.
        public let secret: String
        
        /// Optional requested permissions (comma-separated).
        public let permissions: String?
        
        /// Optional client application name.
        public let name: String?
        
        /// Optional client application URL.
        public let url: String?
        
        /// Optional client application image URL.
        public let image: String?
        
        /// Creates a NostrConnectURI.
        public init(
            clientPubkey: String,
            relays: [String],
            secret: String,
            permissions: String? = nil,
            name: String? = nil,
            url: String? = nil,
            image: String? = nil
        ) {
            self.clientPubkey = clientPubkey
            self.relays = relays
            self.secret = secret
            self.permissions = permissions
            self.name = name
            self.url = url
            self.image = image
        }
        
        /// Generates the URI string.
        public func toString() -> String {
            var components = URLComponents()
            components.scheme = "nostrconnect"
            components.host = clientPubkey
            
            var queryItems: [URLQueryItem] = []
            
            for relay in relays {
                queryItems.append(URLQueryItem(name: "relay", value: relay))
            }
            
            queryItems.append(URLQueryItem(name: "secret", value: secret))
            
            if let permissions = permissions {
                queryItems.append(URLQueryItem(name: "perms", value: permissions))
            }
            if let name = name {
                queryItems.append(URLQueryItem(name: "name", value: name))
            }
            if let url = url {
                queryItems.append(URLQueryItem(name: "url", value: url))
            }
            if let image = image {
                queryItems.append(URLQueryItem(name: "image", value: image))
            }
            
            components.queryItems = queryItems
            
            return components.string ?? ""
        }
        
        /// Parses a nostrconnect:// URI string.
        public init?(from uri: String) {
            guard uri.hasPrefix("nostrconnect://") else { return nil }
            
            guard let components = URLComponents(string: uri),
                  components.scheme == "nostrconnect",
                  let host = components.host,
                  host.count == 64 else {
                return nil
            }
            
            self.clientPubkey = host
            
            guard let queryItems = components.queryItems else { return nil }
            
            var relays: [String] = []
            var secret: String?
            var permissions: String?
            var name: String?
            var url: String?
            var image: String?
            
            for item in queryItems {
                switch item.name {
                case "relay":
                    if let value = item.value, !value.isEmpty {
                        relays.append(value)
                    }
                case "secret":
                    secret = item.value
                case "perms":
                    permissions = item.value
                case "name":
                    name = item.value
                case "url":
                    url = item.value
                case "image":
                    image = item.value
                default:
                    break
                }
            }
            
            guard !relays.isEmpty, let secretValue = secret, !secretValue.isEmpty else {
                return nil
            }
            
            self.relays = relays
            self.secret = secretValue
            self.permissions = permissions
            self.name = name
            self.url = url
            self.image = image
        }
    }
    
    // MARK: - Methods
    
    /// NIP-46 remote signing methods.
    public enum Method: String, Sendable, Codable, CaseIterable {
        /// Establish connection with the remote signer.
        case connect = "connect"
        
        /// Sign a Nostr event.
        case signEvent = "sign_event"
        
        /// Ping to check if signer is responsive.
        case ping = "ping"
        
        /// Get the user's public key.
        case getPublicKey = "get_public_key"
        
        /// Encrypt using NIP-04.
        case nip04Encrypt = "nip04_encrypt"
        
        /// Decrypt using NIP-04.
        case nip04Decrypt = "nip04_decrypt"
        
        /// Encrypt using NIP-44.
        case nip44Encrypt = "nip44_encrypt"
        
        /// Decrypt using NIP-44.
        case nip44Decrypt = "nip44_decrypt"
    }
    
    // MARK: - Request/Response
    
    /// A request to the remote signer.
    public struct Request: Sendable, Codable {
        /// Unique request identifier.
        public let id: String
        
        /// The method to invoke.
        public let method: String
        
        /// Positional parameters for the method.
        public let params: [String]
        
        /// Creates a new request.
        public init(id: String = UUID().uuidString, method: Method, params: [String] = []) {
            self.id = id
            self.method = method.rawValue
            self.params = params
        }
        
        /// Creates a request with a raw method string.
        public init(id: String = UUID().uuidString, methodString: String, params: [String] = []) {
            self.id = id
            self.method = methodString
            self.params = params
        }
    }
    
    /// A response from the remote signer.
    public struct Response: Sendable, Codable {
        /// The request ID this response corresponds to.
        public let id: String
        
        /// The result string (interpretation depends on method).
        public let result: String?
        
        /// Error message if the request failed.
        public let error: String?
        
        /// Whether this is an auth_url challenge.
        public var isAuthChallenge: Bool {
            result == "auth_url" && error != nil
        }
        
        /// The auth URL if this is an auth challenge.
        public var authURL: URL? {
            guard isAuthChallenge, let urlString = error else { return nil }
            return URL(string: urlString)
        }
        
        /// Creates a successful response.
        public static func success(id: String, result: String) -> Response {
            Response(id: id, result: result, error: nil)
        }
        
        /// Creates an error response.
        public static func failure(id: String, error: String) -> Response {
            Response(id: id, result: nil, error: error)
        }
        
        /// Creates an auth challenge response.
        public static func authChallenge(id: String, url: String) -> Response {
            Response(id: id, result: "auth_url", error: url)
        }
    }
    
    // MARK: - Unsigned Event for Signing
    
    /// An unsigned event to be sent for remote signing.
    ///
    /// Contains only the fields needed for signing, without id, pubkey, or sig.
    public struct UnsignedEvent: Sendable, Codable {
        public let kind: Int
        public let content: String
        public let tags: [[String]]
        public let created_at: Int64
        
        public init(kind: Int, content: String, tags: [[String]], createdAt: Date = Date()) {
            self.kind = kind
            self.content = content
            self.tags = tags
            self.created_at = Int64(createdAt.timeIntervalSince1970)
        }
        
        /// Creates from a NostrEvent (strips id, pubkey, sig).
        public init(from event: NostrEvent) {
            self.kind = event.kind
            self.content = event.content
            self.tags = event.tags
            self.created_at = event.createdAt
        }
        
        /// JSON string representation for sending to signer.
        public func toJSON() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(self)
            guard let json = String(data: data, encoding: .utf8) else {
                throw NIP46Error.serializationFailed
            }
            return json
        }
    }
    
    // MARK: - Errors
    
    /// Errors that can occur during NIP-46 operations.
    public enum NIP46Error: LocalizedError, Sendable {
        case invalidURI
        case connectionFailed(String)
        case signingFailed(String)
        case encryptionFailed(String)
        case decryptionFailed(String)
        case timeout
        case unauthorized
        case methodNotSupported(String)
        case invalidResponse
        case serializationFailed
        case authRequired(URL)
        case secretMismatch
        case signerDisconnected
        
        public var errorDescription: String? {
            switch self {
            case .invalidURI:
                return "Invalid bunker or nostrconnect URI"
            case .connectionFailed(let reason):
                return "Connection failed: \(reason)"
            case .signingFailed(let reason):
                return "Signing failed: \(reason)"
            case .encryptionFailed(let reason):
                return "Encryption failed: \(reason)"
            case .decryptionFailed(let reason):
                return "Decryption failed: \(reason)"
            case .timeout:
                return "Request timed out"
            case .unauthorized:
                return "Not authorized to perform this operation"
            case .methodNotSupported(let method):
                return "Method not supported: \(method)"
            case .invalidResponse:
                return "Invalid response from remote signer"
            case .serializationFailed:
                return "Failed to serialize request"
            case .authRequired(let url):
                return "Authentication required at: \(url)"
            case .secretMismatch:
                return "Connection secret mismatch"
            case .signerDisconnected:
                return "Remote signer disconnected"
            }
        }
    }
    
    // MARK: - Permissions
    
    /// Represents a permission request for a specific method.
    public struct Permission: Sendable, Equatable {
        /// The method being permitted.
        public let method: Method
        
        /// Optional kind restriction for sign_event.
        public let kind: Int?
        
        public init(method: Method, kind: Int? = nil) {
            self.method = method
            self.kind = kind
        }
        
        /// Parses a permission string (e.g., "sign_event:1" or "nip44_encrypt").
        public init?(from string: String) {
            let parts = string.split(separator: ":")
            guard let methodPart = parts.first,
                  let method = Method(rawValue: String(methodPart)) else {
                return nil
            }
            
            self.method = method
            
            if parts.count > 1, let kindValue = Int(parts[1]) {
                self.kind = kindValue
            } else {
                self.kind = nil
            }
        }
        
        /// String representation for transmission.
        public func toString() -> String {
            if let kind = kind {
                return "\(method.rawValue):\(kind)"
            }
            return method.rawValue
        }
    }
    
    /// Parses a comma-separated permissions string.
    public static func parsePermissions(_ string: String) -> [Permission] {
        string.split(separator: ",")
            .compactMap { Permission(from: String($0).trimmingCharacters(in: .whitespaces)) }
    }
    
    /// Formats permissions as a comma-separated string.
    public static func formatPermissions(_ permissions: [Permission]) -> String {
        permissions.map { $0.toString() }.joined(separator: ",")
    }
    
    // MARK: - Event Creation Helpers
    
    /// Creates a NIP-46 request event.
    ///
    /// - Parameters:
    ///   - request: The request to send
    ///   - signerPubkey: The remote signer's public key
    ///   - clientSecret: The client's private key for encryption
    /// - Returns: A signed NostrEvent ready to publish
    public static func createRequestEvent(
        request: Request,
        signerPubkey: String,
        clientKeyPair: KeyPair
    ) throws -> NostrEvent {
        // Serialize request to JSON
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        guard let requestJSON = String(data: requestData, encoding: .utf8) else {
            throw NIP46Error.serializationFailed
        }
        
        // Encrypt with NIP-44
        let encryptedContent = try NIP44.encrypt(
            plaintext: requestJSON,
            senderPrivateKey: clientKeyPair.privateKey,
            recipientPublicKey: signerPubkey
        )
        
        // Create and sign event
        let event = NostrEvent(
            pubkey: clientKeyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.remoteSigningRequest.rawValue,
            tags: [["p", signerPubkey]],
            content: encryptedContent
        )
        
        return try clientKeyPair.signEvent(event)
    }
    
    /// Decrypts and parses a NIP-46 response from an event.
    ///
    /// - Parameters:
    ///   - event: The response event
    ///   - clientSecret: The client's private key for decryption
    ///   - signerPubkey: The signer's public key
    /// - Returns: The parsed response
    public static func parseResponseEvent(
        event: NostrEvent,
        clientSecret: String,
        signerPubkey: String
    ) throws -> Response {
        // Decrypt content
        let decrypted = try NIP44.decrypt(
            payload: event.content,
            recipientPrivateKey: clientSecret,
            senderPublicKey: signerPubkey
        )
        
        // Parse response
        guard let data = decrypted.data(using: .utf8) else {
            throw NIP46Error.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Response.self, from: data)
    }
    
    // MARK: - Request Builders
    
    /// Creates a connect request.
    public static func connectRequest(
        signerPubkey: String,
        secret: String? = nil,
        permissions: [Permission]? = nil
    ) -> Request {
        var params = [signerPubkey]
        
        if let secret = secret {
            params.append(secret)
        } else if permissions != nil {
            params.append("") // Empty secret placeholder
        }
        
        if let permissions = permissions {
            params.append(formatPermissions(permissions))
        }
        
        return Request(method: .connect, params: params)
    }
    
    /// Creates a sign_event request.
    public static func signEventRequest(event: UnsignedEvent) throws -> Request {
        let json = try event.toJSON()
        return Request(method: .signEvent, params: [json])
    }
    
    /// Creates a get_public_key request.
    public static func getPublicKeyRequest() -> Request {
        Request(method: .getPublicKey)
    }
    
    /// Creates a ping request.
    public static func pingRequest() -> Request {
        Request(method: .ping)
    }
    
    /// Creates a NIP-04 encrypt request.
    public static func nip04EncryptRequest(thirdPartyPubkey: String, plaintext: String) -> Request {
        Request(method: .nip04Encrypt, params: [thirdPartyPubkey, plaintext])
    }
    
    /// Creates a NIP-04 decrypt request.
    public static func nip04DecryptRequest(thirdPartyPubkey: String, ciphertext: String) -> Request {
        Request(method: .nip04Decrypt, params: [thirdPartyPubkey, ciphertext])
    }
    
    /// Creates a NIP-44 encrypt request.
    public static func nip44EncryptRequest(thirdPartyPubkey: String, plaintext: String) -> Request {
        Request(method: .nip44Encrypt, params: [thirdPartyPubkey, plaintext])
    }
    
    /// Creates a NIP-44 decrypt request.
    public static func nip44DecryptRequest(thirdPartyPubkey: String, ciphertext: String) -> Request {
        Request(method: .nip44Decrypt, params: [thirdPartyPubkey, ciphertext])
    }
}
