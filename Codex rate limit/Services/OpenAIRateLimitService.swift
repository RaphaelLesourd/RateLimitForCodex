import Foundation

struct OpenAIRateLimitService: OpenAIRateLimitServiceProtocol {
  private static let minResponseTokens = 16

  func fetchRateLimit(authToken: String, model: String) async throws -> RateLimitSnapshot {
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30

    let body: [String: Any] = [
      "model": model,
      "input": "ping",
      "max_output_tokens": Self.minResponseTokens,
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

    let requestTokensUsed = responseUsageTotalTokens(from: data)

    return RateLimitSnapshot(
      requestsLimit: headerInt(httpResponse, name: "x-ratelimit-limit-requests"),
      requestsRemaining: headerInt(httpResponse, name: "x-ratelimit-remaining-requests"),
      requestsReset: headerString(httpResponse, name: "x-ratelimit-reset-requests"),
      tokensLimit: headerInt(httpResponse, name: "x-ratelimit-limit-tokens"),
      tokensRemaining: headerInt(httpResponse, name: "x-ratelimit-remaining-tokens"),
      tokensReset: headerString(httpResponse, name: "x-ratelimit-reset-tokens"),
      requestTokensUsed: requestTokensUsed,
      sessionPrimaryUsedPercent: nil,
      sessionPrimaryWindowMinutes: nil,
      sessionPrimaryResetsAt: nil,
      sessionSecondaryUsedPercent: nil,
      sessionSecondaryWindowMinutes: nil,
      sessionSecondaryResetsAt: nil,
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

  private func responseUsageTotalTokens(from data: Data) -> Int? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let usage = root["usage"] as? [String: Any]
    else {
      return nil
    }

    if let total = intValue(for: usage["total_tokens"]) {
      return total
    }

    // Fallbacks for payload variants across model families.
    if let input = intValue(for: usage["input_tokens"]),
       let output = intValue(for: usage["output_tokens"])
    {
      return input + output
    }

    if let prompt = intValue(for: usage["prompt_tokens"]),
       let completion = intValue(for: usage["completion_tokens"])
    {
      return prompt + completion
    }
    return nil
  }

  private func intValue(for raw: Any?) -> Int? {
    if let intValue = raw as? Int {
      return intValue
    }
    if let doubleValue = raw as? Double {
      return Int(doubleValue)
    }
    if let stringValue = raw as? String {
      return Int(stringValue)
    }
    return nil
  }
}

enum RateLimitError: LocalizedError {
  case invalidResponse
  case httpError(statusCode: Int, body: String)

  var errorDescription: String? {
    switch self {
      case .invalidResponse:
        return String(localized: "service.openai.invalid_response")
      case let .httpError(statusCode, body):
        if body.isEmpty {
          return localizedFormat("service.openai.request_failed_status_format", String(statusCode))
        }
        let trimmed = body.count > 220 ? String(body.prefix(220)) + "..." : body
        return localizedFormat("service.openai.request_failed_body_format", String(statusCode), trimmed)
    }
  }

  private func localizedFormat(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
    String(format: String(localized: key), locale: Locale.current, arguments: arguments)
  }
}
