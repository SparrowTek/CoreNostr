//
//  NIP50Tests.swift
//  CoreNostrTests
//
//  Tests for NIP-50: Search Capability Specification
//

import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-50: Search Capability")
struct NIP50Tests {
    
    @Test("Basic search filter creation")
    func basicSearchFilter() throws {
        let filter = Filter.search(query: "bitcoin conference")
        
        #expect(filter.search == "bitcoin conference")
        #expect(filter.limit == 100)
        #expect(filter.authors == nil)
        #expect(filter.kinds == nil)
    }
    
    @Test("Search text notes")
    func searchTextNotes() throws {
        let filter = Filter.searchTextNotes(
            query: "nostr protocol",
            authors: ["pubkey1", "pubkey2"],
            limit: 50
        )
        
        #expect(filter.search == "nostr protocol")
        #expect(filter.kinds == [EventKind.textNote.rawValue])
        #expect(filter.authors == ["pubkey1", "pubkey2"])
        #expect(filter.limit == 50)
    }
    
    @Test("Search articles")
    func searchArticles() throws {
        let filter = Filter.searchArticles(
            query: "lightning network guide",
            limit: 20
        )
        
        #expect(filter.search == "lightning network guide")
        #expect(filter.kinds == [EventKind.longFormContent.rawValue])
        #expect(filter.limit == 20)
    }
    
    @Test("Complex search query builder")
    func complexSearchQuery() throws {
        var query = Filter.SearchQuery()
        query.add(term: "bitcoin")
        query.add(term: "lightning")
        query.language("en")
        query.sentiment(.positive)
        query.nsfw(false)
        
        let built = query.build()
        #expect(built == "bitcoin lightning language:en sentiment:positive nsfw:false")
    }
    
    @Test("Search query with spam inclusion")
    func searchWithSpam() throws {
        var query = Filter.SearchQuery()
        query.add(term: "nostr apps")
        query.includeSpam()
        query.domain("nostr.com")
        
        let built = query.build()
        #expect(built == "nostr apps include:spam domain:nostr.com")
    }
    
    @Test("Parse search query extensions")
    func parseSearchExtensions() throws {
        let query = "bitcoin conference include:spam language:en sentiment:positive nsfw:true"
        let (baseQuery, extensions) = NIP50.parseSearchQuery(query)
        
        #expect(baseQuery == "bitcoin conference")
        #expect(extensions.includeSpam == true)
        #expect(extensions.language == "en")
        #expect(extensions.sentiment == .positive)
        #expect(extensions.nsfw == true)
    }
    
    @Test("Parse query without extensions")
    func parseSimpleQuery() throws {
        let query = "just a simple search"
        let (baseQuery, extensions) = NIP50.parseSearchQuery(query)
        
        #expect(baseQuery == "just a simple search")
        #expect(extensions.includeSpam == false)
        #expect(extensions.domain == nil)
        #expect(extensions.language == nil)
        #expect(extensions.sentiment == nil)
        #expect(extensions.nsfw == nil)
    }
    
    @Test("NIP-50 search filter with dates")
    func searchFilterWithDates() throws {
        let since = Date(timeIntervalSince1970: 1700000000)
        let until = Date(timeIntervalSince1970: 1700086400)
        
        let filter = NIP50.searchFilter(
            query: "nostr development",
            kinds: [1, 30023],
            since: since,
            until: until,
            limit: 200
        )
        
        #expect(filter.search == "nostr development")
        #expect(filter.kinds == [1, 30023])
        #expect(filter.since == 1700000000)
        #expect(filter.until == 1700086400)
        #expect(filter.limit == 200)
    }
    
    @Test("Filter JSON encoding with search")
    func filterJSONWithSearch() throws {
        let filter = Filter(
            authors: ["author1"],
            kinds: [1],
            limit: 10,
            search: "test query"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(filter)
        let json = String(data: data, encoding: .utf8)!
        
        #expect(json.contains("\"search\":\"test query\""))
        #expect(json.contains("\"authors\":[\"author1\"]"))
        #expect(json.contains("\"kinds\":[1]"))
        #expect(json.contains("\"limit\":10"))
    }
    
    @Test("Create search request message")
    func createSearchRequest() throws {
        let request = CoreNostr.createSearchRequest(
            subscriptionId: "sub123",
            query: "bitcoin lightning",
            kinds: [1],
            authors: ["pubkey1"],
            limit: 50
        )
        
        #expect(request.contains("REQ"))
        #expect(request.contains("sub123"))
        #expect(request.contains("\"search\":\"bitcoin lightning\""))
        #expect(request.contains("\"kinds\":[1]"))
        #expect(request.contains("\"authors\":[\"pubkey1\"]"))
        #expect(request.contains("\"limit\":50"))
    }
    
    @Test("Empty search query")
    func emptySearchQuery() throws {
        let filter = Filter.search(query: "")
        #expect(filter.search == "")
        #expect(filter.limit == 100)
    }
    
    @Test("Search query sentiment enum")
    func sentimentEnum() throws {
        #expect(Filter.SearchQuery.Sentiment.negative.rawValue == "negative")
        #expect(Filter.SearchQuery.Sentiment.neutral.rawValue == "neutral")
        #expect(Filter.SearchQuery.Sentiment.positive.rawValue == "positive")
    }
}