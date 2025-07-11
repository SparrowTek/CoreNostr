import Foundation
import Combine

// MARK: - Message Types

/// Messages sent from clients to relays.
/// 
/// These messages follow the NOSTR protocol specification for client-to-relay communication.
public enum ClientMessage: Codable, Sendable {
    /// Publish an event to the relay
    case event(NostrEvent)
    
    /// Request events matching the provided filters
    case req(subscriptionId: String, filters: [Filter])
    
    /// Close a subscription
    case close(subscriptionId: String)
    
    /// Encodes the message to JSON format for transmission to relays.
    /// 
    /// - Returns: JSON string representation of the message
    /// - Throws: ``NostrError/serializationError(_:)`` if encoding fails
    public func encode() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        
        switch self {
        case .event(let event):
            let eventData = try encoder.encode(event)
            guard let eventDict = try JSONSerialization.jsonObject(with: eventData) as? [String: Any] else {
                throw NostrError.serializationError("Failed to serialize event")
            }
            let jsonArray: [Any] = ["EVENT", eventDict]
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.withoutEscapingSlashes])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NostrError.serializationError("Failed to encode client message")
            }
            return jsonString
            
        case .req(let subscriptionId, let filters):
            var jsonArray: [Any] = ["REQ", subscriptionId]
            for filter in filters {
                let filterData = try encoder.encode(filter)
                guard let filterDict = try JSONSerialization.jsonObject(with: filterData) as? [String: Any] else {
                    throw NostrError.serializationError("Failed to serialize filter")
                }
                jsonArray.append(filterDict)
            }
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.withoutEscapingSlashes])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NostrError.serializationError("Failed to encode client message")
            }
            return jsonString
            
        case .close(let subscriptionId):
            let jsonArray: [Any] = ["CLOSE", subscriptionId]
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.withoutEscapingSlashes])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NostrError.serializationError("Failed to encode client message")
            }
            return jsonString
        }
    }
}

/// Messages sent from relays to clients.
/// 
/// These messages follow the NOSTR protocol specification for relay-to-client communication.
public enum RelayMessage: Codable, Sendable {
    /// An event matching a subscription
    case event(subscriptionId: String, event: NostrEvent)
    
    /// Confirmation of event publication
    case ok(eventId: EventID, accepted: Bool, message: String?)
    
    /// End of stored events for a subscription
    case eose(subscriptionId: String)
    
    /// Subscription was closed by the relay
    case closed(subscriptionId: String, message: String?)
    
    /// Notice message from the relay
    case notice(message: String)
    
    /// Authentication challenge from the relay
    case auth(challenge: String)
    
    /// Decodes a relay message from JSON format.
    /// 
    /// - Parameter jsonString: JSON string received from relay
    /// - Returns: Decoded RelayMessage
    /// - Throws: ``NostrError/serializationError(_:)`` if decoding fails
    public static func decode(from jsonString: String) throws -> RelayMessage {
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
              let messageType = jsonArray.first as? String else {
            throw NostrError.serializationError("Invalid message format")
        }
        
        switch messageType {
        case "EVENT":
            guard jsonArray.count >= 3,
                  let subscriptionId = jsonArray[1] as? String,
                  let eventDict = jsonArray[2] as? [String: Any] else {
                throw NostrError.serializationError("Invalid EVENT message format")
            }
            
            let eventData = try JSONSerialization.data(withJSONObject: eventDict)
            let event = try JSONDecoder().decode(NostrEvent.self, from: eventData)
            return .event(subscriptionId: subscriptionId, event: event)
            
        case "OK":
            guard jsonArray.count >= 3,
                  let eventId = jsonArray[1] as? String,
                  let accepted = jsonArray[2] as? Bool else {
                throw NostrError.serializationError("Invalid OK message format")
            }
            let message = jsonArray.count > 3 ? jsonArray[3] as? String : nil
            return .ok(eventId: eventId, accepted: accepted, message: message)
            
        case "EOSE":
            guard jsonArray.count >= 2,
                  let subscriptionId = jsonArray[1] as? String else {
                throw NostrError.serializationError("Invalid EOSE message format")
            }
            return .eose(subscriptionId: subscriptionId)
            
        case "CLOSED":
            guard jsonArray.count >= 2,
                  let subscriptionId = jsonArray[1] as? String else {
                throw NostrError.serializationError("Invalid CLOSED message format")
            }
            let message = jsonArray.count > 2 ? jsonArray[2] as? String : nil
            return .closed(subscriptionId: subscriptionId, message: message)
            
        case "NOTICE":
            guard jsonArray.count >= 2,
                  let message = jsonArray[1] as? String else {
                throw NostrError.serializationError("Invalid NOTICE message format")
            }
            return .notice(message: message)
            
        case "AUTH":
            guard jsonArray.count >= 2,
                  let challenge = jsonArray[1] as? String else {
                throw NostrError.serializationError("Invalid AUTH message format")
            }
            return .auth(challenge: challenge)
            
        default:
            throw NostrError.serializationError("Unknown message type: \(messageType)")
        }
    }
}

