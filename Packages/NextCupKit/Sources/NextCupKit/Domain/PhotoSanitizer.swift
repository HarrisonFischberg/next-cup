import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Re-encodes a photo as JPEG with no metadata, so location and camera details
/// never reach the store or an AI request (blueprint §2, §7). The pixels are
/// decoded with the orientation applied and written to a destination that is
/// given no properties, so EXIF, GPS, TIFF and maker notes are not carried over.
public enum PhotoSanitizer {
  /// Longest edge of the stored photo, in pixels.
  public static let maxPixelSize = 1568

  /// Returns `nil` when `data` is not a decodable image.
  public static func sanitized(
    _ data: Data, maxPixelSize: Int = PhotoSanitizer.maxPixelSize, quality: Double = 0.8
  ) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }

    let output = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        output, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return output as Data
  }
}
