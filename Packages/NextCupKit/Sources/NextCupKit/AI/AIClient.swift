import Foundation

public enum AIProviderKind: String, Codable, CaseIterable, Sendable {
  case anthropic, openAI
}

/// What one AI call carries. The image is kept out of the coded form so a stored
/// request stays small; the queue keeps it as an attachment.
public struct AIRequestPayload: Codable, Equatable, Sendable {
  public var system: String
  public var userText: String
  public var schemaName: String
  public var schema: JSONSchema
  public var imageJPEG: Data?

  enum CodingKeys: String, CodingKey { case system, userText, schemaName, schema }

  public init(
    system: String, userText: String, schemaName: String, schema: JSONSchema, imageJPEG: Data? = nil
  ) {
    self.system = system
    self.userText = userText
    self.schemaName = schemaName
    self.schema = schema
    self.imageJPEG = imageJPEG
  }
}

/// Output that already passed the payload's schema.
public struct AIResult: Equatable, Sendable {
  public let json: Data

  public init(json: Data) { self.json = json }
}

/// One page a web search answer cites.
public struct WebSource: Equatable, Hashable, Sendable {
  public let title: String
  public let url: URL

  public init(title: String, url: URL) {
    self.title = title
    self.url = url
  }
}

/// What a provider found on the web: its summary and the pages it cites.
public struct WebResearch: Equatable, Sendable {
  public let notes: String
  public let sources: [WebSource]

  public init(notes: String, sources: [WebSource]) {
    self.notes = notes
    self.sources = sources
  }
}

public enum AIError: Error, Equatable, LocalizedError, Sendable {
  case disclosureNotAccepted
  case noKey
  case keyRejected
  case offline
  case unavailable(Int?)
  case http(Int)
  case invalidResponse
  case cancelled

  public var errorDescription: String? {
    switch self {
    case .disclosureNotAccepted: "Read and accept the AI disclosure first."
    case .noKey: "Add an API key in Settings first."
    case .keyRejected: "The provider rejected your key."
    case .offline: "No connection. The request will wait."
    case .unavailable: "The provider is busy or unreachable. Try again later."
    case .http(let status): "The provider returned an error (HTTP \(status))."
    case .invalidResponse: "The answer was not in the expected form, so it was discarded."
    case .cancelled: "Cancelled."
    }
  }
}

public struct HTTPResult: Sendable {
  public let status: Int
  public let body: Data

  public init(status: Int, body: Data) {
    self.status = status
    self.body = body
  }
}

/// The only door to the network, so tests can prove when it is (not) opened.
public protocol Transport: Sendable {
  func send(_ request: URLRequest) async throws -> HTTPResult
}

public struct URLSessionTransport: Transport {
  public init() {}

  public func send(_ request: URLRequest) async throws -> HTTPResult {
    let (data, response) = try await URLSession.shared.data(for: request)
    return HTTPResult(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
  }
}

/// One AI call: refused before any I/O without disclosure and key, retried with
/// backoff on 429 and 5xx (max 3 attempts), never after a timeout, and only ever
/// returns schema-valid JSON.
public struct AIClient: Sendable {
  public static let maxAttempts = 3

  let transport: any Transport
  let key: @Sendable (AIProviderKind) -> String?
  let disclosureAccepted: @Sendable (AIProviderKind) -> Bool
  let sleep: @Sendable (Duration) async throws -> Void
  let backoff: Duration

  public init(
    transport: any Transport,
    key: @escaping @Sendable (AIProviderKind) -> String?,
    disclosureAccepted: @escaping @Sendable (AIProviderKind) -> Bool,
    backoff: Duration = .seconds(2),
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) {
    self.transport = transport
    self.key = key
    self.disclosureAccepted = disclosureAccepted
    self.backoff = backoff
    self.sleep = sleep
  }

  /// `effort` is "low", "medium" or "high"; nil leaves the provider's default.
  public func send(
    _ payload: AIRequestPayload, provider: AIProviderKind, model: String, effort: String? = nil
  ) async throws -> AIResult {
    guard disclosureAccepted(provider) else { throw AIError.disclosureNotAccepted }
    guard let apiKey = key(provider), !apiKey.isEmpty else { throw AIError.noKey }
    let request = try Self.request(
      payload, provider: provider, model: model, key: apiKey, effort: effort)
    return try Self.parse(try await perform(request), payload: payload, provider: provider)
  }

