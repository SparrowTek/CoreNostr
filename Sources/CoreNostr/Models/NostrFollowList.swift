//
//  NostrFollowList.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// A follow list entry representing a single followed profile.
///
/// Each entry contains the public key of the followed user, an optional relay URL
/// where their events can be found, and an optional petname (local nickname).
public struct FollowEntry: Codable, Hashable, Sendable {
    /// The public key of the followed profile
    public let pubkey: PublicKey
    
    /// Optional relay URL where events from this profile can be found
    public let relayURL: String?
    
    /// Optional local name (petname) for this profile
    public let petname: String?
    
    /// Creates a new follow entry.
    ///
    /// - Parameters:
    ///   - pubkey: The public key of the profile to follow
    ///   - relayURL: Optional relay URL for finding their events
    ///   - petname: Optional local nickname for this profile
    public init(pubkey: PublicKey, relayURL: String? = nil, petname: String? = nil) {
        self.pubkey = pubkey
        self.relayURL = relayURL
        self.petname = petname
    }
    
    /// Creates a follow entry from a tag array.
    ///
    /// Expected format: `["p", pubkey, relayURL?, petname?]`
    ///
    /// - Parameter tag: The tag array to parse
    /// - Returns: A follow entry if the tag is valid, nil otherwise
    public static func from(tag: [String]) -> FollowEntry? {
        guard tag.count >= 2,
              tag[0] == "p",
              !tag[1].isEmpty else {
            return nil
        }
        
        let relayURL = tag.count > 2 && !tag[2].isEmpty ? tag[2] : nil
        let petname = tag.count > 3 && !tag[3].isEmpty ? tag[3] : nil
        
        return FollowEntry(pubkey: tag[1], relayURL: relayURL, petname: petname)
    }
    
    /// Converts this follow entry to a tag array format.
    ///
    /// - Returns: Tag array in the format `["p", pubkey, relayURL?, petname?]`
    public func toTag() -> [String] {
        var tag = ["p", pubkey]
        
        if let relayURL = relayURL {
            tag.append(relayURL)
            if let petname = petname {
                tag.append(petname)
            }
        } else if let petname = petname {
            tag.append("")
            tag.append(petname)
        }
        
        return tag
    }
}

/// A NOSTR follow list implementing NIP-02 specification.
///
/// Follow lists are special events with kind 3 that contain a list of profiles
/// being followed. They can be used for backup, profile discovery, relay sharing,
/// and implementing petname schemes.
///
/// ## Example
/// ```swift
/// let followList = NostrFollowList(
///     follows: [
///         FollowEntry(pubkey: "91cf9..4e5ca", relayURL: "wss://alicerelay.com/", petname: "alice"),
///         FollowEntry(pubkey: "14aeb..8dad4", relayURL: "wss://bobrelay.com/nostr", petname: "bob")
///     ]
/// )
/// 
/// let event = followList.createEvent(pubkey: userPubkey)
/// ```
public struct NostrFollowList: Codable, Hashable, Sendable {
    /// The list of followed profiles
    public let follows: [FollowEntry]
    
    /// Creates a new follow list.
    ///
    /// - Parameter follows: Array of follow entries
    public init(follows: [FollowEntry] = []) {
        self.follows = follows
    }
    
    /// Creates a follow list from a NostrEvent.
    ///
    /// - Parameter event: The event to parse (must be kind 3)
    /// - Returns: A follow list if the event is valid, nil otherwise
    public static func from(event: NostrEvent) -> NostrFollowList? {
        guard event.kind == EventKind.followList.rawValue else {
            return nil
        }
        
        let follows = event.tags.compactMap { FollowEntry.from(tag: $0) }
        return NostrFollowList(follows: follows)
    }
    
    /// Creates a NostrEvent from this follow list.
    ///
    /// - Parameters:
    ///   - pubkey: The public key of the event author
    ///   - createdAt: Creation timestamp (defaults to current time)
    /// - Returns: An unsigned NostrEvent ready for signing
    public func createEvent(pubkey: PublicKey, createdAt: Date = Date()) -> NostrEvent {
        let tags = follows.map { $0.toTag() }
        
        return NostrEvent(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: EventKind.followList.rawValue,
            tags: tags,
            content: ""
        )
    }
    
    /// Adds a new follow entry to the list.
    ///
    /// New follows are appended to the end to maintain chronological order
    /// as recommended by NIP-02.
    ///
    /// - Parameter follow: The follow entry to add
    /// - Returns: A new follow list with the added entry
    public func adding(_ follow: FollowEntry) -> NostrFollowList {
        return NostrFollowList(follows: follows + [follow])
    }
    
    /// Removes a follow entry by public key.
    ///
    /// - Parameter pubkey: The public key of the profile to unfollow
    /// - Returns: A new follow list with the entry removed
    public func removing(pubkey: PublicKey) -> NostrFollowList {
        let filteredFollows = follows.filter { $0.pubkey != pubkey }
        return NostrFollowList(follows: filteredFollows)
    }
    
    /// Checks if a public key is being followed.
    ///
    /// - Parameter pubkey: The public key to check
    /// - Returns: True if the public key is in the follow list
    public func isFollowing(_ pubkey: PublicKey) -> Bool {
        return follows.contains { $0.pubkey == pubkey }
    }
    
    /// Gets the petname for a given public key.
    ///
    /// - Parameter pubkey: The public key to look up
    /// - Returns: The petname if found, nil otherwise
    public func petname(for pubkey: PublicKey) -> String? {
        return follows.first { $0.pubkey == pubkey }?.petname
    }
    
    /// Gets the relay URL for a given public key.
    ///
    /// - Parameter pubkey: The public key to look up
    /// - Returns: The relay URL if found, nil otherwise
    public func relayURL(for pubkey: PublicKey) -> String? {
        return follows.first { $0.pubkey == pubkey }?.relayURL
    }
    
    /// Updates the petname for an existing follow.
    ///
    /// - Parameters:
    ///   - pubkey: The public key of the profile to update
    ///   - petname: The new petname (nil to remove)
    /// - Returns: A new follow list with the updated petname, or the same list if not found
    public func updatingPetname(for pubkey: PublicKey, to petname: String?) -> NostrFollowList {
        let updatedFollows = follows.map { follow in
            if follow.pubkey == pubkey {
                return FollowEntry(pubkey: follow.pubkey, relayURL: follow.relayURL, petname: petname)
            }
            return follow
        }
        return NostrFollowList(follows: updatedFollows)
    }
    
    /// Updates the relay URL for an existing follow.
    ///
    /// - Parameters:
    ///   - pubkey: The public key of the profile to update
    ///   - relayURL: The new relay URL (nil to remove)
    /// - Returns: A new follow list with the updated relay URL, or the same list if not found
    public func updatingRelayURL(for pubkey: PublicKey, to relayURL: String?) -> NostrFollowList {
        let updatedFollows = follows.map { follow in
            if follow.pubkey == pubkey {
                return FollowEntry(pubkey: follow.pubkey, relayURL: relayURL, petname: follow.petname)
            }
            return follow
        }
        return NostrFollowList(follows: updatedFollows)
    }
}