import Foundation

struct OpenAIRateLimitService: OpenAIRateLimitServiceProtocol {
  func fetchRateLimit(authToken: String, model: String) async throws -> RateLimitSnapshot {
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30

    let body: [String: Any] = [
      "model": model,
      "input": "ping",
      "max_output_tokens": 1,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw RateLimitError.invalidResponse
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      let responseBody = String(decoding: data, as: UTF8.self)
      throw RateLimitError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
    }

    return RateLimitSnapshot(
      requestsLimit: headerInt(httpResponse, name: "x-ratelimit-limit-requests"),
      requestsRemaining: headerInt(httpResponse, name: "x-ratelimit-remaining-requests"),
      requestsReset: headerString(httpResponse, name: "x-ratelimit-reset-requests"),
      tokensLimit: headerInt(httpResponse, name: "x-ratelimit-limit-tokens"),
      tokensRemaining: headerInt(httpResponse, name: "x-ratelimit-remaining-tokens"),
      tokensReset: headerString(httpResponse, name: "x-ratelimit-reset-tokens"),
      codexPrimaryUsedPercent: nil,
      codexPrimaryWindowMinutes: nil,
      codexPrimaryResetsAt: nil,
      codexSecondaryUsedPercent: nil,
      codexSecondaryWindowMinutes: nil,
      codexSecondaryResetsAt: nil,
      fetchedAt: Date()
    )
  }

  private func headerString(_ response: HTTPURLResponse, name: String) -> String? {
    for (key, value) in response.allHeaderFields {
      guard let headerName = key as? String, headerName.caseInsensitiveCompare(name) == .orderedSame else {
        continue
      }
      return String(describing: value)
    }
    return nil
  }

  private func headerInt(_ response: HTTPURLResponse, name: String) -> Int? {
    guard let headerValue = headerString(response, name: name) else { return nil }
    return Int(headerValue)
  }
}

enum RateLimitError: LocalizedError {
  case invalidResponse
  case httpError(statusCode: Int, body: String)

  var errorDescription: String? {
    switch self {
      case .invalidResponse:
        return "Received an invalid response from OpenAI."
      case let .httpError(statusCode, body):
        if body.isEmpty {
          return "OpenAI request failed (\(statusCode))."
        }
        let trimmed = body.count > 220 ? String(body.prefix(220)) + "..." : body
        return "OpenAI request failed (\(statusCode)): \(trimmed)"
    }
  }
}
