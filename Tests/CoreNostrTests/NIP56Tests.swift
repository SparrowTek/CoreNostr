//
//  NIP56Tests.swift
//  CoreNostrTests
//
//  Tests for NIP-56: Reporting
//

import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-56: Reporting")
struct NIP56Tests {
    let reporterKeyPair: KeyPair
    let reportedPubkey: PublicKey
    let eventId: EventID
    
    init() throws {
        reporterKeyPair = try KeyPair.generate()
        reportedPubkey = "reported-user-pubkey-123456789"
        eventId = "event-id-to-report-123456789"
    }
    
    @Test("Report event kind")
    func reportEventKind() throws {
        #expect(NIP56.reportEventKind == 1984)
    }
    
    @Test("Report types")
    func reportTypes() throws {
        #expect(NIP56.ReportType.allCases.count == 7)
        
        #expect(NIP56.ReportType.nudity.rawValue == "nudity")
        #expect(NIP56.ReportType.malware.rawValue == "malware")
        #expect(NIP56.ReportType.profanity.rawValue == "profanity")
        #expect(NIP56.ReportType.illegal.rawValue == "illegal")
        #expect(NIP56.ReportType.spam.rawValue == "spam")
        #expect(NIP56.ReportType.impersonation.rawValue == "impersonation")
        #expect(NIP56.ReportType.other.rawValue == "other")
    }
    
    @Test("Report type descriptions")
    func reportTypeDescriptions() throws {
        for reportType in NIP56.ReportType.allCases {
            #expect(!reportType.description.isEmpty)
        }
    }
    
    @Test("Create user report")
    func createUserReport() throws {
        let report = try NIP56.createReport(
            reportedPubkey: reportedPubkey,
            reportType: .spam,
            content: "This user is sending spam messages",
            reporterKeyPair: reporterKeyPair
        )
        
        #expect(report.kind == 1984)
        #expect(report.pubkey == reporterKeyPair.publicKey)
        #expect(report.content == "This user is sending spam messages")
        
        // Check tags
        let pTag = report.tags.first { $0[0] == "p" }
        #expect(pTag != nil)
        #expect(pTag?.count == 3)
        #expect(pTag?[1] == reportedPubkey)
        #expect(pTag?[2] == "spam")
        
        // Should not have e tag
        let eTag = report.tags.first { $0[0] == "e" }
        #expect(eTag == nil)
        
        // Verify signature
        #expect(try CoreNostr.verifyEvent(report))
    }
    
    @Test("Create event report")
    func createEventReport() throws {
        let report = try NIP56.createReport(
            reportedPubkey: reportedPubkey,
            reportedEventId: eventId,
            reportType: .illegal,
            content: "This event contains potentially illegal content",
            reporterKeyPair: reporterKeyPair
        )
        
        #expect(report.kind == 1984)
        #expect(report.content == "This event contains potentially illegal content")
        
        // Check tags
        let pTag = report.tags.first { $0[0] == "p" }
        #expect(pTag != nil)
        #expect(pTag?[1] == reportedPubkey)
        #expect(pTag?[2] == "illegal")
        
        let eTag = report.tags.first { $0[0] == "e" }
        #expect(eTag != nil)
        #expect(eTag?.count == 3)
        #expect(eTag?[1] == eventId)
        #expect(eTag?[2] == "illegal")
    }
    
    @Test("Parse user report")
    func parseUserReport() throws {
        let event = NostrEvent(
            pubkey: reporterKeyPair.publicKey,
            createdAt: Date(),
            kind: 1984,
            tags: [["p", reportedPubkey, "spam"]],
            content: "Spam report"
        )
        
        let report = NIP56.parseReport(from: event)
        #expect(report != nil)
        #expect(report?.reporterPubkey == reporterKeyPair.publicKey)
        #expect(report?.reportedPubkey == reportedPubkey)
        #expect(report?.reportedEventId == nil)
        #expect(report?.reportType == .spam)
        #expect(report?.content == "Spam report")
    }
    
    @Test("Parse event report")
    func parseEventReport() throws {
        let event = NostrEvent(
            pubkey: reporterKeyPair.publicKey,
            createdAt: Date(),
            kind: 1984,
            tags: [
                ["p", reportedPubkey, "malware"],
                ["e", eventId, "malware"]
            ],
            content: "Contains malware"
        )
        
        let report = NIP56.parseReport(from: event)
        #expect(report != nil)
        #expect(report?.reportedPubkey == reportedPubkey)
        #expect(report?.reportedEventId == eventId)
        #expect(report?.reportType == .malware)
    }
    