// MARK: - Connection State

/// The current state of a relay connection.
public enum ConnectionState: Sendable, Equatable {
    /// Not connected to any relay
    case disconnected
    
    /// In the process of connecting
    case connecting
    
    /// Successfully connected and ready for communication
    case connected
    
    /// Connection failed with an error message
    case error(String)
    
    public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected), (.connecting, .connecting), (.connected, .connected):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - RelayConnection

/// Manages a WebSocket connection to a single NOSTR relay.
/// 
/// RelayConnection handles the low-level WebSocket communication with a relay,
/// including connection management, message sending, and receiving.
/// 
/// ## Usage
/// ```swift
/// let relay = RelayConnection()
/// try await relay.connect(to: URL(string: "wss://relay.example.com")!)
/// 
/// // Send a message
/// try await relay.send(.event(signedEvent))
/// 
/// // Listen for responses
/// for await message in relay.messages {
///     switch message {
///     case .event(let subId, let event):
///         print("Received event: \(event.content)")
///     default:
///         break
///     }
/// }
/// ```
@MainActor
public class RelayConnection: ObservableObject {
    /// The current connection state
    @Published public private(set) var state: ConnectionState = .disconnected
    
    /// The URL of the connected relay
    @Published public private(set) var url: URL?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageContinuation: AsyncStream<RelayMessage>.Continuation?
    private var messageStream: AsyncStream<RelayMessage>?
    
    /// Creates a new relay connection.
    public init() {}
    
    deinit {
        Task { [weak self] in
            await self?.disconnect()
        }
    }
    
    /// Connects to a NOSTR relay.
    /// 
    /// - Parameter url: The WebSocket URL of the relay
    /// - Throws: ``NostrError/networkError(_:)`` if connection fails
    public func connect(to url: URL) async throws {
        guard state == .disconnected else {
            throw NostrError.networkError("Already connected or connecting")
        }
        
        self.url = url
        state = .connecting
        
        do {
            let session = URLSession.shared
            webSocketTask = session.webSocketTask(with: url)
            
            // Create the message stream
            let (stream, continuation) = AsyncStream<RelayMessage>.makeStream()
            messageStream = stream
            messageContinuation = continuation
            
            webSocketTask?.resume()
            
            // Start listening for messages
            await startListening()
            
            state = .connected
        } catch {
            state = .error("Failed to connect: \(error.localizedDescription)")
            throw NostrError.networkError("Failed to connect: \(error.localizedDescription)")
        }
    }
    
    /// Disconnects from the relay and cleans up resources.
    public func disconnect() async {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messageContinuation?.finish()
        messageContinuation = nil
        messageStream = nil
        state = .disconnected
        url = nil
    }
    
    /// Sends a message to the connected relay.
    /// 
    /// - Parameter message: The message to send
    /// - Throws: ``NostrError/networkError(_:)`` if sending fails or not connected
    public func send(_ message: ClientMessage) async throws {
        guard state == .connected, let webSocketTask = webSocketTask else {
            throw NostrError.networkError("Not connected to relay")
        }
        
        do {
            let messageString = try message.encode()
            let webSocketMessage = URLSessionWebSocketTask.Message.string(messageString)
            try await webSocketTask.send(webSocketMessage)
        } catch {
            throw NostrError.networkError("Failed to send message: \(error.localizedDescription)")
        }
    }
    
    /// Stream of messages received from the relay.
    /// 
    /// Use this to listen for events, confirmations, and other relay responses.
    public var messages: AsyncStream<RelayMessage> {
        return messageStream ?? AsyncStream { _ in }
    }
    
