//
//  EventKind.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

/// Standardized event kinds defined by NIP-01.
///
/// Event kinds determine how the event content should be interpreted by clients.
public enum EventKind: Int, CaseIterable, Sendable, Codable {
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
    
    /// Zap request (NIP-57)
    case zapRequest = 9734
    
    /// Zap receipt (NIP-57)
    case zapReceipt = 9735
    
    // MARK: - NIP-51 Lists
    
    /// Mute list - things the user wants to hide (NIP-51)
    case muteList = 10000
    
    /// Pinned notes - events the user wants to showcase (NIP-51)
    case pinnedNotes = 10001
    
    /// Read/Write Relays - user's relay preferences (NIP-51)
    case relayList = 10002
    
    /// Bookmarks - saved items (NIP-51)
    case bookmarks = 10003
    
    /// Communities - user's community memberships (NIP-51)
    case communities = 10004
    
    /// Public chats - chat channel memberships (NIP-51)
    case publicChats = 10005
    
    /// Blocked relays - relays to never connect to (NIP-51)
    case blockedRelays = 10006
    
    /// Search relays - relays used for queries (NIP-51)
    case searchRelays = 10007
    
    /// Simple groups - group memberships (NIP-51)
    case simpleGroups = 10009
    
    /// Interests - topics of interest (NIP-51)
    case interests = 10015
    
    /// Emojis - preferred emojis (NIP-51)
    case emojis = 10030
    
    /// DM relays - relays for receiving direct messages (NIP-51)
    case dmRelays = 10050
    
    // MARK: - NIP-51 Sets (Parameterized Replaceable Events)
    
    /// Follow sets - categorized user groups (NIP-51)
    case followSets = 30000
    
    /// Relay sets - relay groups (NIP-51)
    case relaySets = 30002
    
    /// Bookmark sets - categorized bookmarks (NIP-51)
    case bookmarkSets = 30003
    
    /// Curation sets - grouped articles/notes (NIP-51)
    case curationSets = 30004
    
    /// Interest sets - topic collections (NIP-51)
    case interestSets = 30015
    
    /// Emoji sets - emoji collections (NIP-51)
    case emojiSets = 30030
    
    // MARK: - NIP-23 Long-form Content
    
    /// Long-form text content (articles/blog posts) (NIP-23)
    case longFormContent = 30023
    
    /// Long-form text content draft (NIP-23)
    case longFormDraft = 30024
    
    // MARK: - NIP-42 Authentication
    
    /// Client authentication (NIP-42)
    case clientAuthentication = 22242
    
    // MARK: - NIP-47 Nostr Wallet Connect
    
    /// Wallet service info event (NIP-47)
    case nwcInfo = 13194
    
    /// Wallet connect request (NIP-47)
    case nwcRequest = 23194
    
    /// Wallet connect response (NIP-47)
    case nwcResponse = 23195
    
    /// Wallet connect notification - NIP-04 encrypted (NIP-47) - Legacy
    case nwcNotificationLegacy = 23196
    
    /// Wallet connect notification - NIP-44 encrypted (NIP-47)
    case nwcNotification = 23197
    
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
        case .zapRequest: return "Zap Request"
        case .zapReceipt: return "Zap Receipt"
        case .muteList: return "Mute List"
        case .pinnedNotes: return "Pinned Notes"
        case .relayList: return "Relay List"
        case .bookmarks: return "Bookmarks"
        case .communities: return "Communities"
        case .publicChats: return "Public Chats"
        case .blockedRelays: return "Blocked Relays"
        case .searchRelays: return "Search Relays"
        case .simpleGroups: return "Simple Groups"
        case .interests: return "Interests"
        case .emojis: return "Emojis"
        case .dmRelays: return "DM Relays"
        case .followSets: return "Follow Sets"
        case .relaySets: return "Relay Sets"
        case .bookmarkSets: return "Bookmark Sets"
        case .curationSets: return "Curation Sets"
        case .interestSets: return "Interest Sets"
        case .emojiSets: return "Emoji Sets"
        case .longFormContent: return "Long-form Content"
        case .longFormDraft: return "Long-form Draft"
        case .clientAuthentication: return "Client Authentication"
        case .nwcInfo: return "NWC Info"
        case .nwcRequest: return "NWC Request"
        case .nwcResponse: return "NWC Response"
        case .nwcNotificationLegacy: return "NWC Notification (Legacy)"
        case .nwcNotification: return "NWC Notification"
        }
    }
}
