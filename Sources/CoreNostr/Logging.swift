import Foundation
#if canImport(os)
import os
#endif

public enum NostrLogLevel: Int, Sendable {
    case debug = 0
    case info = 1
    case warn = 2
    case error = 3
    case none = 4
}

public struct NostrLogger: Sendable {
    public static var level: NostrLogLevel = .warn
    public static var isEnabled: Bool = true
    public static var subsystem: String = "dev.sparrowtek.corenostr"
    public static var category: String = "CoreNostr"

    public static func setLevel(_ newLevel: NostrLogLevel) { level = newLevel }

    public static func debug(_ message: @autoclosure () -> String) { log(.debug, message()) }
    public static func info(_ message: @autoclosure () -> String)  { log(.info,  message()) }
    public static func warn(_ message: @autoclosure () -> String)  { log(.warn,  message()) }
    public static func error(_ message: @autoclosure () -> String) { log(.error, message()) }

    private static func log(_ level: NostrLogLevel, _ message: String) {
        guard isEnabled, level.rawValue >= Self.level.rawValue, Self.level != .none else { return }
        let redacted = redactSecrets(in: message)
        #if canImport(os)
        let logger = Logger(subsystem: subsystem, category: category)
        switch level {
        case .debug: logger.debug("\(redacted, privacy: .public)")
        case .info:  logger.info("\(redacted, privacy: .public)")
        case .warn:  logger.warning("\(redacted, privacy: .public)")
        case .error: logger.error("\(redacted, privacy: .public)")
        case .none:  break
        }
        #else
        let prefix: String
        switch level {
        case .debug: prefix = "[DEBUG]"
        case .info:  prefix = "[INFO]"
        case .warn:  prefix = "[WARN]"
        case .error: prefix = "[ERROR]"
        case .none:  return
        }
        print("CoreNostr \(prefix) \(redacted)")
        #endif
    }

    /// Redact likely secrets (64-hex keys, 128-hex signatures, bech32 nsec strings)
    private static func redactSecrets(in text: String) -> String {
        var result = text
        // Redact 64-hex (keys) and 128-hex (sigs)
        let hexPatterns = ["[0-9a-fA-F]{64}", "[0-9a-fA-F]{128}"]
        for pattern in hexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: (result as NSString).length)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range) { match -> String in
                    let matched = (result as NSString).substring(with: match.range)
                    return mask(matched)
                }
            }
        }
        // Redact bech32 secrets starting with nsec1
        if let regex = try? NSRegularExpression(pattern: "nsec1[02-9ac-hj-np-z]{10,}", options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: (result as NSString).length)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range) { match -> String in
                let matched = (result as NSString).substring(with: match.range)
                return mask(matched)
            }
        }
        return result
    }

    private static func mask(_ s: String) -> String {
        guard s.count > 10 else { return "[REDACTED]" }
        let start = s.prefix(6)
        let end = s.suffix(4)
        return "\(start)…\(end) [REDACTED]"
    }
}


