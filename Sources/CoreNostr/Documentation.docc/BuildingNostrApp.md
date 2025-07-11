# Building a NOSTR App with CoreNostr

Create a complete NOSTR application using CoreNostr's powerful APIs.

## Overview

This tutorial will guide you through building a complete NOSTR application using CoreNostr. You'll learn how to:

- Set up key management
- Connect to multiple relays
- Create and publish different types of events
- Subscribe to event feeds
- Handle user interactions and real-time updates

## Prerequisites

- Basic knowledge of Swift and SwiftUI
- Understanding of async/await patterns
- Familiarity with NOSTR concepts (events, relays, keys)

## Step 1: Project Setup

First, create a new Swift project and add CoreNostr as a dependency:

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://github.com/your-org/CoreNostr", from: "1.0.0")
]
```

## Step 2: Create the Core NOSTR Client

Let's start by creating a main client class that will manage our NOSTR operations:

```swift
import CoreNostr
import SwiftUI

@MainActor
@Observable
class NostrClient {
    // Core components
    private var keyPair: KeyPair?
    private let relayPool = RelayPool()
    
    // UI State
    var isConnected = false
    var connectionStatus = "Disconnected"
    var events: [NostrEvent] = []
    var userProfile: UserProfile?
    
    // Configuration
    private let defaultRelays = [
        "wss://relay.damus.io",
        "wss://relay.nostr.band",
        "wss://nos.lol"
    ]
    
    init() {
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        // Load or generate keys
        await loadOrGenerateKeys()
        
        // Connect to relays
        await connectToRelays()
        
        // Start listening for events
        await startListening()
    }
}
```

## Step 3: Key Management

Implement secure key management with persistence:

```swift
extension NostrClient {
    private func loadOrGenerateKeys() async {
        // In a real app, you'd load from secure storage
        // For this example, we'll generate new keys
        do {
            keyPair = try CoreNostr.createKeyPair()
            print("Generated new key pair")
            print("Public key: \(keyPair!.publicKey)")
        } catch {
            print("Failed to generate keys: \(error)")
        }
    }
    
    var publicKey: String? {
        keyPair?.publicKey
    }
    
    var isLoggedIn: Bool {
        keyPair != nil
    }
}
```

## Step 4: Relay Connection Management

Connect to multiple relays and handle connection states:

```swift
extension NostrClient {
    private func connectToRelays() async {
        connectionStatus = "Connecting..."
        
        var connectedCount = 0
        
        for relayURL in defaultRelays {
            guard let url = URL(string: relayURL) else { continue }
            
            do {
                try await relayPool.addRelay(url)
                connectedCount += 1
                print("Connected to \(relayURL)")
            } catch {
                print("Failed to connect to \(relayURL): \(error)")
            }
        }
        
        isConnected = connectedCount > 0
        connectionStatus = isConnected ? 
            "Connected to \(connectedCount) relays" : 
            "Connection failed"
    }
    
    func reconnect() async {
        // Disconnect from all relays
        for url in Array(relayPool.connections.keys) {
            await relayPool.removeRelay(url)
        }
        
        isConnected = false
        events.removeAll()
        
        // Reconnect
        await connectToRelays()
        await startListening()
    }
}
```

## Step 5: Event Publishing

Implement functions to create and publish different types of events:

```swift
extension NostrClient {
    func publishTextNote(_ content: String, replyTo: String? = nil) async {
        guard let keyPair = keyPair else { return }
        
        do {
            let event = try CoreNostr.createTextNote(
                keyPair: keyPair,
                content: content,
                replyTo: replyTo
            )
            
            await relayPool.publishEvent(event)
            
            // Add to local events immediately for optimistic UI
            events.insert(event, at: 0)
            
        } catch {
            print("Failed to publish note: \(error)")
        }
    }
    
    func updateProfile(name: String, about: String, picture: String?) async {
        guard let keyPair = keyPair else { return }
        
        do {
            let event = try CoreNostr.createMetadataEvent(
                keyPair: keyPair,
                name: name,
                about: about,
                picture: picture
            )
            
            await relayPool.publishEvent(event)
            
            // Update local profile
            userProfile = UserProfile(
                name: name,
                about: about,
                picture: picture
            )
            
        } catch {
            print("Failed to update profile: \(error)")
        }
    }
    
