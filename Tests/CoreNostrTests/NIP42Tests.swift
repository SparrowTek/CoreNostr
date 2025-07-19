//
//  NIP42Tests.swift
//  CoreNostrTests
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-42: Client Authentication")
struct NIP42Tests {
    let keyPair: KeyPair
    let relayURL = "wss://relay.example.com"
    let challengeString = "challenge-123456"
    
    init() throws {
        let privateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
        self.keyPair = try KeyPair(privateKey: privateKeyHex)
    }
    
    @Test("Create authentication challenge")
    func testCreateAuthChallenge() {
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL
        )
        
        #expect(challenge.challenge == challengeString)
        #expect(challenge.relayURL == relayURL)
        #expect(challenge.isValid)
        
        // Test expired challenge
        let oldChallenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL,
            receivedAt: Date(timeIntervalSinceNow: -700) // 11 minutes ago
        )
        
        #expect(!oldChallenge.isValid)
    }
    
    @Test("Create authentication event")
    func testCreateAuthenticationEvent() throws {
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL
        )
        
        let event = try CoreNostr.createAuthenticationEvent(
            challenge: challenge,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.clientAuthentication.rawValue)
        #expect(event.content == "")
        #expect(event.pubkey == keyPair.publicKey)
        
        // Check tags
        let tags = event.tags
        #expect(tags.contains(["relay", relayURL]))
        #expect(tags.contains(["challenge", challengeString]))
        
        // Verify it's a signed event
        #expect(!event.id.isEmpty)
        #expect(!event.sig.isEmpty)
    }
    
    @Test("Create authentication response")
    func testCreateAuthResponse() throws {
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL
        )
        
        let response = try CoreNostr.authenticate(
            challenge: challenge,
            keyPair: keyPair
        )
        
        #expect(response.event.isAuthenticationEvent)
        #expect(response.challenge.challenge == challengeString)
        
        // Verify the response event
        let authDetails = response.event.parseAuthentication()
        #expect(authDetails?.relayURL == relayURL)
        #expect(authDetails?.challenge == challengeString)
    }
    
    @Test("Expired challenge handling")
    func testExpiredChallenge() throws {
        let expiredChallenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL,
            receivedAt: Date(timeIntervalSinceNow: -700)
        )
        
        do {
            _ = try CoreNostr.createAuthenticationEvent(
                challenge: expiredChallenge,
                keyPair: keyPair
            )
            #expect(Bool(false), "Should throw error for expired challenge")
        } catch {
            #expect(error as? AuthenticationError == .challengeExpired)
        }
    }
    
    @Test("Relay URL normalization")
    func testRelayURLNormalization() {
        // Test various URL formats
        #expect(CoreNostr.normalizeRelayURL("relay.example.com") == "wss://relay.example.com")
        #expect(CoreNostr.normalizeRelayURL("wss://relay.example.com") == "wss://relay.example.com")
        #expect(CoreNostr.normalizeRelayURL("wss://relay.example.com/") == "wss://relay.example.com")
        #expect(CoreNostr.normalizeRelayURL("WSS://RELAY.EXAMPLE.COM/") == "wss://relay.example.com")
        #expect(CoreNostr.normalizeRelayURL("ws://relay.example.com") == "ws://relay.example.com")
    }
    
    @Test("Parse authentication from event")
    func testParseAuthentication() throws {
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL
        )
        
        let event = try CoreNostr.createAuthenticationEvent(
            challenge: challenge,
            keyPair: keyPair
        )
        
        #expect(event.isAuthenticationEvent)
        
        let parsed = event.parseAuthentication()
        #expect(parsed != nil)
        #expect(parsed?.relayURL == relayURL)
        #expect(parsed?.challenge == challengeString)
        
        // Test non-auth event
        let textEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Hello"
        )
        
        #expect(!textEvent.isAuthenticationEvent)
        #expect(textEvent.parseAuthentication() == nil)
    }
    
    @Test("Verify authentication event")
    func testVerifyAuthentication() throws {
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: "wss://relay.example.com"
        )
        
        let event = try CoreNostr.createAuthenticationEvent(
            challenge: challenge,
            keyPair: keyPair
        )
        
        // Should verify against same challenge
        #expect(event.verifyAuthentication(against: challenge))
        
        // Should fail with different challenge string
        let differentChallenge = AuthChallenge(
            challenge: "different-challenge",
            relayURL: relayURL
        )
        #expect(!event.verifyAuthentication(against: differentChallenge))
        
        // Should fail with different relay
        let differentRelay = AuthChallenge(
            challenge: challengeString,
            relayURL: "wss://different.relay.com"
        )
        #expect(!event.verifyAuthentication(against: differentRelay))
        
        // Should pass with slightly different relay URL format
        let sameRelayDifferentFormat = AuthChallenge(
            challenge: challengeString,
            relayURL: "relay.example.com" // Without wss://
        )
        #expect(event.verifyAuthentication(against: sameRelayDifferentFormat))
    }
    
    @Test("Authentication manager")
    func testAuthenticationManager() {
        var manager = AuthenticationManager()
        
        let challenge1 = AuthChallenge(
            challenge: "challenge1",
            relayURL: "wss://relay1.com"
        )
        
        let challenge2 = AuthChallenge(
            challenge: "challenge2",
            relayURL: "wss://relay2.com"
        )
        
        // Store challenges
        manager.storeChallenge(challenge1)
        manager.storeChallenge(challenge2)
        
        // Retrieve challenges
        let retrieved1 = manager.getChallenge(for: "relay1.com") // Without wss://
        #expect(retrieved1?.challenge == "challenge1")
        
        let retrieved2 = manager.getChallenge(for: "wss://relay2.com/") // With trailing slash
        #expect(retrieved2?.challenge == "challenge2")
        
        // Check status
        if case .authenticationRequired(let challenge) = manager.getStatus(for: "relay1.com") {
            #expect(challenge.challenge == "challenge1")
        } else {
            #expect(Bool(false), "Expected authenticationRequired status")
        }
        
        // Update status
        manager.updateStatus(.authenticated(since: Date()), for: "relay1.com")
        
        if case .authenticated = manager.getStatus(for: "relay1.com") {
            // Success
        } else {
            #expect(Bool(false), "Expected authenticated status")
        }
        
        // Unknown relay should be notAuthenticated
        if case .notAuthenticated = manager.getStatus(for: "unknown.relay.com") {
            // Success
        } else {
            #expect(Bool(false), "Expected notAuthenticated status")
        }
    }
    
    @Test("Cleanup expired challenges")
    func testCleanupExpiredChallenges() {
        var manager = AuthenticationManager()
        
        let validChallenge = AuthChallenge(
            challenge: "valid",
            relayURL: "wss://valid.relay.com"
        )
        
        let expiredChallenge = AuthChallenge(
            challenge: "expired",
            relayURL: "wss://expired.relay.com",
            receivedAt: Date(timeIntervalSinceNow: -700)
        )
        
        manager.storeChallenge(validChallenge)
        manager.storeChallenge(expiredChallenge)
        
        // Both should exist initially
        #expect(manager.getChallenge(for: "valid.relay.com") != nil)
        #expect(manager.getChallenge(for: "expired.relay.com") != nil)
        
        // Cleanup expired
        manager.cleanupExpiredChallenges()
        
        // Only valid should remain
        #expect(manager.getChallenge(for: "valid.relay.com") != nil)
        #expect(manager.getChallenge(for: "expired.relay.com") == nil)
        
        // Status should be reset to notAuthenticated
        if case .notAuthenticated = manager.getStatus(for: "expired.relay.com") {
            // Success
        } else {
            #expect(Bool(false), "Expected notAuthenticated status after cleanup")
        }
    }
    
    @Test("Authentication status enum")
    func testAuthenticationStatus() {
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL
        )
        
        // Test different status cases
        let notAuth = AuthenticationStatus.notAuthenticated
        let authRequired = AuthenticationStatus.authenticationRequired(challenge: challenge)
        let authenticating = AuthenticationStatus.authenticating
        let authenticated = AuthenticationStatus.authenticated(since: Date())
        let failed = AuthenticationStatus.failed(reason: "Invalid credentials")
        let restricted = AuthenticationStatus.restricted(reason: "Insufficient permissions")
        
        // Just verify they can be created
        if case .notAuthenticated = notAuth { /* ok */ }
        if case .authenticationRequired = authRequired { /* ok */ }
        if case .authenticating = authenticating { /* ok */ }
        if case .authenticated = authenticated { /* ok */ }
        if case .failed = failed { /* ok */ }
        if case .restricted = restricted { /* ok */ }
    }
    
    @Test("Invalid authentication event")
    func testInvalidAuthEvent() {
        // Missing tags
        let invalidEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.clientAuthentication.rawValue,
            tags: [], // No tags
            content: ""
        )
        
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: relayURL
        )
        
        let response = AuthResponse(event: invalidEvent, challenge: challenge)
        #expect(response == nil)
        
        // Wrong kind
        let wrongKindEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.textNote.rawValue,
            tags: [
                ["relay", relayURL],
                ["challenge", challengeString]
            ],
            content: ""
        )
        
        let response2 = AuthResponse(event: wrongKindEvent, challenge: challenge)
        #expect(response2 == nil)
    }
    
    @Test("Authentication with subdomain relays")
    func testSubdomainRelayAuth() throws {
        let challenge = AuthChallenge(
            challenge: challengeString,
            relayURL: "wss://us-east.relay.example.com"
        )
        
        let event = try CoreNostr.createAuthenticationEvent(
            challenge: challenge,
            keyPair: keyPair
        )
        
        // Should verify with exact match
        #expect(event.verifyAuthentication(against: challenge))
        
        // Should verify with different protocol format
        let httpChallenge = AuthChallenge(
            challenge: challengeString,
            relayURL: "us-east.relay.example.com" // Without wss://
        )
        #expect(event.verifyAuthentication(against: httpChallenge))
        
        // Should not verify with different subdomain
        let differentSubdomain = AuthChallenge(
            challenge: challengeString,
            relayURL: "wss://eu-west.relay.example.com"
        )
        #expect(!event.verifyAuthentication(against: differentSubdomain))
    }
}