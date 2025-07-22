//
//  NIP42.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// NIP-42: Authentication of clients to relays
/// https://github.com/nostr-protocol/nips/blob/master/42.md
///
/// Defines a way for clients to authenticate to relays by signing an ephemeral event.

// MARK: - Authentication Challenge

/// Represents a challenge sent by a relay for authentication
public struct AuthChallenge: Sendable {
    /// The challenge string from the relay
    public let challenge: String
    
    /// The relay URL that sent the challenge
    public let relayURL: String
    
    /// When the challenge was received
    public let receivedAt: Date
    
    /// Initialize an authentication challenge
    public init(challenge: String, relayURL: String, receivedAt: Date = Date()) {
        self.challenge = challenge
        self.relayURL = relayURL
        self.receivedAt = receivedAt
    }
    
    /// Check if the challenge is still valid (within 10 minutes)
    public var isValid: Bool {
        Date().timeIntervalSince(receivedAt) < 600 // 10 minutes
    }
}

// MARK: - Authentication Response

/// Represents an authentication response to a relay challenge
public struct AuthResponse: Sendable {
    /// The signed authentication event
    public let event: NostrEvent
    
    /// The challenge this is responding to
    public let challenge: AuthChallenge
    
    /// Initialize from a signed event and challenge
    public init?(event: NostrEvent, challenge: AuthChallenge) {
        guard event.kind == EventKind.clientAuthentication.rawValue else { return nil }
        
        // Verify the event has required tags
        let hasRelayTag = event.tags.contains { $0.count >= 2 && $0[0] == "relay" }
        let hasChallengeTag = event.tags.contains { $0.count >= 2 && $0[0] == "challenge" }
        
        guard hasRelayTag && hasChallengeTag else { return nil }
        
        self.event = event
        self.challenge = challenge
    }
}

// MARK: - Authentication Error

/// Errors that can occur during authentication
public enum AuthenticationError: LocalizedError, Sendable {
    case invalidChallenge
    case challengeExpired
    case invalidRelayURL
    case signingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidChallenge:
            return "Invalid authentication challenge"
        case .challengeExpired:
            return "Authentication challenge has expired"
        case .invalidRelayURL:
            return "Invalid relay URL"
        case .signingFailed:
            return "Failed to sign authentication event"
        }
    }
}

// MARK: - CoreNostr Extensions

public extension CoreNostr {
    /// Create an authentication event in response to a relay challenge
    static func createAuthenticationEvent(
        challenge: AuthChallenge,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        // Verify challenge is still valid
        guard challenge.isValid else {
            throw AuthenticationError.challengeExpired
        }
        
        // Normalize relay URL
        let normalizedURL = normalizeRelayURL(challenge.relayURL)
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.clientAuthentication.rawValue,
            tags: [
                ["relay", normalizedURL],
                ["challenge", challenge.challenge]
            ],
            content: ""
        )
        
        return try keyPair.signEvent(event)
    }
    
    /// Create an authentication response for a challenge
    static func authenticate(
        challenge: AuthChallenge,
        keyPair: KeyPair
    ) throws -> AuthResponse {
        let event = try createAuthenticationEvent(challenge: challenge, keyPair: keyPair)
        
        guard let response = AuthResponse(event: event, challenge: challenge) else {
            throw AuthenticationError.signingFailed
        }
        
        return response
    }
    
    /// Normalize a relay URL for comparison
    static func normalizeRelayURL(_ url: String) -> String {
        var normalized = url.lowercased()
        
        // Ensure wss:// or ws:// prefix
        if !normalized.hasPrefix("wss://") && !normalized.hasPrefix("ws://") {
            normalized = "wss://" + normalized
        }
        
        // Remove trailing slash
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
}

// MARK: - NostrEvent Extensions

public extension NostrEvent {
    /// Check if this is an authentication event
    var isAuthenticationEvent: Bool {
        kind == EventKind.clientAuthentication.rawValue
    }
    
    /// Parse authentication details from this event
    func parseAuthentication() -> (relayURL: String, challenge: String)? {
        guard isAuthenticationEvent else { return nil }
        
        guard let relayTag = tags.first(where: { $0.count >= 2 && $0[0] == "relay" }),
              let challengeTag = tags.first(where: { $0.count >= 2 && $0[0] == "challenge" }) else {
            return nil
        }
        
        return (relayTag[1], challengeTag[1])
    }
    
    /// Verify this authentication event against a challenge
    func verifyAuthentication(against challenge: AuthChallenge) -> Bool {
        guard let (relayURL, eventChallenge) = parseAuthentication() else {
            return false
        }
        
        // Check challenge matches
        guard eventChallenge == challenge.challenge else {
            return false
        }
        
        // Check relay URL matches (with normalization)
        let normalizedChallengeURL = CoreNostr.normalizeRelayURL(challenge.relayURL)
        let normalizedEventURL = CoreNostr.normalizeRelayURL(relayURL)
        
        // For most cases, just checking domain should be enough
        guard extractDomain(from: normalizedChallengeURL) == extractDomain(from: normalizedEventURL) else {
            return false
        }
        
        // Check timestamp is recent (within 10 minutes)
        let eventDate = Date(timeIntervalSince1970: TimeInterval(createdAt))
        guard abs(eventDate.timeIntervalSinceNow) < 600 else {
            return false
        }
        
        return true
    }
    
    private func extractDomain(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        return url.host
    }
}

// MARK: - Authentication Status

/// Represents the authentication status with a relay
public enum AuthenticationStatus: Sendable {
    /// Not authenticated
    case notAuthenticated
    
    /// Authentication required by relay
    case authenticationRequired(challenge: AuthChallenge)
    
    /// Authentication in progress
    case authenticating
    
    /// Successfully authenticated
    case authenticated(since: Date)
    
    /// Authentication failed
    case failed(reason: String)
    
    /// Authentication rejected (still not allowed after authenticating)
    case restricted(reason: String)
}

// MARK: - Authentication Manager Helper

/// Helper to manage authentication state with relays
public struct AuthenticationManager: Sendable {
    private var challenges: [String: AuthChallenge] = [:]
    private var statuses: [String: AuthenticationStatus] = [:]
    
    public init() {}
    
    /// Store a challenge from a relay
    public mutating func storeChallenge(_ challenge: AuthChallenge) {
        let relayKey = CoreNostr.normalizeRelayURL(challenge.relayURL)
        challenges[relayKey] = challenge
        statuses[relayKey] = .authenticationRequired(challenge: challenge)
    }
    
    /// Get the stored challenge for a relay
    public func getChallenge(for relayURL: String) -> AuthChallenge? {
        let relayKey = CoreNostr.normalizeRelayURL(relayURL)
        return challenges[relayKey]
    }
    
    /// Update authentication status for a relay
    public mutating func updateStatus(_ status: AuthenticationStatus, for relayURL: String) {
        let relayKey = CoreNostr.normalizeRelayURL(relayURL)
        statuses[relayKey] = status
    }
    
    /// Get authentication status for a relay
    public func getStatus(for relayURL: String) -> AuthenticationStatus {
        let relayKey = CoreNostr.normalizeRelayURL(relayURL)
        return statuses[relayKey] ?? .notAuthenticated
    }
    
    /// Clear expired challenges
    public mutating func cleanupExpiredChallenges() {
        for (relay, challenge) in challenges {
            if !challenge.isValid {
                challenges.removeValue(forKey: relay)
                if case .authenticationRequired = statuses[relay] {
                    statuses[relay] = .notAuthenticated
                }
            }
        }
    }
}