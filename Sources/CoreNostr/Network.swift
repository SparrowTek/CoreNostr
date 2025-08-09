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
                throw NostrError.serializationError(type: "NostrEvent", reason: "Failed to encode event to JSON")
            }
            let jsonArray: [Any] = ["EVENT", eventDict]
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.withoutEscapingSlashes])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NostrError.serializationError(type: "ClientMessage", reason: "Failed to encode message array to JSON")
            }
            return jsonString
            
        case .req(let subscriptionId, let filters):
            var jsonArray: [Any] = ["REQ", subscriptionId]
            for filter in filters {
                let filterData = try encoder.encode(filter)
                guard let filterDict = try JSONSerialization.jsonObject(with: filterData) as? [String: Any] else {
                    throw NostrError.serializationError(type: "Filter", reason: "Failed to encode filter to JSON")
                }
                jsonArray.append(filterDict)
            }
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.withoutEscapingSlashes])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NostrError.serializationError(type: "ClientMessage", reason: "Failed to encode message array to JSON")
            }
            return jsonString
            
        case .close(let subscriptionId):
            let jsonArray: [Any] = ["CLOSE", subscriptionId]
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.withoutEscapingSlashes])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NostrError.serializationError(type: "ClientMessage", reason: "Failed to encode message array to JSON")
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
            throw NostrError.serializationError(type: "RelayMessage", reason: "Message must be a JSON array")
        }
        
        switch messageType {
        case "EVENT":
            guard jsonArray.count >= 3,
                  let subscriptionId = jsonArray[1] as? String,
                  let eventDict = jsonArray[2] as? [String: Any] else {
                throw NostrError.serializationError(type: "EVENT message", reason: "Expected format: [\"EVENT\", \"subscription_id\", {event_object}]")
            }
            
            let eventData = try JSONSerialization.data(withJSONObject: eventDict)
            let event = try JSONDecoder().decode(NostrEvent.self, from: eventData)
            return .event(subscriptionId: subscriptionId, event: event)
            
        case "OK":
            guard jsonArray.count >= 3,
                  let eventId = jsonArray[1] as? String,
                  let accepted = jsonArray[2] as? Bool else {
                throw NostrError.serializationError(type: "OK message", reason: "Expected format: [\"OK\", \"event_id\", accepted: bool, \"message\"]")
            }
            let message = jsonArray.count > 3 ? jsonArray[3] as? String : nil
            return .ok(eventId: eventId, accepted: accepted, message: message)
            
        case "EOSE":
            guard jsonArray.count >= 2,
                  let subscriptionId = jsonArray[1] as? String else {
                throw NostrError.serializationError(type: "EOSE message", reason: "Expected format: [\"EOSE\", \"subscription_id\"]")
            }
            return .eose(subscriptionId: subscriptionId)
            
        case "CLOSED":
            guard jsonArray.count >= 2,
                  let subscriptionId = jsonArray[1] as? String else {
                throw NostrError.serializationError(type: "CLOSED message", reason: "Expected format: [\"CLOSED\", \"subscription_id\", \"message\"]")
            }
            let message = jsonArray.count > 2 ? jsonArray[2] as? String : nil
            return .closed(subscriptionId: subscriptionId, message: message)
            
        case "NOTICE":
            guard jsonArray.count >= 2,
                  let message = jsonArray[1] as? String else {
                throw NostrError.serializationError(type: "NOTICE message", reason: "Expected format: [\"NOTICE\", \"message\"]")
            }
            return .notice(message: message)
            
        case "AUTH":
            guard jsonArray.count >= 2,
                  let challenge = jsonArray[1] as? String else {
                throw NostrError.serializationError(type: "AUTH message", reason: "Expected format: [\"AUTH\", \"challenge\"]")
            }
            return .auth(challenge: challenge)
            
        default:
            throw NostrError.protocolViolation(reason: "Unknown message type: '\(messageType)'. Expected EVENT, OK, EOSE, CLOSED, NOTICE, or AUTH")
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
@Observable
public class RelayConnection {
    /// The current connection state
    public private(set) var state: ConnectionState = .disconnected
    
    /// The URL of the connected relay
    public private(set) var url: URL?
    
    // Move networking off the main actor via RelayIO
    private var io: RelayIOProtocol?

    private var webSocketTask: URLSessionWebSocketTask?
    private var messageContinuation: AsyncStream<RelayMessage>.Continuation?
    private var messageStream: AsyncStream<RelayMessage>?
    
    // Keepalive and reconnection
    private var pingTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts: Int = 0
    
    /// Whether to automatically reconnect on errors
    public var autoReconnect: Bool = true
    
    /// Interval between pings in seconds
    public var pingInterval: TimeInterval = 30
    
    /// Creates a new relay connection.
    public init() {}

    /// Internal initializer for injecting a custom IO layer (used in tests)
    /// - Parameter io: An instance conforming to `RelayIOProtocol`
    init(io: RelayIOProtocol) {
        self.io = io
    }
    
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
            throw NostrError.networkError(operation: .connect, reason: "Already connected or connection in progress")
        }
        
        self.url = url
        state = .connecting
        let io: RelayIOProtocol = self.io ?? RelayIO(url: url, pingInterval: pingInterval, autoReconnect: autoReconnect)
        self.io = io
        do {
            try await io.connect()
            // Cache messages stream for main-actor access
            self.messageStream = await io.getMessages()
            if let stateStream = await io.getStateStream() {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    for await s in stateStream {
                        self.state = s
                        if s == .connected {
                            self.messageStream = await io.getMessages()
                        }
                    }
                }
            }
            state = .connected
        } catch {
            state = .error("Connection error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Disconnects from the relay and cleans up resources.
    public func disconnect() async {
        await io?.disconnect()
        io = nil
        state = .disconnected
        url = nil
    }
    
    /// Sends a message to the connected relay.
    /// 
    /// - Parameter message: The message to send
    /// - Throws: ``NostrError/networkError(_:)`` if sending fails or not connected
    public func send(_ message: ClientMessage) async throws {
        guard state == .connected, let io = io else {
            throw NostrError.networkError(operation: .send, reason: "Not connected to relay")
        }
        do {
            let messageString = try message.encode()
            try await io.sendString(messageString)
        } catch {
            throw NostrError.networkError(operation: .send, reason: "WebSocket send failed: \(error.localizedDescription)")
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
        while !Task.isCancelled {
            do {
                let message = try await webSocketTask.receive()
                await handleWebSocketMessage(message)
            } catch {
                await MainActor.run {
                    self.state = .error("Connection error: \(error.localizedDescription)")
                }
                await handleConnectionErrorAndMaybeReconnect()
                break
            }
        }
    }

    private func startPinging() {
        pingTask?.cancel()
        guard let webSocketTask = webSocketTask else { return }
        let interval = pingInterval
        pingTask = Task { [weak self] in
            while let self = self, !Task.isCancelled, self.state == .connected {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                webSocketTask.sendPing { error in
                    if let error = error {
                        Task { @MainActor in
                            self.state = .error("Ping failed: \(error.localizedDescription)")
                            await self.handleConnectionErrorAndMaybeReconnect()
                        }
                    }
                }
            }
        }
    }

    private func cleanupConnection(keepURL: Bool) {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messageContinuation?.finish()
        messageContinuation = nil
        messageStream = nil
        listenTask?.cancel()
        listenTask = nil
        pingTask?.cancel()
        pingTask = nil
        if !keepURL {
            url = nil
        }
    }

    private func handleConnectionErrorAndMaybeReconnect() async {
        // Clean up but keep URL for reconnect
        cleanupConnection(keepURL: true)
        if autoReconnect, let url = self.url {
            scheduleReconnect(to: url)
        }
    }

    private func scheduleReconnect(to url: URL) {
        reconnectTask?.cancel()
        reconnectAttempts += 1
        let baseDelay: Double = 1.0
        let exp = pow(2.0, Double(max(0, reconnectAttempts - 1))) * baseDelay
        let delay = min(60.0, exp)
        let jitter = Double.random(in: 0...(delay * 0.2))
        let totalDelay = delay + jitter
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
            guard let self = self else { return }
            await MainActor.run {
                self.state = .connecting
            }
            do {
                try await self.connect(to: url)
            } catch {
                await MainActor.run {
                    self.state = .error("Reconnect failed: \(error.localizedDescription)")
                }
                // Schedule again
                self.scheduleReconnect(to: url)
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
@Observable
public class RelayPool {
    /// Dictionary of relay URLs to their connections
    /// Dictionary of relay URLs to their connections
    public private(set) var connections: [URL: RelayConnection] = [:]
    
    /// Creates a new relay pool.
    public init() {}
    
    /// Adds a new relay to the pool and connects to it.
    /// 
    /// - Parameter url: The WebSocket URL of the relay
    /// - Throws: ``NostrError/networkError(_:)`` if the relay already exists or connection fails
    public func addRelay(_ url: URL) async throws {
        guard connections[url] == nil else {
            throw NostrError.validationError(field: "relayURL", reason: "Relay with URL '\(url)' already exists in pool")
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

// MARK: - RelayIO (off-main-actor WebSocket handler)

// Internal protocol to allow dependency injection of IO in tests
protocol RelayIOProtocol: AnyObject, Sendable {
    func connect() async throws
    func getMessages() async -> AsyncStream<RelayMessage>?
    func getStateStream() async -> AsyncStream<ConnectionState>?
    func disconnect() async
    func sendString(_ string: String) async throws
}

actor RelayIO: RelayIOProtocol {
    let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageContinuation: AsyncStream<RelayMessage>.Continuation?
    private(set) var messages: AsyncStream<RelayMessage>?
    private var pingTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts: Int = 0
    private let autoReconnect: Bool
    private let pingInterval: TimeInterval
    private let readTimeout: TimeInterval = 30
    private var lastReceiveAt: Date = .distantPast
    private var timeoutTask: Task<Void, Never>?
    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private(set) var stateStream: AsyncStream<ConnectionState>?
    
    init(url: URL, pingInterval: TimeInterval, autoReconnect: Bool) {
        self.url = url
        self.pingInterval = pingInterval
        self.autoReconnect = autoReconnect
    }
    
    func connect() async throws {
        guard webSocketTask == nil else { return }
        let session = URLSession.shared
        webSocketTask = session.webSocketTask(with: url)
        if messages == nil {
            let (stream, continuation) = AsyncStream<RelayMessage>.makeStream()
            messages = stream
            messageContinuation = continuation
        }
        if stateStream == nil {
            let (s, c) = AsyncStream<ConnectionState>.makeStream()
            stateStream = s
            stateContinuation = c
        }
        webSocketTask?.resume()
        
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            await self?.startListening()
        }
        startPinging()
        startTimeoutWatcher()
        stateContinuation?.yield(.connected)
    }
    
    func getMessages() async -> AsyncStream<RelayMessage>? { messages }
    func getStateStream() async -> AsyncStream<ConnectionState>? { stateStream }
    
    func disconnect() async {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messageContinuation?.finish()
        messageContinuation = nil
        messages = nil
        listenTask?.cancel()
        listenTask = nil
        pingTask?.cancel()
        pingTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
        stateContinuation?.finish()
        stateContinuation = nil
        stateStream = nil
    }
    
    func sendString(_ string: String) async throws {
        guard let task = webSocketTask else {
            throw NostrError.networkError(operation: .send, reason: "Not connected")
        }
        try await task.send(.string(string))
    }
    
    private func startListening() async {
        guard let task = webSocketTask else { return }
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let relayMessage = try? RelayMessage.decode(from: text) {
                        lastReceiveAt = Date()
                        messageContinuation?.yield(relayMessage)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8),
                       let relayMessage = try? RelayMessage.decode(from: text) {
                        lastReceiveAt = Date()
                        messageContinuation?.yield(relayMessage)
                    }
                @unknown default:
                    break
                }
            } catch {
                stateContinuation?.yield(.disconnected)
                await handleConnectionErrorAndMaybeReconnect()
                break
            }
        }
    }
    
    private func startPinging() {
        pingTask?.cancel()
        guard let task = webSocketTask else { return }
        let interval = pingInterval
        pingTask = Task { [weak self] in
            while let self = self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                task.sendPing { error in
                    if error != nil {
                        Task {
                            await self.stateContinuation?.yield(.disconnected)
                            await self.handleConnectionErrorAndMaybeReconnect()
                        }
                    }
                }
            }
        }
    }

    private func startTimeoutWatcher() {
        timeoutTask?.cancel()
        lastReceiveAt = Date()
        let timeout = readTimeout
        timeoutTask = Task { [weak self] in
            while let self = self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self.checkTimeout()
            }
        }
    }
    
    private func checkTimeout() async {
        let elapsed = Date().timeIntervalSince(lastReceiveAt)
        if elapsed >= readTimeout {
            stateContinuation?.yield(.disconnected)
            await handleConnectionErrorAndMaybeReconnect()
        }
    }
    
    private func handleConnectionErrorAndMaybeReconnect() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        listenTask?.cancel()
        listenTask = nil
        pingTask?.cancel()
        pingTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        if autoReconnect {
            scheduleReconnect()
        } else {
            messageContinuation?.finish()
            messageContinuation = nil
            messages = nil
            stateContinuation?.finish()
            stateContinuation = nil
            stateStream = nil
        }
    }
    
    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectAttempts += 1
        let baseDelay: Double = 1.0
        let exp = pow(2.0, Double(max(0, reconnectAttempts - 1))) * baseDelay
        let delay = min(60.0, exp)
        let jitter = Double.random(in: 0...(delay * 0.2))
        let totalDelay = delay + jitter
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
            guard let self = self else { return }
            await self.stateContinuation?.yield(.connecting)
            do {
                try await self.connect()
            } catch {
                await self.scheduleReconnect()
            }
        }
    }
}
