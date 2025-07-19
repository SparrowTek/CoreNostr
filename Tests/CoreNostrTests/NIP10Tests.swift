import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-10: Reply Threading Tests")
struct NIP10Tests {
    
    let keyPair = try! KeyPair.generate()
    let otherKeyPair = try! KeyPair.generate()
    
    @Test("Extract thread references - marked format")
    func testExtractThreadReferencesMarked() throws {
        // Create event with marked tags
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [
                ["e", "rootid123", "wss://relay.example.com", "root"],
                ["e", "replyid456", "", "reply"],
                ["e", "mentionid789", "wss://other.relay.com", "mention"],
                ["p", otherKeyPair.publicKey]
            ],
            content: "Test reply"
        )
        let signedEvent = try keyPair.signEvent(event)
        
        let refs = signedEvent.extractThreadReferences()
        #expect(refs.count == 3)
        
        // Check root
        if case .root(let eventId, let relay, let marker) = refs[0] {
            #expect(eventId == "rootid123")
            #expect(relay == "wss://relay.example.com")
            #expect(marker == "root")
        } else {
            Issue.record("Expected root reference")
        }
        
        // Check reply
        if case .reply(let eventId, let relay, let marker) = refs[1] {
            #expect(eventId == "replyid456")
            #expect(relay == nil)
            #expect(marker == "reply")
        } else {
            Issue.record("Expected reply reference")
        }
        
        // Check mention
        if case .mention(let eventId, let relay) = refs[2] {
            #expect(eventId == "mentionid789")
            #expect(relay == "wss://other.relay.com")
        } else {
            Issue.record("Expected mention reference")
        }
        
