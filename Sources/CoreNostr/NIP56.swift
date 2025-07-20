//
//  NIP56.swift
//  CoreNostr
//
//  NIP-56: Reporting
//  https://github.com/nostr-protocol/nips/blob/master/56.md
//

import Foundation

/// NIP-56: Reporting
///
/// This NIP defines a mechanism for users to report objectionable content.
/// Reports are events of kind 1984 that can be used by clients and relays
/// for moderation purposes.
///
/// ## Example Usage
/// ```swift
/// // Report a user for spam
/// let report = try NIP56.createReport(
///     reportedPubkey: "spammer-pubkey",
///     reportType: .spam,
///     content: "Sending repetitive promotional messages",
///     reporterKeyPair: keyPair
/// )
/// 
/// // Report a specific event
/// let eventReport = try NIP56.createReport(
///     reportedPubkey: "author-pubkey",
///     reportedEventId: "event-id",
///     reportType: .illegal,
///     content: "Contains potentially illegal content",
///     reporterKeyPair: keyPair
/// )
/// ```
public enum NIP56 {
    
    /// The event kind for reporting (1984 - reference to Orwell)
    public static let reportEventKind = 1984
    
    /// Types of reports as defined in NIP-56
    public enum ReportType: String, CaseIterable, Codable, Sendable {
        case nudity = "nudity"
        case malware = "malware"
        case profanity = "profanity"
        case illegal = "illegal"
        case spam = "spam"
        case impersonation = "impersonation"
        case other = "other"
        
        /// Human-readable description of the report type
        public var description: String {
            switch self {
            case .nudity:
                return "Pornographic or adult content including nudity"
            case .malware:
                return "Virus, trojan, worm, robot, spyware, adware, or other malicious content"
            case .profanity:
                return "Profanity, hateful speech, or other harmful content"
            case .illegal:
                return "Content that may be illegal in some jurisdictions"
            case .spam:
                return "Spam or repetitive unwanted content"
            case .impersonation:
                return "Someone pretending to be someone else"
            case .other:
                return "Other objectionable content"
            }
        }
    }
    
    /// Creates a report event.
    ///
    /// - Parameters:
    ///   - reportedPubkey: The public key of the user being reported
    ///   - reportedEventId: Optional event ID if reporting a specific event
    ///   - reportType: The type of report
    ///   - content: Detailed description of the report
    ///   - reporterKeyPair: The key pair of the reporter
    /// - Returns: A signed report event
    /// - Throws: NostrError if signing fails
    public static func createReport(
        reportedPubkey: PublicKey,
        reportedEventId: EventID? = nil,
        reportType: ReportType,
        content: String,
        reporterKeyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        // Required: Add reported user's pubkey
        tags.append(["p", reportedPubkey, reportType.rawValue])
        
        // Optional: Add event ID if reporting a specific event
        if let eventId = reportedEventId {
            tags.append(["e", eventId, reportType.rawValue])
        }
        
        let event = NostrEvent(
            pubkey: reporterKeyPair.publicKey,
            createdAt: Date(),
            kind: reportEventKind,
            tags: tags,
            content: content
        )
        
        return try reporterKeyPair.signEvent(event)
    }
    
    /// Parses a report from an event.
    ///
    /// - Parameter event: The event to parse
    /// - Returns: A report if the event is valid, nil otherwise
    public static func parseReport(from event: NostrEvent) -> Report? {
        guard event.kind == reportEventKind else {
            return nil
        }
        
        // Find the reported pubkey (required)
        guard let pTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "p" }) else {
            return nil
        }
        
        let reportedPubkey = pTag[1]
        let reportTypeFromP = pTag.count >= 3 ? ReportType(rawValue: pTag[2]) : nil
        
        // Find the reported event ID (optional)
        let eTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "e" })
        let reportedEventId = eTag?[1]
        let reportTypeFromE = eTag != nil && eTag!.count >= 3 ? ReportType(rawValue: eTag![2]) : nil
        
        // Determine report type (prefer e tag type if available)
        let reportType = reportTypeFromE ?? reportTypeFromP ?? .other
        
        return Report(
            id: event.id,
            reporterPubkey: event.pubkey,
            reportedPubkey: reportedPubkey,
            reportedEventId: reportedEventId,
            reportType: reportType,
            content: event.content,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            event: event
        )
    }
    
    /// A parsed report structure
    public struct Report: Codable, Sendable {
        /// The ID of the report event
        public let id: EventID
        
        /// The public key of the reporter
        public let reporterPubkey: PublicKey
        
        /// The public key of the reported user
        public let reportedPubkey: PublicKey
        
        /// The ID of the reported event (if applicable)
        public let reportedEventId: EventID?
        
        /// The type of report
        public let reportType: ReportType
        
        /// Detailed description of the report
        public let content: String
        
        /// When the report was created
        public let createdAt: Date
        
        /// The original event
        public let event: NostrEvent
    }
}

// MARK: - Report Analysis

extension NIP56 {
    /// Analyzes reports for a specific user.
    ///
    /// - Parameters:
    ///   - pubkey: The public key to analyze reports for
    ///   - reports: Collection of report events
    /// - Returns: Analysis of reports for the user
    public static func analyzeReports(
        for pubkey: PublicKey,
        in reports: [NostrEvent]
    ) -> ReportAnalysis {
        let parsedReports = reports.compactMap { parseReport(from: $0) }
        let userReports = parsedReports.filter { $0.reportedPubkey == pubkey }
        
        var typeCount: [ReportType: Int] = [:]
        var reporters = Set<PublicKey>()
        
        for report in userReports {
            typeCount[report.reportType, default: 0] += 1
            reporters.insert(report.reporterPubkey)
        }
        
        return ReportAnalysis(
            totalReports: userReports.count,
            uniqueReporters: reporters.count,
            reportsByType: typeCount,
            reports: userReports
        )
    }
    
    /// Analysis of reports for a user
    public struct ReportAnalysis {
        /// Total number of reports
        public let totalReports: Int
        
        /// Number of unique reporters
        public let uniqueReporters: Int
        
        /// Breakdown by report type
        public let reportsByType: [ReportType: Int]
        
        /// The actual reports
        public let reports: [Report]
        
        /// The most common report type
        public var mostCommonType: ReportType? {
            reportsByType.max(by: { $0.value < $1.value })?.key
        }
    }
}

// MARK: - Filter Extensions

extension Filter {
    /// Creates a filter for fetching reports.
    ///
    /// - Parameters:
    ///   - reportedPubkeys: Public keys to fetch reports for
    ///   - reporters: Only include reports from these reporters
    ///   - limit: Maximum number of reports
    /// - Returns: A filter for report events
    public static func reports(
        reportedPubkeys: [PublicKey]? = nil,
        reporters: [PublicKey]? = nil,
        limit: Int? = 100
    ) -> Filter {
        return Filter(
            authors: reporters,
            kinds: [NIP56.reportEventKind],
            limit: limit,
            p: reportedPubkeys
        )
    }
    
    /// Creates a filter for fetching reports about specific events.
    ///
    /// - Parameters:
    ///   - eventIds: Event IDs to fetch reports for
    ///   - reporters: Only include reports from these reporters
    ///   - limit: Maximum number of reports
    /// - Returns: A filter for report events
    public static func eventReports(
        eventIds: [EventID],
        reporters: [PublicKey]? = nil,
        limit: Int? = 100
    ) -> Filter {
        return Filter(
            authors: reporters,
            kinds: [NIP56.reportEventKind],
            limit: limit,
            e: eventIds
        )
    }
}

