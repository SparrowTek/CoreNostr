//
//  NIP58Tests.swift
//  CoreNostrTests
//
//  Tests for NIP-58: Badges
//

import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-58: Badges")
struct NIP58Tests {
    let issuerKeyPair: KeyPair
    let userKeyPair1: KeyPair
    let userKeyPair2: KeyPair
    
    init() throws {
        issuerKeyPair = try KeyPair.generate()
        userKeyPair1 = try KeyPair.generate()
        userKeyPair2 = try KeyPair.generate()
    }
    
    @Test("Event kinds")
    func eventKinds() throws {
        #expect(NIP58.badgeDefinitionKind == 30009)
        #expect(NIP58.badgeAwardKind == 8)
        #expect(NIP58.profileBadgesKind == 30008)
    }
    
    @Test("Thumbnail sizes")
    func thumbnailSizes() throws {
        #expect(NIP58.ThumbnailSize.tiny.pixels == 16)
        #expect(NIP58.ThumbnailSize.small.pixels == 32)
        #expect(NIP58.ThumbnailSize.medium.pixels == 64)
        #expect(NIP58.ThumbnailSize.large.pixels == 128)
        #expect(NIP58.ThumbnailSize.xlarge.pixels == 256)
        #expect(NIP58.ThumbnailSize.xxlarge.pixels == 512)
    }
    
    @Test("Create badge definition")
    func createBadgeDefinition() throws {
        let definition = try NIP58.createBadgeDefinition(
            identifier: "contributor-2024",
            name: "2024 Contributor",
            description: "Contributed to the project in 2024",
            image: "https://example.com/badge.png",
            keyPair: issuerKeyPair
        )
        
        #expect(definition.kind == 30009)
        #expect(definition.pubkey == issuerKeyPair.publicKey)
        
        // Check tags
        let dTag = definition.tags.first { $0[0] == "d" }
        #expect(dTag?[1] == "contributor-2024")
        
        let nameTag = definition.tags.first { $0[0] == "name" }
        #expect(nameTag?[1] == "2024 Contributor")
        
        let descTag = definition.tags.first { $0[0] == "description" }
        #expect(descTag?[1] == "Contributed to the project in 2024")
        
        let imageTag = definition.tags.first { $0[0] == "image" }
        #expect(imageTag?[1] == "https://example.com/badge.png")
        
        #expect(try CoreNostr.verifyEvent(definition))
    }
    
    @Test("Create badge definition with thumbnails")
    func createBadgeDefinitionWithThumbnails() throws {
        let thumbnails: [NIP58.ThumbnailSize: String] = [
            .small: "https://example.com/badge-32.png",
            .medium: "https://example.com/badge-64.png",
            .large: "https://example.com/badge-128.png"
        ]
        
        let definition = try NIP58.createBadgeDefinition(
            identifier: "special-badge",
            name: "Special Badge",
            thumbnails: thumbnails,
            keyPair: issuerKeyPair
        )
        
        let thumbTags = definition.tags.filter { $0[0] == "thumb" }
        #expect(thumbTags.count == 3)
        
        // Should be sorted by size
        #expect(thumbTags[0][1] == "32x32")
        #expect(thumbTags[1][1] == "64x64")
        #expect(thumbTags[2][1] == "128x128")
    }
    
    @Test("Create badge award")
    func createBadgeAward() throws {
        let definition = try NIP58.createBadgeDefinition(
            identifier: "test-badge",
            name: "Test Badge",
            keyPair: issuerKeyPair
        )
        
        let award = try NIP58.createBadgeAward(
            badgeDefinition: definition,
            awardedTo: [userKeyPair1.publicKey, userKeyPair2.publicKey],
            content: "Congratulations!",
            keyPair: issuerKeyPair
        )
        
        #expect(award.kind == 8)
        #expect(award.content == "Congratulations!")
        #expect(award.pubkey == issuerKeyPair.publicKey)
        
        // Check a tag
        let aTag = award.tags.first { $0[0] == "a" }
        #expect(aTag != nil)
        #expect(aTag?[1] == "30009:\(issuerKeyPair.publicKey):test-badge")
        
        // Check p tags
        let pTags = award.tags.filter { $0[0] == "p" }
        #expect(pTags.count == 2)
        #expect(pTags.contains { $0[1] == userKeyPair1.publicKey })
        #expect(pTags.contains { $0[1] == userKeyPair2.publicKey })
        
        #expect(try CoreNostr.verifyEvent(award))
    }
    