    func reactToEvent(_ eventId: String, reaction: String = "❤️") async {
        guard let keyPair = keyPair else { return }
        
        do {
            let event = try CoreNostr.createEvent(
                keyPair: keyPair,
                kind: .reaction, // You'd need to add this to EventKind
                content: reaction,
                tags: [["e", eventId]]
            )
            
            await relayPool.publishEvent(event)
            
        } catch {
            print("Failed to react to event: \(error)")
        }
    }
}
```

## Step 6: Event Subscription and Listening

Set up event subscriptions and handle incoming events:

```swift
extension NostrClient {
    private func startListening() async {
        guard isConnected else { return }
        
        // Subscribe to recent global events
        await subscribeToGlobalFeed()
        
        // Subscribe to your own events
        if let publicKey = keyPair?.publicKey {
            await subscribeToUserFeed(publicKey)
        }
        
        // Listen for incoming events
        Task {
            for await (relayURL, message) in relayPool.allMessages {
                await handleRelayMessage(message, from: relayURL)
            }
        }
    }
    
    private func subscribeToGlobalFeed() async {
        let filter = Filter.textNotes(limit: 50)
        await relayPool.subscribe(subscriptionId: "global-feed", filters: [filter])
    }
    
    private func subscribeToUserFeed(_ publicKey: String) async {
        let filter = Filter.textNotes(authors: [publicKey], limit: 20)
        await relayPool.subscribe(subscriptionId: "user-feed", filters: [filter])
    }
    
    private func handleRelayMessage(_ message: RelayMessage, from relayURL: URL) async {
        switch message {
        case .event(let subscriptionId, let event):
            await handleIncomingEvent(event, subscriptionId: subscriptionId)
            
        case .ok(let eventId, let accepted, let message):
            if accepted {
                print("Event \(eventId) accepted by \(relayURL)")
            } else {
                print("Event \(eventId) rejected: \(message ?? "unknown reason")")
            }
            
        case .eose(let subscriptionId):
            print("End of stored events for \(subscriptionId) from \(relayURL)")
            
        case .notice(let notice):
            print("Notice from \(relayURL): \(notice)")
            
        default:
            break
        }
    }
    
    private func handleIncomingEvent(_ event: NostrEvent, subscriptionId: String) async {
        // Verify event signature
        do {
            let isValid = try CoreNostr.verifyEvent(event)
            guard isValid else {
                print("Invalid event signature")
                return
            }
        } catch {
            print("Event verification failed: \(error)")
            return
        }
        
        // Add to events if it's not a duplicate
        if !events.contains(where: { $0.id == event.id }) {
            // Insert in chronological order
            let insertIndex = events.firstIndex { $0.createdAt < event.createdAt } ?? events.count
            events.insert(event, at: insertIndex)
            
            // Limit the number of events in memory
            if events.count > 500 {
                events.removeLast(events.count - 500)
            }
        }
        
        // Handle metadata events
        if event.isMetadata, event.pubkey == keyPair?.publicKey {
            await parseAndUpdateProfile(event)
        }
    }
    
    private func parseAndUpdateProfile(_ event: NostrEvent) async {
        // Parse JSON metadata
        guard let data = event.content.data(using: .utf8),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        userProfile = UserProfile(
            name: metadata["name"] as? String,
            about: metadata["about"] as? String,
            picture: metadata["picture"] as? String
        )
    }
}
```

## Step 7: User Profile Model

Create a simple user profile model:

```swift
struct UserProfile: Codable, Identifiable {
    let id = UUID()
    let name: String?
    let about: String?
    let picture: String?
    
    var displayName: String {
        name?.isEmpty == false ? name! : "Anonymous"
    }
    
    var hasProfileInfo: Bool {
        name != nil || about != nil || picture != nil
    }
}
```

## Step 8: SwiftUI Views

Create the main SwiftUI views for your app:

```swift
import SwiftUI

