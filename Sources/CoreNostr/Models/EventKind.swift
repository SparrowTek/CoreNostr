//
//  EventKind.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

/// Standardized event kinds defined by NIP-01.
///
/// Event kinds determine how the event content should be interpreted by clients.
public enum EventKind: Int, CaseIterable, Sendable {
    /// Set metadata about the user (profile information)
    case setMetadata = 0
    
    /// Text note (tweet-like message)
    case textNote = 1
    
    /// Recommend a relay server
    case recommendServer = 2
    
    /// Follow list (NIP-02)
    case followList = 3
    
    /// Encrypted direct message (NIP-04) - DEPRECATED in favor of NIP-17
    case encryptedDirectMessage = 4
    
    /// Event deletion (NIP-09)
    case deletion = 5
    
    /// Reaction to an event (NIP-25)
    case reaction = 7
    
    /// Reaction to a website (NIP-25)
    case websiteReaction = 17
    
    /// OpenTimestamps attestation (NIP-03)
    case openTimestamps = 1040
    
    /// Human-readable description of the event kind.
    public var description: String {
        switch self {
        case .setMetadata: return "Set Metadata"
        case .textNote: return "Text Note"
        case .recommendServer: return "Recommend Server"
        case .followList: return "Follow List"
        case .encryptedDirectMessage: return "Encrypted Direct Message"
        case .deletion: return "Event Deletion"
        case .reaction: return "Reaction"
        case .websiteReaction: return "Website Reaction"
        case .openTimestamps: return "OpenTimestamps Attestation"
        }
    }
}