  /// Searches the web for `question` and returns what the provider found, in its own words,
  /// with the pages its answer cites. Only `question` and `system` are sent. Anthropic uses
  /// its web search tool (billed per search on the user's key); OpenAI its web_search tool.
  public func research(
    _ question: String, system: String, provider: AIProviderKind, model: String,
    maxSearches: Int = 3
  ) async throws -> WebResearch {
    guard disclosureAccepted(provider) else { throw AIError.disclosureNotAccepted }
    guard let apiKey = key(provider), !apiKey.isEmpty else { throw AIError.noKey }
    let request = try Self.researchRequest(
      question, system: system, provider: provider, model: model, key: apiKey,
      maxSearches: maxSearches)
    return try Self.parseResearch(try await perform(request), provider: provider)
  }

  /// Sends one request with retries and returns the body of a 2xx answer.
  private func perform(_ request: URLRequest) async throws -> Data {
    for attempt in 1...Self.maxAttempts {
      let result: HTTPResult
      do {
        result = try await transport.send(request)
      } catch let error as URLError where error.code == .cancelled {
        throw AIError.cancelled
      } catch is CancellationError {
        throw AIError.cancelled
      } catch let error as URLError
        where [.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff].contains(
          error.code)
      {
        throw AIError.offline
      } catch let error as URLError where error.code == .timedOut {
        // The provider may have received, and billed, the request: never send it again.
        throw AIError.unavailable(nil)
      } catch {
        if attempt == Self.maxAttempts { throw AIError.unavailable(nil) }
        try await pause(attempt)
        continue
      }
      switch result.status {
      case 200..<300: return result.body
      case 401: throw AIError.keyRejected
      case 429, 500...599:
        if attempt == Self.maxAttempts { throw AIError.unavailable(result.status) }
        try await pause(attempt)
      default: throw AIError.http(result.status)
      }
    }
    throw AIError.unavailable(nil)
  }

