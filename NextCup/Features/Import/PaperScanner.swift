import Foundation
import NextCupKit
import UIKit
import Vision

/// Reads the text on a photographed journal page with Vision, on the device
/// (blueprint §1). No key and no network are involved.
enum PaperScanner {
  /// The page's lines from top to bottom, each with Vision's own confidence.
  /// `photo` must already be sanitized.
  static func lines(in photo: Data) async throws -> [PaperLine] {
    var request = RecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let observations = try await request.perform(on: photo)
    return
      observations
      .sorted { $0.boundingBox.cgRect.midY > $1.boundingBox.cgRect.midY }
      .compactMap { observation in
        observation.topCandidates(1).first.map {
          PaperLine(text: $0.string, confidence: Double($0.confidence))
        }
      }
  }
}

#if DEBUG
  /// A synthetic journal page for tests and UI tests: black type on white, no
  /// real person's handwriting or data.
  enum PaperSample {
    static let lines = [
      "Method: V60", "Beans: Sample Blend", "Dose: 18 g", "Water: 288 g", "Temp: 94 C",
      "Time: 2:45", "Grind: 24", "Rating: 4/5", "Notes: sweet, bright",
    ]

    static func page(_ lines: [String] = PaperSample.lines) -> Data {
      let size = CGSize(width: 1000, height: CGFloat(160 + lines.count * 110))
      let image = UIGraphicsImageRenderer(size: size).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let attributes: [NSAttributedString.Key: Any] = [
          .font: UIFont.systemFont(ofSize: 56, weight: .medium), .foregroundColor: UIColor.black,
        ]
        for (index, line) in lines.enumerated() {
          (line as NSString).draw(
            at: CGPoint(x: 60, y: 60 + CGFloat(index) * 110), withAttributes: attributes)
        }
      }
      return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
  }
#endif
