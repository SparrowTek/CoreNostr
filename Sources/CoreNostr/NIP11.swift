import Foundation

/// NIP-11: Relay Information Document
/// https://github.com/nostr-protocol/nips/blob/master/11.md
/// 
/// Data models for relay metadata. The actual fetching is done by platform-specific code.

/// Relay information document structure
public struct RelayInformation: Codable, Sendable {
    /// Relay name
    public let name: String?
    
    /// Relay description  
    public let description: String?
    
    /// Administrative contact pubkey
    public let pubkey: String?
    
    /// Administrative contact URI
    public let contact: String?
    
    /// List of NIP numbers supported by the relay
    public let supportedNips: [Int]?
    
    /// Relay software name
    public let software: String?
    
    /// Relay software version
    public let version: String?
    
    /// Relay limitations
    public let limitation: RelayLimitation?
    
    /// Event retention policies
    public let retentionPolicy: [RetentionPolicy]?
    
    /// Countries where the relay is operating
    public let relayCountries: [String]?
    
    /// Language tags preferred by the relay
    public let languageTags: [String]?
    
    /// Arbitrary tags for the relay
    public let tags: [String]?
    
    /// Posting policy URL
    public let postingPolicy: String?
    
    /// URL for relay payments
    public let paymentsUrl: String?
    
    /// Fee structure
    public let fees: RelayFees?
    
    /// Icon URL
    public let icon: String?
    
    private enum CodingKeys: String, CodingKey {
        case name, description, pubkey, contact
        case supportedNips = "supported_nips"
        case software, version, limitation
        case retentionPolicy = "retention"
        case relayCountries = "relay_countries"
        case languageTags = "language_tags"
        case tags
        case postingPolicy = "posting_policy"
        case paymentsUrl = "payments_url"
        case fees, icon
    }
    
    public init(
        name: String? = nil,
        description: String? = nil,
        pubkey: String? = nil,
        contact: String? = nil,
        supportedNips: [Int]? = nil,
        software: String? = nil,
        version: String? = nil,
        limitation: RelayLimitation? = nil,
        retentionPolicy: [RetentionPolicy]? = nil,
        relayCountries: [String]? = nil,
        languageTags: [String]? = nil,
        tags: [String]? = nil,
        postingPolicy: String? = nil,
        paymentsUrl: String? = nil,
        fees: RelayFees? = nil,
        icon: String? = nil
    ) {
        self.name = name
        self.description = description
        self.pubkey = pubkey
        self.contact = contact
        self.supportedNips = supportedNips
        self.software = software
        self.version = version
        self.limitation = limitation
        self.retentionPolicy = retentionPolicy
        self.relayCountries = relayCountries
        self.languageTags = languageTags
        self.tags = tags
        self.postingPolicy = postingPolicy
        self.paymentsUrl = paymentsUrl
        self.fees = fees
        self.icon = icon
    }
}

/// Relay limitations structure
public struct RelayLimitation: Codable, Sendable {
    /// Maximum message length accepted
    public let maxMessageLength: Int?
    
    /// Maximum number of subscriptions per connection
    public let maxSubscriptions: Int?
    
    /// Maximum number of filters per subscription
    public let maxFilters: Int?
    
    /// Maximum limit value for queries
    public let maxLimit: Int?
    
    /// Maximum subscription ID length
    public let maxSubidLength: Int?
    
    /// Maximum number of tags in an event
    public let maxEventTags: Int?
    
    /// Maximum content length
    public let maxContentLength: Int?
    
    /// Minimum proof-of-work difficulty required
    public let minPowDifficulty: Int?
    
    /// Whether authentication is required
    public let authRequired: Bool?
    
    /// Whether payment is required
    public let paymentRequired: Bool?
    
    /// Whether the relay restricts writing
    public let restrictedWrites: Bool?
    
    /// Minimum timestamp for events
    public let createdAtLowerLimit: Int?
    
    /// Maximum timestamp for events
    public let createdAtUpperLimit: Int?
    
    private enum CodingKeys: String, CodingKey {
        case maxMessageLength = "max_message_length"
        case maxSubscriptions = "max_subscriptions"
        case maxFilters = "max_filters"
        case maxLimit = "max_limit"
        case maxSubidLength = "max_subid_length"
        case maxEventTags = "max_event_tags"
        case maxContentLength = "max_content_length"
        case minPowDifficulty = "min_pow_difficulty"
        case authRequired = "auth_required"
        case paymentRequired = "payment_required"
        case restrictedWrites = "restricted_writes"
        case createdAtLowerLimit = "created_at_lower_limit"
        case createdAtUpperLimit = "created_at_upper_limit"
    }
    
