import Foundation

/// A scanned retail barcode looked up in Open Food Facts (T037). Pure: the app
/// supplies the transport, so parsing and every failure path are testable.
public enum BarcodeLookup {
  /// Open Food Facts asks every client to name itself and give a contact.
  public static let userAgent = "NextCup/1.0 (iOS; hello@rarecreatures.app)"

  /// EAN-8, UPC-A/E, EAN-13 and GTIN-14 are 8 to 14 digits. Anything else is
  /// refused before a request is built, so a scan can never shape the URL.
  public static func normalized(_ code: String) -> String? {
    let digits = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (8...14).contains(digits.count), digits.allSatisfy(\.isASCII),
      digits.allSatisfy(\.isNumber)
    else { return nil }
    return digits
  }

  public static func request(for code: String) -> URLRequest? {
    guard let code = normalized(code),
      let url = URL(
        string:
          "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,brands")
    else { return nil }
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    return request
  }

  public struct Product: Equatable, Sendable {
    /// Empty when the record has only a brand: a brand is not the coffee's name.
    public var name: String
    /// The first listed brand, usually the roaster.
    public var brand: String?

    public init(name: String, brand: String?) {
      self.name = name
      self.brand = brand
    }
  }

  public enum Failure: Error, Equatable, Sendable {
    case invalidCode, notFound, offline, unreadable
  }

  /// Reads a v2 product response. A 404, `status: 0` or a product with neither
  /// a name nor a brand is "not found".
  public static func parse(_ data: Data, statusCode: Int) -> Result<Product, Failure> {
    if statusCode == 404 { return .failure(.notFound) }
    guard (200..<300).contains(statusCode) else { return .failure(.unreadable) }
    struct Body: Decodable {
      struct P: Decodable {
        var productName: String?
        var brands: String?
        enum CodingKeys: String, CodingKey {
          case productName = "product_name"
          case brands
        }
      }
      var status: Int?
      var product: P?
    }
    guard let body = try? JSONDecoder().decode(Body.self, from: data) else {
      return .failure(.unreadable)
    }
    let clean = { (s: String?) -> String? in
      let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return t.isEmpty ? nil : t
    }
    let brand = clean(body.product?.brands?.split(separator: ",").first.map(String.init))
    guard body.status != 0, let product = body.product,
      clean(product.productName) != nil || brand != nil
    else { return .failure(.notFound) }
    return .success(Product(name: clean(product.productName) ?? "", brand: brand))
  }

  /// Validates the code, fetches through `fetch`, and parses. A transport error is "offline".
  public static func lookUp(
    _ code: String,
    fetch: @Sendable (URLRequest) async throws -> (Data, Int)
  ) async -> Result<Product, Failure> {
    guard let request = request(for: code) else { return .failure(.invalidCode) }
    do {
      let (data, status) = try await fetch(request)
      return parse(data, statusCode: status)
    } catch {
      return .failure(.offline)
    }
  }
}