    @Test("Create badge award - invalid definition")
    func createBadgeAwardInvalidDefinition() throws {
        let notABadge = NostrEvent(
            pubkey: issuerKeyPair.publicKey,
            kind: 1, // Wrong kind
            tags: [],
            content: "Not a badge"
        )
        
        #expect(throws: NostrError.self) {
            _ = try NIP58.createBadgeAward(
                badgeDefinition: notABadge,
                awardedTo: [userKeyPair1.publicKey],
                keyPair: issuerKeyPair
            )
        }
    }
    
    @Test("Create profile badges")
    func createProfileBadges() throws {
        let definition1 = try NIP58.createBadgeDefinition(
            identifier: "badge1",
            keyPair: issuerKeyPair
        )
        
        let award1 = try NIP58.createBadgeAward(
            badgeDefinition: definition1,
            awardedTo: [userKeyPair1.publicKey],
            keyPair: issuerKeyPair
        )
        
        let definition2 = try NIP58.createBadgeDefinition(
            identifier: "badge2",
            keyPair: issuerKeyPair
        )
        
        let award2 = try NIP58.createBadgeAward(
            badgeDefinition: definition2,
            awardedTo: [userKeyPair1.publicKey],
            keyPair: issuerKeyPair
        )
        
        let badgeDisplay1 = try NIP58.BadgeDisplay(definition: definition1, award: award1)
        let badgeDisplay2 = try NIP58.BadgeDisplay(definition: definition2, award: award2)
        
        let profileBadges = try NIP58.createProfileBadges(
            badges: [badgeDisplay1, badgeDisplay2],
            keyPair: userKeyPair1
        )
        
        #expect(profileBadges.kind == 30008)
        #expect(profileBadges.pubkey == userKeyPair1.publicKey)
        
        // Check d tag
        let dTag = profileBadges.tags.first { $0[0] == "d" }
        #expect(dTag?[1] == "profile_badges")
        
        // Check alternating a and e tags
        let aTags = profileBadges.tags.filter { $0[0] == "a" }
        let eTags = profileBadges.tags.filter { $0[0] == "e" }
        #expect(aTags.count == 2)
        #expect(eTags.count == 2)
        
        #expect(try CoreNostr.verifyEvent(profileBadges))
    }
    
    @Test("Badge display creation")
    func badgeDisplayCreation() throws {
        let definition = try NIP58.createBadgeDefinition(
            identifier: "test-badge",
            keyPair: issuerKeyPair
        )
        
        let award = try NIP58.createBadgeAward(
            badgeDefinition: definition,
            awardedTo: [userKeyPair1.publicKey],
            keyPair: issuerKeyPair
        )
        
        let display = try NIP58.BadgeDisplay(definition: definition, award: award)
        #expect(display.badgeDefinitionTag == "30009:\(issuerKeyPair.publicKey):test-badge")
        #expect(display.badgeAwardEventId == award.id)
    }
    
    @Test("Parse badge definition")
    func parseBadgeDefinition() throws {
        let event = NostrEvent(
            pubkey: issuerKeyPair.publicKey,
            kind: 30009,
            tags: [
                ["d", "my-badge"],
                ["name", "My Badge"],
                ["description", "A test badge"],
                ["image", "https://example.com/badge.png"],
                ["thumb", "32x32", "https://example.com/badge-32.png"],
                ["thumb", "64x64", "https://example.com/badge-64.png"]
            ],
            content: ""
        )
        
        let definition = NIP58.parseBadgeDefinition(from: event)
        #expect(definition != nil)
        #expect(definition?.identifier == "my-badge")
        #expect(definition?.name == "My Badge")
        #expect(definition?.description == "A test badge")
        #expect(definition?.image == "https://example.com/badge.png")
        #expect(definition?.thumbnails?.count == 2)
        #expect(definition?.issuer == issuerKeyPair.publicKey)
    }
    
    @Test("Parse badge award")
    func parseBadgeAward() throws {
        let event = NostrEvent(
            pubkey: issuerKeyPair.publicKey,
            kind: 8,
            tags: [
                ["a", "30009:issuer-pubkey:badge-id"],
                ["p", userKeyPair1.publicKey],
                ["p", userKeyPair2.publicKey]
            ],
            content: "Well done!"
        )
        
        let award = NIP58.parseBadgeAward(from: event)
        #expect(award != nil)
        #expect(award?.badgeReference == "30009:issuer-pubkey:badge-id")
        #expect(award?.awardedTo.count == 2)
        #expect(award?.awardedTo.contains(userKeyPair1.publicKey) == true)
        #expect(award?.awardedTo.contains(userKeyPair2.publicKey) == true)
        #expect(award?.message == "Well done!")
        #expect(award?.awarder == issuerKeyPair.publicKey)
    }
    
    @Test("Parse profile badges")
    func parseProfileBadges() throws {
        let event = NostrEvent(
            pubkey: userKeyPair1.publicKey,
            kind: 30008,
            tags: [
                ["d", "profile_badges"],
                ["a", "30009:issuer1:badge1"],
                ["e", "award-event-id-1"],
                ["a", "30009:issuer2:badge2"],
                ["e", "award-event-id-2"]
            ],
            content: ""
        )
        
        let badges = NIP58.parseProfileBadges(from: event)
        #expect(badges?.count == 2)
        #expect(badges?[0].badgeDefinitionTag == "30009:issuer1:badge1")
        #expect(badges?[0].badgeAwardEventId == "award-event-id-1")
        #expect(badges?[1].badgeDefinitionTag == "30009:issuer2:badge2")
        #expect(badges?[1].badgeAwardEventId == "award-event-id-2")
    }
    
    @Test("Invalid badge parsing")
    func invalidBadgeParsing() throws {
        // Wrong kind
        let wrongKind = NostrEvent(
            pubkey: issuerKeyPair.publicKey,
            kind: 1,
            tags: [["d", "badge"]],
            content: ""
        )
        #expect(NIP58.parseBadgeDefinition(from: wrongKind) == nil)
        
        // Missing d tag
        let missingD = NostrEvent(
            pubkey: issuerKeyPair.publicKey,
            kind: 30009,
            tags: [],
            content: ""
        )
        #expect(NIP58.parseBadgeDefinition(from: missingD) == nil)
        
        // Award without p tags
        let noPTags = NostrEvent(
            pubkey: issuerKeyPair.publicKey,
            kind: 8,
            tags: [["a", "30009:issuer:badge"]],
            content: ""
        )
        #expect(NIP58.parseBadgeAward(from: noPTags) == nil)
    }
    
    @Test("Badge filters")
    func badgeFilters() throws {
        let defFilter = Filter.badgeDefinitions(
            issuers: [issuerKeyPair.publicKey]
        )
        #expect(defFilter.kinds == [30009])
        #expect(defFilter.authors == [issuerKeyPair.publicKey])
        
        let awardFilter = Filter.badgeAwards(
            awarders: [issuerKeyPair.publicKey],
            recipients: [userKeyPair1.publicKey],
            limit: 50
        )
        #expect(awardFilter.kinds == [8])
        #expect(awardFilter.authors == [issuerKeyPair.publicKey])
        #expect(awardFilter.p == [userKeyPair1.publicKey])
        #expect(awardFilter.limit == 50)
        
        let profileFilter = Filter.profileBadges(
            pubkeys: [userKeyPair1.publicKey, userKeyPair2.publicKey]
        )
        #expect(profileFilter.kinds == [30008])
        #expect(profileFilter.authors?.count == 2)
    }
    
    @Test("Complete badge flow")
    func completeBadgeFlow() throws {
        // 1. Create badge definition
        let definition = try NIP58.createBadgeDefinition(
            identifier: "early-adopter",
            name: "Early Adopter",
            description: "One of the first users",
            image: "https://example.com/early-adopter.png",
            keyPair: issuerKeyPair
        )
        
        // 2. Award badge to users
        let award = try NIP58.createBadgeAward(
            badgeDefinition: definition,
            awardedTo: [userKeyPair1.publicKey],
            content: "Thanks for being an early adopter!",
            keyPair: issuerKeyPair
        )
        
        // 3. User displays badge on profile
        let display = try NIP58.BadgeDisplay(definition: definition, award: award)
        let profileBadges = try NIP58.createProfileBadges(
            badges: [display],
            keyPair: userKeyPair1
        )
        
        // Verify all events
        #expect(try CoreNostr.verifyEvent(definition))
        #expect(try CoreNostr.verifyEvent(award))
        #expect(try CoreNostr.verifyEvent(profileBadges))
        
        // Parse them back
        let parsedDef = NIP58.parseBadgeDefinition(from: definition)
        #expect(parsedDef?.name == "Early Adopter")
        
        let parsedAward = NIP58.parseBadgeAward(from: award)
        #expect(parsedAward?.awardedTo.contains(userKeyPair1.publicKey) == true)
        
        let parsedProfile = NIP58.parseProfileBadges(from: profileBadges)
        #expect(parsedProfile?.count == 1)
    }
}