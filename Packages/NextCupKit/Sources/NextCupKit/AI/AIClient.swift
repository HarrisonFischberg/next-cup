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
/// backoff on 429 and 5xx (max 3 attempts), and only ever returns schema-valid JSON.
public struct AIClient: Sendable {
  public static let maxAttempts = 3

  let transport: any Transport
  let key: @Sendable (AIProviderKind) -> String?
  let disclosureAccepted: @Sendable () -> Bool
  let sleep: @Sendable (Duration) async throws -> Void
  let backoff: Duration

  public init(
    transport: any Transport,
    key: @escaping @Sendable (AIProviderKind) -> String?,
    disclosureAccepted: @escaping @Sendable () -> Bool,
    backoff: Duration = .seconds(2),
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) {
    self.transport = transport
    self.key = key
    self.disclosureAccepted = disclosureAccepted
    self.backoff = backoff
    self.sleep = sleep
  }

  public func send(_ payload: AIRequestPayload, provider: AIProviderKind, model: String)
    async throws -> AIResult
  {
    guard disclosureAccepted() else { throw AIError.disclosureNotAccepted }
    guard let apiKey = key(provider), !apiKey.isEmpty else { throw AIError.noKey }
    let request = try Self.request(payload, provider: provider, model: model, key: apiKey)

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
      } catch {
        if attempt == Self.maxAttempts { throw AIError.unavailable(nil) }
        try await pause(attempt)
        continue
      }
      switch result.status {
      case 200..<300: return try Self.parse(result.body, payload: payload, provider: provider)
      case 401: throw AIError.keyRejected
      case 429, 500...599:
        if attempt == Self.maxAttempts { throw AIError.unavailable(result.status) }
        try await pause(attempt)
      default: throw AIError.http(result.status)
      }
    }
    throw AIError.unavailable(nil)
  }

  private func pause(_ attempt: Int) async throws {
    do { try await sleep(backoff * (1 << (attempt - 1))) } catch { throw AIError.cancelled }
  }

  // MARK: Requests

  static func request(
    _ payload: AIRequestPayload, provider: AIProviderKind, model: String, key: String
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
      body = [
        "model": model, "max_tokens": 1024, "system": payload.system,
        "messages": [["role": "user", "content": content]],
        "tools": [
          [
            "name": payload.schemaName, "description": "Return the answer in this shape.",
            "input_schema": payload.schema.jsonObject,
          ]
        ],
        "tool_choice": ["type": "tool", "name": payload.schemaName],
      ]
    case .openAI:
      request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
      request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      var content: [[String: Any]] = [["type": "input_text", "text": payload.userText]]
      if let image {
        content.append(["type": "input_image", "image_url": "data:image/jpeg;base64,\(image)"])
      }
      body = [
        "model": model, "instructions": payload.system,
        "input": [["role": "user", "content": content]],
        "text": [
          "format": [
            "type": "json_schema", "name": payload.schemaName, "strict": true,
            "schema": payload.schema.jsonObject,
          ]
        ],
      ]
    }
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
    return request
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
      let blocks = root["content"] as? [[String: Any]] ?? []
      answer = blocks.first { $0["type"] as? String == "tool_use" }?["input"]
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