        #expect(signedEvent.rootEventId == "rootid123")
        #expect(signedEvent.replyToEventId == "replyid456")
        #expect(signedEvent.mentionedEventIds == ["mentionid789"])
        #expect(signedEvent.isReply)
        #expect(signedEvent.isThreaded)
    }
    
    @Test("Extract thread references - positional format (deprecated)")
    func testExtractThreadReferencesPositional() throws {
        // Test single e-tag (direct reply)
        let replyEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [
                ["e", "parentid123", "wss://relay.example.com"],
                ["p", otherKeyPair.publicKey]
            ],
            content: "Direct reply"
        )
        let signedReplyEvent = try keyPair.signEvent(replyEvent)
        
        let replyRefs = signedReplyEvent.extractThreadReferences()
        #expect(replyRefs.count == 1)
        
        if case .reply(let eventId, let relay, _) = replyRefs[0] {
            #expect(eventId == "parentid123")
            #expect(relay == "wss://relay.example.com")
        } else {
            Issue.record("Expected reply reference")
        }
        
        #expect(signedReplyEvent.replyToEventId == "parentid123")
        #expect(signedReplyEvent.rootEventId == nil)
        
        // Test multiple e-tags (thread with root and reply)
        let threadEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [
                ["e", "rootid123"],
                ["e", "mentionid456", "wss://relay1.com"],
                ["e", "mentionid789"],
                ["e", "replyid999", "wss://relay2.com"]
            ],
            content: "Thread reply"
        )
        let signedThreadEvent = try keyPair.signEvent(threadEvent)
        
        let threadRefs = signedThreadEvent.extractThreadReferences()
        #expect(threadRefs.count == 4)
        
        // First should be root
        if case .root(let eventId, _, _) = threadRefs[0] {
            #expect(eventId == "rootid123")
        } else {
            Issue.record("Expected root reference")
        }
        
        // Middle should be mentions
        if case .mention(let eventId, _) = threadRefs[1] {
            #expect(eventId == "mentionid456")
        } else {
            Issue.record("Expected mention reference")
        }
        
        // Last should be reply
        if case .reply(let eventId, _, _) = threadRefs[3] {
            #expect(eventId == "replyid999")
        } else {
            Issue.record("Expected reply reference")
        }
        
        #expect(signedThreadEvent.rootEventId == "rootid123")
        #expect(signedThreadEvent.replyToEventId == "replyid999")
        #expect(signedThreadEvent.mentionedEventIds.count == 2)
    }
    
    @Test("Create reply event")
    func testCreateReplyEvent() throws {
        // Create parent event
        let parentEvent = NostrEvent(
            pubkey: otherKeyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Original post"
        )
        let signedParentEvent = try otherKeyPair.signEvent(parentEvent)
        
        // Create reply
        let replyEvent = try NostrEvent.createReply(
            to: signedParentEvent,
            content: "This is a reply",
            keyPair: keyPair
        )
        
        #expect(replyEvent.content == "This is a reply")
        #expect(replyEvent.pubkey == keyPair.publicKey)
        
        // Check tags
        let pTags = replyEvent.tags.filter { $0.first == "p" }
        let eTags = replyEvent.tags.filter { $0.first == "e" }
        
        #expect(pTags.count == 1)
        #expect(pTags[0][1] == signedParentEvent.pubkey)
        
        #expect(eTags.count == 1)
        #expect(eTags[0][1] == signedParentEvent.id)
        #expect(eTags[0].last == "reply")
        
        // Verify thread references
        #expect(replyEvent.replyToEventId == signedParentEvent.id)
        #expect(replyEvent.isReply)
    }
    
    @Test("Create reply in existing thread")
    func testCreateReplyInThread() throws {
        // Create root event
        let rootEvent = NostrEvent(
            pubkey: otherKeyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Root post"
        )
        let signedRootEvent = try otherKeyPair.signEvent(rootEvent)
        
        // Create parent event (reply to root)
        let parentEvent = NostrEvent(
            pubkey: otherKeyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [
                ["e", signedRootEvent.id, "", "root"],
                ["e", signedRootEvent.id, "", "reply"],
                ["p", signedRootEvent.pubkey]
            ],
            content: "Reply to root"
        )
        let signedParentEvent = try otherKeyPair.signEvent(parentEvent)
        
        // Create nested reply
        let nestedReply = try NostrEvent.createReply(
            to: signedParentEvent,
            root: signedRootEvent,
            content: "Reply to reply",
            keyPair: keyPair
        )
        
        let eTags = nestedReply.tags.filter { $0.first == "e" }
        #expect(eTags.count == 2)
        
        // Should have root marker
        let rootTag = eTags.first { $0.last == "root" }
        #expect(rootTag?[1] == signedRootEvent.id)
        
        // Should have reply marker for parent
        let replyTag = eTags.first { $0.last == "reply" }
        #expect(replyTag?[1] == signedParentEvent.id)
        
        #expect(nestedReply.rootEventId == signedRootEvent.id)
        #expect(nestedReply.replyToEventId == signedParentEvent.id)
    }
    
    @Test("Create event with mentions")
    func testCreateWithMentions() throws {
        // Create events to mention
        let mention1 = NostrEvent(
            pubkey: otherKeyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "First post"
        )
        let signedMention1 = try otherKeyPair.signEvent(mention1)
        
        let mention2 = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Second post"
        )
        let signedMention2 = try keyPair.signEvent(mention2)
        
        // Create event with mentions
        let eventWithMentions = try NostrEvent.createWithMentions(
            content: "Check out these posts!",
            mentionedEvents: [signedMention1, signedMention2],
            keyPair: keyPair
        )
        
        let eTags = eventWithMentions.tags.filter { $0.first == "e" }
        let pTags = eventWithMentions.tags.filter { $0.first == "p" }
        
        #expect(eTags.count == 2)
        #expect(eTags[0][1] == signedMention1.id)
        #expect(eTags[0].last == "mention")
        #expect(eTags[1][1] == signedMention2.id)
        #expect(eTags[1].last == "mention")
        
        // Should have p tag for other author (not self)
        #expect(pTags.count == 1)
        #expect(pTags[0][1] == otherKeyPair.publicKey)
        
        #expect(eventWithMentions.mentionedEventIds.contains(signedMention1.id))
        #expect(eventWithMentions.mentionedEventIds.contains(signedMention2.id))
    }
    
    @Test("TagReference tag generation")
    func testTagReferenceTagGeneration() {
        // Test root with all fields
        let root = NostrEvent.TagReference.root(
            eventId: "abc123",
            relayUrl: "wss://relay.com",
            marker: "root"
        )
        #expect(root.tag == ["e", "abc123", "wss://relay.com", "root"])
        
        // Test reply without relay
        let reply = NostrEvent.TagReference.reply(
            eventId: "def456",
            marker: "reply"
        )
        #expect(reply.tag == ["e", "def456", "", "reply"])
        
        // Test mention
        let mention = NostrEvent.TagReference.mention(
            eventId: "ghi789",
            relayUrl: "wss://other.relay"
        )
        #expect(mention.tag == ["e", "ghi789", "wss://other.relay", "mention"])
        
        // Test accessors
        #expect(root.eventId == "abc123")
        #expect(root.relayUrl == "wss://relay.com")
        #expect(reply.eventId == "def456")
        #expect(reply.relayUrl == nil)
    }
    
    @Test("Filter convenience methods")
    func testFilterConvenienceMethods() {
        // Test replies filter
        let repliesFilter = Filter.replies(to: "eventid123")
        #expect(repliesFilter.kinds == [EventKind.textNote.rawValue])
        #expect(repliesFilter.e == ["eventid123"])
        
        // Test thread filter
        let threadFilter = Filter.thread(rootEventId: "rootid456")
        #expect(threadFilter.kinds == [EventKind.textNote.rawValue])
        #expect(threadFilter.e == ["rootid456"])
        
        // Test mentioning filter
        let mentioningFilter = Filter.mentioning(events: ["id1", "id2", "id3"])
        #expect(mentioningFilter.kinds == [EventKind.textNote.rawValue])
        #expect(mentioningFilter.e == ["id1", "id2", "id3"])
    }
    
    @Test("Empty tags handling")
    func testEmptyTagsHandling() throws {
        // Event with no e tags
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [["p", otherKeyPair.publicKey]],
            content: "No thread tags"
        )
        let signedEvent = try keyPair.signEvent(event)
        
        let refs = signedEvent.extractThreadReferences()
        #expect(refs.isEmpty)
        #expect(signedEvent.rootEventId == nil)
        #expect(signedEvent.replyToEventId == nil)
        #expect(signedEvent.mentionedEventIds.isEmpty)
        #expect(!signedEvent.isReply)
        #expect(!signedEvent.isThreaded)
    }
}