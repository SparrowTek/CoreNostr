import Foundation
import Combine

// MARK: - Message Types
public enum ClientMessage: Codable, Sendable {
    case event(NostrEvent)
    case req(subscriptionId: String, filters: [Filter])
    case close(subscriptionId: String)
    
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

public enum RelayMessage: Codable, Sendable {
    case event(subscriptionId: String, event: NostrEvent)
    case ok(eventId: EventID, accepted: Bool, message: String?)
    case eose(subscriptionId: String)
    case closed(subscriptionId: String, message: String?)
    case notice(message: String)
    case auth(challenge: String)
    
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
public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
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
@MainActor
public class RelayConnection: ObservableObject {
    @Published public private(set) var state: ConnectionState = .disconnected
    @Published public private(set) var url: URL?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageContinuation: AsyncStream<RelayMessage>.Continuation?
    private var messageStream: AsyncStream<RelayMessage>?
    
    public init() {}
    
    deinit {
        Task { [weak self] in
            await self?.disconnect()
        }
    }
    
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
    
    public func disconnect() async {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messageContinuation?.finish()
        messageContinuation = nil
        messageStream = nil
        state = .disconnected
        url = nil
    }
    
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
    
    public var messages: AsyncStream<RelayMessage> {
        return messageStream ?? AsyncStream { _ in }
    }
    
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
@MainActor
public class RelayPool: ObservableObject {
    @Published public private(set) var connections: [URL: RelayConnection] = [:]
    
    public init() {}
    
    public func addRelay(_ url: URL) async throws {
        guard connections[url] == nil else {
            throw NostrError.networkError("Relay already exists")
        }
        
        let connection = RelayConnection()
        connections[url] = connection
        try await connection.connect(to: url)
    }
    
    public func removeRelay(_ url: URL) async {
        if let connection = connections[url] {
            await connection.disconnect()
            connections.removeValue(forKey: url)
        }
    }
    
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
    
    public func subscribe(subscriptionId: String, filters: [Filter]) async {
        let message = ClientMessage.req(subscriptionId: subscriptionId, filters: filters)
        await broadcast(message)
    }
    
    public func unsubscribe(subscriptionId: String) async {
        let message = ClientMessage.close(subscriptionId: subscriptionId)
        await broadcast(message)
    }
    
    public func publishEvent(_ event: NostrEvent) async {
        let message = ClientMessage.event(event)
        await broadcast(message)
    }
    
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