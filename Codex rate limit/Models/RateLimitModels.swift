import Foundation

struct RateLimitSnapshot {
  let requestsLimit: Int?
  let requestsRemaining: Int?
  let requestsReset: String?
  let tokensLimit: Int?
  let tokensRemaining: Int?
  let tokensReset: String?
  let requestTokensUsed: Int?
  let sessionPrimaryUsedPercent: Double?
  let sessionPrimaryWindowMinutes: Int?
  let sessionPrimaryResetsAt: Date?
  let sessionSecondaryUsedPercent: Double?
  let sessionSecondaryWindowMinutes: Int?
  let sessionSecondaryResetsAt: Date?
  let fetchedAt: Date
}

struct SessionRateLimitSnapshot {
  let primaryUsedPercent: Double?
  let primaryWindowMinutes: Int?
  let primaryResetsAt: Date?
  let secondaryUsedPercent: Double?
  let secondaryWindowMinutes: Int?
  let secondaryResetsAt: Date?
}
