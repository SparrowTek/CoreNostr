//
//  NostrNIP05.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// A NIP-05 internet identifier for mapping Nostr keys to DNS-based identifiers.
///
/// NIP-05 provides a way to map human-readable internet identifiers (like email addresses)
/// to Nostr public keys through DNS-based verification using well-known JSON endpoints.
///
/// ## Example
/// ```swift
/// let identifier = try NostrNIP05Identifier(identifier: "bob@example.com")
/// print(identifier.localPart) // "bob"
/// print(identifier.domain) // "example.com"
/// 
/// let verifier = NostrNIP05Verifier()
/// let isValid = try await verifier.verify(identifier: identifier, publicKey: pubkey)
/// ```
///
/// ## Usage Notes
/// - NIP-05 is for identification, not verification (except for domain owners)
/// - Clients should always follow public keys, not NIP-05 addresses
/// - The `_@domain` format represents the "root" identifier for a domain
public struct NostrNIP05Identifier: Codable, Hashable, Sendable {
    /// The local part of the identifier (before the @)
    public let localPart: String
    
    /// The domain part of the identifier (after the @)
    public let domain: String
    
    /// The full identifier string
    public var identifier: String {
        return "\(localPart)@\(domain)"
    }
    
    /// Whether this is a root identifier (_@domain)
    public var isRootIdentifier: Bool {
        return localPart == "_"
    }
    
    /// The display identifier (shows just domain for root identifiers)
    public var displayIdentifier: String {
        return isRootIdentifier ? domain : identifier
    }
    
    /// Creates a NIP-05 identifier from a string.
    ///
    /// - Parameter identifier: The identifier string in format "local@domain"
    /// - Throws: ``NostrError/invalidEvent(reason:)`` if the identifier format is invalid
    public init(identifier: String) throws {
        let components = identifier.split(separator: "@", maxSplits: 1)
        guard components.count == 2 else {
            throw NostrError.invalidNIP05(identifier: identifier, reason: "Must be in format 'name@domain.com' or '_@domain.com'")
        }
        
        let localPart = String(components[0]).lowercased()
        let domain = String(components[1]).lowercased()
        
        // Validate local part contains only allowed characters
        let allowedLocalChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.")
        guard localPart.unicodeScalars.allSatisfy({ allowedLocalChars.contains($0) }) else {
            throw NostrError.invalidNIP05(identifier: identifier, reason: "Local part contains invalid characters")
        }
        
        // Basic domain validation
        guard !domain.isEmpty,
              domain.contains("."),
              !domain.hasPrefix("."),
              !domain.hasSuffix(".") else {
            throw NostrError.invalidNIP05(identifier: identifier, reason: "Domain format is invalid")
        }
        
        self.localPart = localPart
        self.domain = domain
    }
    
    /// Creates a NIP-05 identifier from local and domain parts.
    ///
    /// - Parameters:
    ///   - localPart: The local part (before @)
    ///   - domain: The domain part (after @)
    /// - Throws: ``NostrError/invalidEvent(reason:)`` if the parts are invalid
    public init(localPart: String, domain: String) throws {
        try self.init(identifier: "\(localPart)@\(domain)")
    }
    
    /// The well-known URL for this identifier.
    public var wellKnownURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/.well-known/nostr.json"
        components.queryItems = [URLQueryItem(name: "name", value: localPart)]
        return components.url
    }
}

/// The response structure from a NIP-05 well-known JSON endpoint.
public struct NostrNIP05Response: Codable, Sendable {
    /// Mapping of names to public keys
    public let names: [String: PublicKey]
    
    /// Optional mapping of public keys to relay URLs
    public let relays: [PublicKey: [String]]?
    
    /// Creates a NIP-05 response.
    ///
    /// - Parameters:
    ///   - names: Mapping of names to public keys
    ///   - relays: Optional mapping of public keys to relay URLs
    public init(names: [String: PublicKey], relays: [PublicKey: [String]]? = nil) {
        self.names = names
        self.relays = relays
    }
    
    /// Gets the public key for a given name.
    ///
    /// - Parameter name: The local part to look up
    /// - Returns: The public key if found, nil otherwise
    public func publicKey(for name: String) -> PublicKey? {
        return names[name.lowercased()]
    }
    
    /// Gets the relay URLs for a given public key.
    ///
    /// - Parameter publicKey: The public key to look up
    /// - Returns: Array of relay URLs, or empty array if none found
    public func relayURLs(for publicKey: PublicKey) -> [String] {
        return relays?[publicKey] ?? []
    }
}

/// A verifier for NIP-05 identifiers.
///
/// This class handles the verification process of NIP-05 identifiers by fetching
/// the well-known JSON endpoint and validating the mapping.
public final class NostrNIP05Verifier: Sendable {
    private let urlSession: URLSession
    private let timeout: TimeInterval
    
    /// Creates a new NIP-05 verifier.
    ///
    /// - Parameters:
    ///   - urlSession: The URL session to use for requests (defaults to shared)
    ///   - timeout: Request timeout in seconds (defaults to 10)
    public init(urlSession: URLSession = .shared, timeout: TimeInterval = 10) {
        self.urlSession = urlSession
        self.timeout = timeout
    }
    