struct ContentView: View {
    @State private var client = NostrClient()
    @State private var newNoteText = ""
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Connection status
                HStack {
                    Circle()
                        .fill(client.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(client.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Events feed
                List(client.events) { event in
                    EventRow(event: event)
                }
                .refreshable {
                    await client.reconnect()
                }
                
                // New note input
                HStack {
                    TextField("What's happening?", text: $newNoteText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...4)
                    
                    Button("Send") {
                        Task {
                            await client.publishTextNote(newNoteText)
                            newNoteText = ""
                        }
                    }
                    .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("NOSTR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Profile") {
                        showingProfile = true
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView(client: client)
            }
        }
    }
}

struct EventRow: View {
    let event: NostrEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.pubkey.prefix(8) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(event.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if event.isTextNote {
                Text(event.content)
                    .font(.body)
            } else if event.isMetadata {
                Text("Updated profile")
                    .font(.body)
                    .italic()
                    .foregroundColor(.secondary)
            }
            
            if !event.tags.isEmpty {
                HStack {
                    ForEach(event.tags.prefix(3), id: \.self) { tag in
                        if tag.count >= 2 {
                            Text("#\(tag[0])")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProfileView: View {
    let client: NostrClient
    @State private var name = ""
    @State private var about = ""
    @State private var picture = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    TextField("Name", text: $name)
                    TextField("About", text: $about, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Picture URL", text: $picture)
                }
                
                Section("Your Public Key") {
                    if let publicKey = client.publicKey {
                        Text(publicKey)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await client.updateProfile(
                                name: name,
                                about: about,
                                picture: picture.isEmpty ? nil : picture
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            if let profile = client.userProfile {
                name = profile.name ?? ""
                about = profile.about ?? ""
                picture = profile.picture ?? ""
            }
        }
    }
}
```

## Step 9: Error Handling and Edge Cases

Add robust error handling:

```swift
extension NostrClient {
    enum ClientError: LocalizedError {
        case notConnected
        case keyPairMissing
        case eventCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Not connected to any relays"
            case .keyPairMissing:
                return "No key pair available"
            case .eventCreationFailed:
                return "Failed to create event"
            }
        }
    }
    
    func handleError(_ error: Error) {
        print("NOSTR Client Error: \(error.localizedDescription)")
        
        // In a real app, you might want to show user-friendly error messages
        // or attempt automatic recovery
        
        if case NostrError.networkError = error {
            // Try to reconnect
            Task {
                await reconnect()
            }
        }
    }
}
```

## Step 10: Testing Your App

Create unit tests for your NOSTR client:

```swift
import Testing
@testable import YourNostrApp

@Test func testKeyGeneration() async throws {
    let client = NostrClient()
    
    // Wait for initialization
    try await Task.sleep(nanoseconds: 1_000_000_000)
    
    #expect(client.publicKey != nil)
    #expect(client.isLoggedIn == true)
}

@Test func testEventCreation() async throws {
    let client = NostrClient()
    
    // Wait for initialization
    try await Task.sleep(nanoseconds: 1_000_000_000)
    
    await client.publishTextNote("Test note")
    
    #expect(client.events.count > 0)
    #expect(client.events.first?.content == "Test note")
}
```

## Conclusion

You've now built a complete NOSTR application with CoreNostr! The app includes:

- ✅ Key management and generation
- ✅ Multiple relay connections
- ✅ Event publishing (text notes, metadata)
- ✅ Real-time event subscription
- ✅ SwiftUI interface
- ✅ Error handling
- ✅ Profile management

## Next Steps

To enhance your app further, consider:

1. **Persistence**: Store events and keys locally using SwiftData or Core Data
2. **Media Support**: Add image and video support with NIP-94
3. **Direct Messages**: Implement encrypted direct messaging with NIP-04
4. **Advanced Features**: Add reactions, reposts, and threading
5. **Relay Management**: Allow users to add/remove relays
6. **Search**: Implement event and user search functionality
7. **Notifications**: Add push notifications for mentions and replies

## See Also

- ``CoreNostr``
- ``KeyPair``
- ``RelayConnection``
- ``RelayPool``
- ``NostrEvent``
- ``Filter``