    public init(
        maxMessageLength: Int? = nil,
        maxSubscriptions: Int? = nil,
        maxFilters: Int? = nil,
        maxLimit: Int? = nil,
        maxSubidLength: Int? = nil,
        maxEventTags: Int? = nil,
        maxContentLength: Int? = nil,
        minPowDifficulty: Int? = nil,
        authRequired: Bool? = nil,
        paymentRequired: Bool? = nil,
        restrictedWrites: Bool? = nil,
        createdAtLowerLimit: Int? = nil,
        createdAtUpperLimit: Int? = nil
    ) {
        self.maxMessageLength = maxMessageLength
        self.maxSubscriptions = maxSubscriptions
        self.maxFilters = maxFilters
        self.maxLimit = maxLimit
        self.maxSubidLength = maxSubidLength
        self.maxEventTags = maxEventTags
        self.maxContentLength = maxContentLength
        self.minPowDifficulty = minPowDifficulty
        self.authRequired = authRequired
        self.paymentRequired = paymentRequired
        self.restrictedWrites = restrictedWrites
        self.createdAtLowerLimit = createdAtLowerLimit
        self.createdAtUpperLimit = createdAtUpperLimit
    }
}

/// Retention policy for events
public struct RetentionPolicy: Codable, Sendable {
    /// Time period in seconds
    public let time: Int?
    
    /// Number of events to retain
    public let count: Int?
    
    /// Event kinds this policy applies to
    public let kinds: [Int]?
    
    public init(time: Int? = nil, count: Int? = nil, kinds: [Int]? = nil) {
        self.time = time
        self.count = count
        self.kinds = kinds
    }
}

/// Fee structure for relay services
public struct RelayFees: Codable, Sendable {
    /// Admission fees
    public let admission: [RelayFee]?
    
    /// Subscription fees
    public let subscription: [RelayFee]?
    
    /// Publication fees
    public let publication: [RelayFee]?
    
    public init(
        admission: [RelayFee]? = nil,
        subscription: [RelayFee]? = nil,
        publication: [RelayFee]? = nil
    ) {
        self.admission = admission
        self.subscription = subscription
        self.publication = publication
    }
}

/// Individual fee structure
public struct RelayFee: Codable, Sendable {
    /// Fee amount
    public let amount: Int
    
    /// Currency unit (e.g., "msats")
    public let unit: String
    
    /// Time period in seconds
    public let period: Int?
    
    /// Event kinds this fee applies to
    public let kinds: [Int]?
    
    public init(amount: Int, unit: String, period: Int? = nil, kinds: [Int]? = nil) {
        self.amount = amount
        self.unit = unit
        self.period = period
        self.kinds = kinds
    }
}

/// Helper extensions for working with relay information
public extension RelayInformation {
    /// Check if the relay supports a specific NIP
    func supports(nip: Int) -> Bool {
        supportedNips?.contains(nip) ?? false
    }
    
    /// Check if the relay has any limitations
    var hasLimitations: Bool {
        limitation != nil
    }
    
    /// Check if the relay requires authentication
    var requiresAuth: Bool {
        limitation?.authRequired ?? false
    }
    
    /// Check if the relay requires payment
    var requiresPayment: Bool {
        limitation?.paymentRequired ?? false || fees != nil
    }
    
    /// Get the minimum PoW difficulty if any
    var minimumPoWDifficulty: Int? {
        limitation?.minPowDifficulty
    }
}

/// NIP support checking
public extension RelayInformation {
    /// Common NIPs that might be supported
    enum CommonNIP: Int {
        case basicProtocol = 1
        case followLists = 2
        case openTimestamps = 3
        case encryptedDM = 4  // Deprecated
        case dns = 5
        case mnemonics = 6
        case webAuth = 7
        case mentionHandling = 8
        case eventDeletion = 9
        case replyThreading = 10
        case relayInfo = 11
        case genericTags = 12
        case proofOfWork = 13
        // Add more as needed
    }
    
    /// Check support for common NIPs
    func supports(_ commonNip: CommonNIP) -> Bool {
        supports(nip: commonNip.rawValue)
    }
}