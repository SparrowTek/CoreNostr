//
//  NostrOpenTimestamps.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// A NOSTR OpenTimestamps attestation implementing NIP-03 specification.
///
/// OpenTimestamps attestations are special events with kind 1040 that contain
/// a cryptographic proof from the OpenTimestamps protocol, proving that a specific
/// NOSTR event existed at a certain point in time by anchoring it to the Bitcoin blockchain.
///
/// ## Example
/// ```swift
/// let attestation = NostrOpenTimestamps(
///     eventId: "e71c6ea722987debdb60f81f9ea4f604b5ac0664120dd64fb9d23abc4ec7c323",
///     relayURL: "wss://relay.example.com",
///     otsData: otsFileData
/// )
/// 
/// let event = attestation.createEvent(pubkey: userPubkey)
/// ```
public struct NostrOpenTimestamps: Codable, Hashable, Sendable {
    /// The event ID being attested to
    public let eventId: EventID
    
    /// Optional relay URL where the attested event can be found
    public let relayURL: String?
    
    /// The raw OTS file data containing the Bitcoin attestation
    public let otsData: Data
    
    /// Creates a new OpenTimestamps attestation.
    ///
    /// - Parameters:
    ///   - eventId: The ID of the event being attested
    ///   - relayURL: Optional relay URL where the event can be found
    ///   - otsData: The raw OTS file data containing the Bitcoin attestation
    public init(eventId: EventID, relayURL: String? = nil, otsData: Data) {
        self.eventId = eventId
        self.relayURL = relayURL
        self.otsData = otsData
    }
    
    /// Creates an OpenTimestamps attestation from a NostrEvent.
    ///
    /// - Parameter event: The event to parse (must be kind 1040)
    /// - Returns: An OpenTimestamps attestation if the event is valid, nil otherwise
    public static func from(event: NostrEvent) -> NostrOpenTimestamps? {
        guard event.kind == EventKind.openTimestamps.rawValue else {
            return nil
        }
        
        // Find the "e" tag containing the event ID
        guard let eventTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "e" }),
              !eventTag[1].isEmpty else {
            return nil
        }
        
        let eventId = eventTag[1]
        let relayURL = eventTag.count > 2 && !eventTag[2].isEmpty ? eventTag[2] : nil
        
        // Decode the base64 content to get OTS data
        guard let otsData = Data(base64Encoded: event.content) else {
            return nil
        }
        
        return NostrOpenTimestamps(eventId: eventId, relayURL: relayURL, otsData: otsData)
    }
    
    /// Creates a NostrEvent from this OpenTimestamps attestation.
    ///
    /// - Parameters:
    ///   - pubkey: The public key of the event author
    ///   - createdAt: Creation timestamp (defaults to current time)
    /// - Returns: An unsigned NostrEvent ready for signing
    public func createEvent(pubkey: PublicKey, createdAt: Date = Date()) -> NostrEvent {
        var tags: [[String]] = []
        
        // Add the event reference tag
        if let relayURL = relayURL {
            tags.append(["e", eventId, relayURL])
        } else {
            tags.append(["e", eventId])
        }
        
        // Add the required "alt" tag for OpenTimestamps attestation
        tags.append(["alt", "opentimestamps attestation"])
        
        // Encode OTS data as base64 for the content
        let base64Content = otsData.base64EncodedString()
        
        return NostrEvent(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: EventKind.openTimestamps.rawValue,
            tags: tags,
            content: base64Content
        )
    }
    
    /// Validates that the OTS data appears to be a valid OTS file.
    ///
    /// This performs basic validation to ensure the data starts with the OTS magic bytes
    /// and has a reasonable minimum size for an OTS file.
    ///
    /// - Returns: True if the OTS data appears valid, false otherwise
    public func isValidOTSData() -> Bool {
        // OTS files start with magic bytes: 0x00, 0x4F, 0x54, 0x53 (NUL, 'O', 'T', 'S')
        let otsMagic: [UInt8] = [0x00, 0x4F, 0x54, 0x53]
        
        guard otsData.count >= otsMagic.count else {
            return false
        }
        
        let prefix = Array(otsData.prefix(otsMagic.count))
        return prefix == otsMagic
    }
    
    /// Gets the size of the OTS file data in bytes.
    ///
    /// - Returns: The size of the OTS data
    public var otsDataSize: Int {
        return otsData.count
    }
    
    /// Gets the base64-encoded representation of the OTS data.
    ///
    /// This is the same format used in the event content.
    ///
    /// - Returns: Base64-encoded OTS data
    public var base64EncodedOTSData: String {
        return otsData.base64EncodedString()
    }
}

// MARK: - Convenience Extensions

extension NostrOpenTimestamps {
    /// Creates an OpenTimestamps attestation from base64-encoded OTS data.
    ///
    /// - Parameters:
    ///   - eventId: The ID of the event being attested
    ///   - relayURL: Optional relay URL where the event can be found
    ///   - base64OTSData: The base64-encoded OTS file data
    /// - Returns: An OpenTimestamps attestation if the base64 data is valid, nil otherwise
    public static func fromBase64(
        eventId: EventID,
        relayURL: String? = nil,
        base64OTSData: String
    ) -> NostrOpenTimestamps? {
        guard let otsData = Data(base64Encoded: base64OTSData) else {
            return nil
        }
        return NostrOpenTimestamps(eventId: eventId, relayURL: relayURL, otsData: otsData)
    }
    
    /// Creates an OpenTimestamps attestation from an OTS file URL.
    ///
    /// This is a convenience method for loading OTS data from a file.
    ///
    /// - Parameters:
    ///   - eventId: The ID of the event being attested
    ///   - relayURL: Optional relay URL where the event can be found
    ///   - otsFileURL: The URL to the OTS file
    /// - Returns: An OpenTimestamps attestation if the file can be read, nil otherwise
    /// - Throws: File reading errors
    public static func fromFile(
        eventId: EventID,
        relayURL: String? = nil,
        otsFileURL: URL
    ) throws -> NostrOpenTimestamps? {
        let otsData = try Data(contentsOf: otsFileURL)
        return NostrOpenTimestamps(eventId: eventId, relayURL: relayURL, otsData: otsData)
    }
    
    /// Saves the OTS data to a file.
    ///
    /// - Parameter url: The URL where to save the OTS file
    /// - Throws: File writing errors
    public func saveOTSFile(to url: URL) throws {
        try otsData.write(to: url)
    }
}