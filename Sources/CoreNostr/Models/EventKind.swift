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
    
    /// Human-readable description of the event kind.
    public var description: String {
        switch self {
        case .setMetadata: return "Set Metadata"
        case .textNote: return "Text Note"
        case .recommendServer: return "Recommend Server"
        }
    }
}
