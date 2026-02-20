import Foundation

struct RateLimitSnapshot {
  let requestsLimit: Int?
  let requestsRemaining: Int?
  let requestsReset: String?
  let tokensLimit: Int?
  let tokensRemaining: Int?
  let tokensReset: String?
  let codexPrimaryUsedPercent: Double?
  let codexPrimaryWindowMinutes: Int?
  let codexPrimaryResetsAt: Date?
  let codexSecondaryUsedPercent: Double?
  let codexSecondaryWindowMinutes: Int?
  let codexSecondaryResetsAt: Date?
  let fetchedAt: Date
}

struct CodexSessionRateLimitSnapshot {
  let primaryUsedPercent: Double?
  let primaryWindowMinutes: Int?
  let primaryResetsAt: Date?
  let secondaryUsedPercent: Double?
  let secondaryWindowMinutes: Int?
  let secondaryResetsAt: Date?
}

struct CodexAuthSession {
  let email: String?
}