    /// Verifies a NIP-05 identifier against a public key.
    ///
    /// This method fetches the well-known JSON endpoint and checks if the identifier
    /// maps to the given public key.
    ///
    /// - Parameters:
    ///   - identifier: The NIP-05 identifier to verify
    ///   - publicKey: The public key to verify against
    /// - Returns: True if the identifier is valid for the public key
    /// - Throws: Network or parsing errors
    public func verify(identifier: NostrNIP05Identifier, publicKey: PublicKey) async throws -> Bool {
        let response = try await fetchWellKnownResponse(for: identifier)
        return response.publicKey(for: identifier.localPart) == publicKey
    }
    
    /// Discovers a public key from a NIP-05 identifier.
    ///
    /// This method fetches the well-known JSON endpoint and returns the public key
    /// mapped to the identifier.
    ///
    /// - Parameter identifier: The NIP-05 identifier to discover
    /// - Returns: The public key if found, nil otherwise
    /// - Throws: Network or parsing errors
    public func discoverPublicKey(for identifier: NostrNIP05Identifier) async throws -> PublicKey? {
        let response = try await fetchWellKnownResponse(for: identifier)
        return response.publicKey(for: identifier.localPart)
    }
    
    /// Fetches the well-known JSON response for an identifier.
    ///
    /// - Parameter identifier: The NIP-05 identifier
    /// - Returns: The parsed well-known response
    /// - Throws: Network or parsing errors
    public func fetchWellKnownResponse(for identifier: NostrNIP05Identifier) async throws -> NostrNIP05Response {
        guard let url = identifier.wellKnownURL else {
            throw NostrError.invalidURI(uri: identifier.identifier, reason: "Failed to construct well-known URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
        request.timeoutInterval = timeout
        
        let (data, response) = try await urlSession.data(for: request)
        
        // Check for HTTP errors
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw NostrError.networkError(operation: .receive, reason: "HTTP error \(httpResponse.statusCode) from well-known endpoint")
            }
            
            // Security constraint: no redirects allowed
            if httpResponse.url != url {
                throw NostrError.networkError(operation: .receive, reason: "Redirects not allowed for well-known endpoints per NIP-05")
            }
        }
        
        // Parse JSON response
        do {
            return try JSONDecoder().decode(NostrNIP05Response.self, from: data)
        } catch {
            throw NostrError.serializationError(type: "NIP-05 well-known response", reason: "Failed to parse JSON: \(error.localizedDescription)")
        }
    }
}

/// A discovery service for finding users by NIP-05 identifiers.
public final class NostrNIP05Discovery: Sendable {
    private let verifier: NostrNIP05Verifier
    
    /// Creates a new NIP-05 discovery service.
    ///
    /// - Parameter verifier: The verifier to use (defaults to new instance)
    public init(verifier: NostrNIP05Verifier = NostrNIP05Verifier()) {
        self.verifier = verifier
    }
    
    /// Discovers a user's information from their NIP-05 identifier.
    ///
    /// This method performs the reverse lookup: it fetches the well-known JSON
    /// to get the public key, then can be used to find the user's metadata event.
    ///
    /// - Parameter identifier: The NIP-05 identifier to discover
    /// - Returns: Discovery result with public key and optional relay URLs
    /// - Throws: Network or parsing errors
    public func discover(identifier: NostrNIP05Identifier) async throws -> NostrNIP05DiscoveryResult? {
        let response = try await verifier.fetchWellKnownResponse(for: identifier)
        
        guard let publicKey = response.publicKey(for: identifier.localPart) else {
            return nil
        }
        
        let relayURLs = response.relayURLs(for: publicKey)
        
        return NostrNIP05DiscoveryResult(
            identifier: identifier,
            publicKey: publicKey,
            relayURLs: relayURLs
        )
    }
}

/// The result of a NIP-05 discovery operation.
public struct NostrNIP05DiscoveryResult: Codable, Hashable, Sendable {
    /// The NIP-05 identifier that was discovered
    public let identifier: NostrNIP05Identifier
    
    /// The public key associated with the identifier
    public let publicKey: PublicKey
    
    /// Optional relay URLs where the user can be found
    public let relayURLs: [String]
    
    /// Creates a discovery result.
    ///
    /// - Parameters:
    ///   - identifier: The NIP-05 identifier
    ///   - publicKey: The associated public key
    ///   - relayURLs: Optional relay URLs
    public init(identifier: NostrNIP05Identifier, publicKey: PublicKey, relayURLs: [String] = []) {
        self.identifier = identifier
        self.publicKey = publicKey
        self.relayURLs = relayURLs
    }
}

// MARK: - Extensions

extension NostrNIP05Identifier: CustomStringConvertible {
    public var description: String {
        return displayIdentifier
    }
}

extension NostrNIP05Identifier: ExpressibleByStringLiteral {
    /// Creates a NIP-05 identifier from a string literal.
    ///
    /// - Important: This initializer is intended for compile-time string literals only.
    ///   Invalid identifiers will cause a fatal error. For runtime string parsing,
    ///   use `init(identifier:)` which throws on invalid input.
    ///
    /// - Parameter value: A valid NIP-05 identifier string (e.g., "user@example.com")
    public init(stringLiteral value: String) {
        do {
            try self.init(identifier: value)
        } catch {
            fatalError("Invalid NIP-05 identifier literal '\(value)': \(error.localizedDescription). Use init(identifier:) for runtime parsing.")
        }
    }
}