    @Test("Parse report with missing type")
    func parseReportMissingType() throws {
        let event = NostrEvent(
            pubkey: reporterKeyPair.publicKey,
            createdAt: Date(),
            kind: 1984,
            tags: [["p", reportedPubkey]],
            content: "Some report"
        )
        
        let report = NIP56.parseReport(from: event)
        #expect(report != nil)
        #expect(report?.reportType == .other)
    }
    
    @Test("Invalid report - missing p tag")
    func invalidReportMissingPTag() throws {
        let event = NostrEvent(
            pubkey: reporterKeyPair.publicKey,
            createdAt: Date(),
            kind: 1984,
            tags: [],
            content: "Invalid report"
        )
        
        let report = NIP56.parseReport(from: event)
        #expect(report == nil)
    }
    
    @Test("Invalid report - wrong kind")
    func invalidReportWrongKind() throws {
        let event = NostrEvent(
            pubkey: reporterKeyPair.publicKey,
            createdAt: Date(),
            kind: 1,
            tags: [["p", reportedPubkey, "spam"]],
            content: "Not a report"
        )
        
        let report = NIP56.parseReport(from: event)
        #expect(report == nil)
    }
    
    @Test("Analyze reports")
    func analyzeReports() throws {
        let reporter1 = try KeyPair.generate()
        let reporter2 = try KeyPair.generate()
        
        let reports = [
            NostrEvent(
                pubkey: reporter1.publicKey,
                kind: 1984,
                tags: [["p", reportedPubkey, "spam"]],
                content: "Spam 1"
            ),
            NostrEvent(
                pubkey: reporter1.publicKey,
                kind: 1984,
                tags: [["p", reportedPubkey, "spam"]],
                content: "Spam 2"
            ),
            NostrEvent(
                pubkey: reporter2.publicKey,
                kind: 1984,
                tags: [["p", reportedPubkey, "illegal"]],
                content: "Illegal content"
            ),
            NostrEvent(
                pubkey: reporter2.publicKey,
                kind: 1984,
                tags: [["p", "other-user", "spam"]],
                content: "Different user"
            )
        ]
        
        let analysis = NIP56.analyzeReports(for: reportedPubkey, in: reports)
        
        #expect(analysis.totalReports == 3)
        #expect(analysis.uniqueReporters == 2)
        #expect(analysis.reportsByType[.spam] == 2)
        #expect(analysis.reportsByType[.illegal] == 1)
        #expect(analysis.mostCommonType == .spam)
        #expect(analysis.reports.count == 3)
    }
    
    @Test("Reports filter")
    func reportsFilter() throws {
        let filter = Filter.reports(
            reportedPubkeys: ["user1", "user2"],
            reporters: ["reporter1"],
            limit: 50
        )
        
        #expect(filter.kinds == [1984])
        #expect(filter.authors == ["reporter1"])
        #expect(filter.p == ["user1", "user2"])
        #expect(filter.limit == 50)
    }
    
    @Test("Event reports filter")
    func eventReportsFilter() throws {
        let filter = Filter.eventReports(
            eventIds: ["event1", "event2"],
            reporters: ["reporter1", "reporter2"],
            limit: 25
        )
        
        #expect(filter.kinds == [1984])
        #expect(filter.authors == ["reporter1", "reporter2"])
        #expect(filter.e == ["event1", "event2"])
        #expect(filter.limit == 25)
    }
    
    @Test("Report all types")
    func reportAllTypes() throws {
        for reportType in NIP56.ReportType.allCases {
            let report = try NIP56.createReport(
                reportedPubkey: reportedPubkey,
                reportType: reportType,
                content: "Testing \(reportType.rawValue)",
                reporterKeyPair: reporterKeyPair
            )
            
            #expect(report.kind == 1984)
            let pTag = report.tags.first { $0[0] == "p" }
            #expect(pTag?[2] == reportType.rawValue)
        }
    }
    
    @Test("Complex report scenario")
    func complexReportScenario() throws {
        // Create impersonation report with event
        let report = try NIP56.createReport(
            reportedPubkey: reportedPubkey,
            reportedEventId: eventId,
            reportType: .impersonation,
            content: "This user is impersonating a well-known figure",
            reporterKeyPair: reporterKeyPair
        )
        
        // Parse it back
        let parsed = NIP56.parseReport(from: report)
        #expect(parsed != nil)
        #expect(parsed?.reportType == .impersonation)
        #expect(parsed?.reportedEventId == eventId)
        
        // Analyze with other reports
        let analysis = NIP56.analyzeReports(for: reportedPubkey, in: [report])
        #expect(analysis.totalReports == 1)
        #expect(analysis.reportsByType[.impersonation] == 1)
    }
}