    /// Starts listening for messages from the WebSocket.
    private func startListening() async {
        guard let webSocketTask = webSocketTask else { return }
        
        Task {
            while state == .connected {
                do {
                    let message = try await webSocketTask.receive()
                    await handleWebSocketMessage(message)
                } catch {
                    await MainActor.run {
                        self.state = .error("Connection error: \(error.localizedDescription)")
                    }
                    break
                }
            }
        }
    }
    
    /// Handles incoming WebSocket messages and converts them to RelayMessages.
    /// 
    /// - Parameter message: The WebSocket message to handle
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            do {
                let relayMessage = try RelayMessage.decode(from: text)
                messageContinuation?.yield(relayMessage)
            } catch {
                print("Failed to decode relay message: \(error)")
            }
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await handleWebSocketMessage(.string(text))
            }
        @unknown default:
            break
        }
    }
}

// MARK: - Relay Pool

/// Manages connections to multiple NOSTR relays.
/// 
/// RelayPool allows you to connect to multiple relays simultaneously,
/// broadcast messages to all connected relays, and aggregate responses.
/// 
/// ## Usage
/// ```swift
/// let pool = RelayPool()
/// try await pool.addRelay(URL(string: "wss://relay1.example.com")!)
/// try await pool.addRelay(URL(string: "wss://relay2.example.com")!)
/// 
/// // Broadcast to all relays
/// await pool.publishEvent(signedEvent)
/// 
/// // Listen to all relays
/// for await (relayURL, message) in pool.allMessages {
///     print("From \(relayURL): \(message)")
/// }
/// ```
@MainActor
public class RelayPool: ObservableObject {
    /// Dictionary of relay URLs to their connections
    /// Dictionary of relay URLs to their connections
    @Published public private(set) var connections: [URL: RelayConnection] = [:]
    
    /// Creates a new relay pool.
    public init() {}
    
    /// Adds a new relay to the pool and connects to it.
    /// 
    /// - Parameter url: The WebSocket URL of the relay
    /// - Throws: ``NostrError/networkError(_:)`` if the relay already exists or connection fails
    public func addRelay(_ url: URL) async throws {
        guard connections[url] == nil else {
            throw NostrError.networkError("Relay already exists")
        }
        
        let connection = RelayConnection()
        connections[url] = connection
        try await connection.connect(to: url)
    }
    
    /// Removes a relay from the pool and disconnects from it.
    /// 
    /// - Parameter url: The URL of the relay to remove
    public func removeRelay(_ url: URL) async {
        if let connection = connections[url] {
            await connection.disconnect()
            connections.removeValue(forKey: url)
        }
    }
    
    /// Broadcasts a message to all connected relays.
    /// 
    /// - Parameter message: The message to broadcast
    public func broadcast(_ message: ClientMessage) async {
        await withTaskGroup(of: Void.self) { group in
            for connection in connections.values {
                group.addTask {
                    do {
                        try await connection.send(message)
                    } catch {
                        print("Failed to send message to relay: \(error)")
                    }
                }
            }
        }
    }
    
    /// Subscribes to events matching the given filters on all relays.
    /// 
    /// - Parameters:
    ///   - subscriptionId: Unique identifier for this subscription
    ///   - filters: Array of filters to match events
    public func subscribe(subscriptionId: String, filters: [Filter]) async {
        let message = ClientMessage.req(subscriptionId: subscriptionId, filters: filters)
        await broadcast(message)
    }
    
    /// Unsubscribes from events with the given subscription ID on all relays.
    /// 
    /// - Parameter subscriptionId: The subscription ID to close
    public func unsubscribe(subscriptionId: String) async {
        let message = ClientMessage.close(subscriptionId: subscriptionId)
        await broadcast(message)
    }
    
    /// Publishes an event to all connected relays.
    /// 
    /// - Parameter event: The signed event to publish
    public func publishEvent(_ event: NostrEvent) async {
        let message = ClientMessage.event(event)
        await broadcast(message)
    }
    
    /// Stream of all messages from all connected relays.
    /// 
    /// Each message is paired with the URL of the relay it came from.
    public var allMessages: AsyncStream<(URL, RelayMessage)> {
        return AsyncStream { continuation in
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for (url, connection) in connections {
                        group.addTask {
                            for await message in await connection.messages {
                                continuation.yield((url, message))
                            }
                        }
                    }
                }
            }
        }
    }
}