  /// The models this key can use, newest first as the provider lists them. Also checks the
  /// key: a rejected one throws `keyRejected`. Sends only the key, never user data.
  public func models(_ provider: AIProviderKind) async throws -> [String] {
    guard let apiKey = key(provider), !apiKey.isEmpty else { throw AIError.noKey }
    var request: URLRequest
    switch provider {
    case .anthropic:
      request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1000")!)
      request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
      request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    case .openAI:
      request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
      request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    request.timeoutInterval = 30
    let result: HTTPResult
    do {
      result = try await transport.send(request)
    } catch let error as URLError
      where [.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff].contains(
        error.code)
    {
      throw AIError.offline
    } catch {
      throw AIError.unavailable(nil)
    }
    switch result.status {
    case 200..<300: break
    case 401, 403: throw AIError.keyRejected
    default: throw AIError.http(result.status)
    }
    guard let root = try? JSONSerialization.jsonObject(with: result.body) as? [String: Any],
      let data = root["data"] as? [[String: Any]]
    else { throw AIError.invalidResponse }
    let ids = data.compactMap { $0["id"] as? String }
    guard provider == .openAI else { return ids }
    // OpenAI lists every model it has; keep the chat ones that take a JSON schema.
    let skip = ["audio", "realtime", "tts", "transcribe", "image", "search", "embedding"]
    return ids.filter { id in
      (id.hasPrefix("gpt-") || (id.hasPrefix("o") && id.dropFirst().first?.isNumber == true))
        && !skip.contains { id.contains($0) }
    }.sorted(by: >)
  }

  private func pause(_ attempt: Int) async throws {
    do { try await sleep(backoff * (1 << (attempt - 1))) } catch { throw AIError.cancelled }
  }

  // MARK: Requests

  static func request(
    _ payload: AIRequestPayload, provider: AIProviderKind, model: String, key: String,
    effort: String? = nil
  ) throws -> URLRequest {
    var request: URLRequest
    let body: [String: Any]
    let image = payload.imageJPEG?.base64EncodedString()
    switch provider {
    case .anthropic:
      request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
      request.setValue(key, forHTTPHeaderField: "x-api-key")
      request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
      var content: [[String: Any]] = []
      if let image {
        content.append([
          "type": "image",
          "source": ["type": "base64", "media_type": "image/jpeg", "data": image],
        ])
      }
      content.append(["type": "text", "text": payload.userText])
      // Structured output, not a forced tool: current Claude models refuse forced tool_choice.
      var output: [String: Any] = [
        "format": ["type": "json_schema", "schema": payload.schema.jsonObject]
      ]
      if let effort { output["effort"] = effort }
      body = [
        "model": model, "max_tokens": 16000, "system": payload.system,
        "messages": [["role": "user", "content": content]],
        "output_config": output,
      ]
    case .openAI:
      request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
      request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      var content: [[String: Any]] = [["type": "input_text", "text": payload.userText]]
      if let image {
        content.append(["type": "input_image", "image_url": "data:image/jpeg;base64,\(image)"])
      }
      var openAIBody: [String: Any] = [
        "model": model, "instructions": payload.system,
        "input": [["role": "user", "content": content]],
        "text": [
          "format": [
            "type": "json_schema", "name": payload.schemaName, "strict": true,
            "schema": payload.schema.jsonObject,
          ]
        ],
      ]
      if let effort { openAIBody["reasoning"] = ["effort": effort] }
      body = openAIBody
    }
    request.httpMethod = "POST"
    request.timeoutInterval = 120
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
    return request
  }

  static func researchRequest(
    _ question: String, system: String, provider: AIProviderKind, model: String, key: String,
    maxSearches: Int
  ) throws -> URLRequest {
    var request: URLRequest
    let body: [String: Any]
    switch provider {
    case .anthropic:
      request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
      request.setValue(key, forHTTPHeaderField: "x-api-key")
      request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
      // The basic tool works on every model a key may pick; no structured output here,
      // because web search answers always carry citations.
      body = [
        "model": model, "max_tokens": 8000, "system": system,
        "messages": [["role": "user", "content": question]],
        "tools": [["type": "web_search_20250305", "name": "web_search", "max_uses": maxSearches]],
      ]
    case .openAI:
      request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
      request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      body = [
        "model": model, "instructions": system, "input": question,
        "tools": [["type": "web_search"]], "max_tool_calls": maxSearches,
      ]
    }
    request.httpMethod = "POST"
    request.timeoutInterval = 120
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
    return request
  }

  /// The answer's text and the pages it cites, in order, without repeats. Sources come
  /// only from the provider's citations, never from the model's own text, so every one is
  /// a page the search returned.
  static func parseResearch(_ data: Data, provider: AIProviderKind) throws -> WebResearch {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw AIError.invalidResponse
    }
    let blocks: [[String: Any]]
    let citationKey: String
    switch provider {
    case .anthropic:
      blocks = (root["content"] as? [[String: Any]] ?? []).filter {
        $0["type"] as? String == "text"
      }
      citationKey = "citations"
    case .openAI:
      blocks = (root["output"] as? [[String: Any]] ?? [])
        .filter { $0["type"] as? String == "message" }
        .flatMap { $0["content"] as? [[String: Any]] ?? [] }
        .filter { $0["type"] as? String == "output_text" }
      citationKey = "annotations"
    }
    var sources: [WebSource] = []
    for citation in blocks.flatMap({ $0[citationKey] as? [[String: Any]] ?? [] }) {
      guard let raw = citation["url"] as? String, let url = URL(string: raw),
        url.scheme == "https", !sources.contains(where: { $0.url == url })
      else { continue }
      let title = (citation["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
      sources.append(WebSource(title: title.isEmpty ? url.host() ?? raw : title, url: url))
    }
    let text = blocks.compactMap { $0["text"] as? String }.joined()
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw AIError.invalidResponse }
    return WebResearch(notes: text, sources: sources)
  }

  // MARK: Responses

  static func parse(_ data: Data, payload: AIRequestPayload, provider: AIProviderKind) throws
    -> AIResult
  {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw AIError.invalidResponse
    }
    let answer: Any?
    switch provider {
    case .anthropic:
      let text =
        (root["content"] as? [[String: Any]] ?? [])
        .first { $0["type"] as? String == "text" }?["text"] as? String
      answer = text.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
    case .openAI:
      let text =
        (root["output"] as? [[String: Any]] ?? [])
        .filter { $0["type"] as? String == "message" }
        .flatMap { $0["content"] as? [[String: Any]] ?? [] }
        .first { $0["type"] as? String == "output_text" }?["text"] as? String
      answer = text.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
    }
    guard let answer, payload.schema.validates(answer),
      let json = try? JSONSerialization.data(withJSONObject: answer, options: .sortedKeys)
    else { throw AIError.invalidResponse }
    return AIResult(json: json)
  }
}
