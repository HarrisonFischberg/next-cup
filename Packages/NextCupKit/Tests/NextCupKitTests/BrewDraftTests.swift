import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import NextCupKit

private func succeeded<F: Error>(_ result: Result<Void, F>) -> Bool {
  if case .success = result { return true }
  return false
}

@Suite struct DraftStoreTests {
  private func makeURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("nextcup-draft-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("brew-draft.json")
  }

  @Test func listsEveryDraftWithWhatItBelongsTo() throws {
    let folder = makeURL().deletingLastPathComponent()
    let edited = UUID()
    let repeated = UUID()
    _ = DraftStore(fileURL: folder.appendingPathComponent("brew-draft.json"))
      .save(BrewDraft(notes: "new"))
    _ = DraftStore(fileURL: folder.appendingPathComponent("brew-edit-\(edited.uuidString).json"))
      .save(BrewDraft(id: edited, notes: "edit"))
    _ = DraftStore(fileURL: folder.appendingPathComponent("brew-again-\(repeated.uuidString).json"))
      .save(BrewDraft(notes: "again"))
    try Data("not a draft".utf8).write(to: folder.appendingPathComponent("notes.txt"))

    let found = DraftStore.all(in: folder)
    #expect(found.count == 3)
    #expect(found.first { $0.kind == .newBrew }?.draft.notes == "new")
    #expect(found.first { $0.kind == .editing(edited) }?.draft.notes == "edit")
    #expect(found.first { $0.kind == .repeating(repeated) }?.draft.notes == "again")
  }

  @Test func loadsNothingBeforeAnythingIsSaved() {
    #expect(DraftStore(fileURL: makeURL()).load() == .none)
  }

  @Test func roundTripsEveryField() {
    let store = DraftStore(fileURL: makeURL())
    let draft = BrewDraft(
      sourceKey: "run-1", methodID: UUID(), recipeID: UUID(), doseG: 15.5, waterG: 250,
      tempC: 94, totalTimeS: 187, grindSetting: "21 clicks", verdict: "sour", ratingTenths: 7,
      notes: "Bright, a little thin.", photo: Data([1, 2, 3]),
      targets: BrewTargets(doseG: 15, waterG: 250, tempC: 96, totalTimeS: 180), endedEarly: true)
    #expect(succeeded(store.save(draft)))
    #expect(store.load() == .draft(draft))
  }

  @Test func draftFromBeforeTenthsOpensConverted() throws {
    let url = makeURL()
    let store = DraftStore(fileURL: url)
    _ = store.save(BrewDraft(doseG: 15, ratingTenths: 7, notes: "kept"))
    var object = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    object["ratingHalfSteps"] = object.removeValue(forKey: "ratingTenths")
    try JSONSerialization.data(withJSONObject: object).write(to: url)

    guard case .draft(let draft) = store.load() else {
      Issue.record("old draft was discarded")
      return
    }
    #expect(draft.ratingTenths == 70)
    #expect(draft.notes == "kept")
  }

  @Test func laterSaveReplacesEarlier() {
    let store = DraftStore(fileURL: makeURL())
    var draft = BrewDraft(doseG: 15)
    _ = store.save(draft)
    draft.notes = "typed after"
    _ = store.save(draft)
    #expect(store.load() == .draft(draft))
  }

  @Test func corruptFileIsDiscardedNotFatal() throws {
    let url = makeURL()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{ not json".utf8).write(to: url)
    let store = DraftStore(fileURL: url)
    #expect(store.load() == .discardedCorrupt)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    #expect(store.load() == .none)
  }

  @Test func failedWriteIsReportedAndKeepsThePreviousDraft() {
    let url = makeURL()
    let good = DraftStore(fileURL: url)
    let first = BrewDraft(doseG: 15)
    _ = good.save(first)

    struct Boom: Error {}
    let failing = DraftStore(fileURL: url) { _, _ in throw Boom() }
    let result = failing.save(BrewDraft(doseG: 99))
    guard case .failure(.writeFailed) = result else {
      Issue.record("expected a write failure, got \(result)")
      return
    }
    #expect(good.load() == .draft(first))
  }

  @Test func clearRemovesTheDraftAndIsIdempotent() {
    let store = DraftStore(fileURL: makeURL())
    _ = store.save(BrewDraft(doseG: 15))
    #expect(succeeded(store.clear()))
    #expect(store.load() == .none)
    #expect(succeeded(store.clear()))
  }

  @Test func canSaveNeedsPositiveDoseAndWater() {
    #expect(!BrewDraft().canSave)
    #expect(!BrewDraft(doseG: 15).canSave)
    #expect(!BrewDraft(doseG: 0, waterG: 250).canSave)
    #expect(BrewDraft(doseG: 15, waterG: 250).canSave)
  }
}

@Suite struct PhotoSanitizerTests {
  /// A small JPEG carrying GPS, EXIF and TIFF metadata, like a phone photo.
  private func photoWithMetadata(width: Int = 400, height: Int = 200) throws -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = try #require(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.7, green: 0.4, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())

    let output = NSMutableData()
    let destination = try #require(
      CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
    let properties: [CFString: Any] = [
      kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 37.33, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 122.03, kCGImagePropertyGPSLongitudeRef: "W",
      ],
      kCGImagePropertyExifDictionary: [
        kCGImagePropertyExifUserComment: "kitchen",
        kCGImagePropertyExifLensModel: "Synthetic lens",
      ],
      kCGImagePropertyTIFFDictionary: [
        kCGImagePropertyTIFFMake: "Synthetic", kCGImagePropertyTIFFModel: "Phone 1",
      ],
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
  }

  private func properties(of data: Data) throws -> [CFString: Any] {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }

  @Test func fixtureReallyCarriesLocation() throws {
    let original = try properties(of: photoWithMetadata())
    #expect(original[kCGImagePropertyGPSDictionary] != nil)
    #expect(original[kCGImagePropertyExifDictionary] != nil)
  }

  @Test func sanitizedPhotoHasNoGPSExifOrTIFFMetadata() throws {
    let cleaned = try #require(PhotoSanitizer.sanitized(photoWithMetadata()))
    let result = try properties(of: cleaned)
    #expect(result[kCGImagePropertyGPSDictionary] == nil)
    let exif = result[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    #expect(exif[kCGImagePropertyExifUserComment] == nil)
    #expect(exif[kCGImagePropertyExifLensModel] == nil)
    let tiff = result[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
    #expect(tiff[kCGImagePropertyTIFFMake] == nil)
    #expect(tiff[kCGImagePropertyTIFFModel] == nil)
    #expect(!String(decoding: cleaned, as: UTF8.self).contains("Synthetic"))
  }

  @Test func sanitizedPhotoIsStillAnImageAndIsScaledDown() throws {
    let cleaned = try #require(
      PhotoSanitizer.sanitized(photoWithMetadata(width: 400, height: 200), maxPixelSize: 100))
    let result = try properties(of: cleaned)
    #expect(result[kCGImagePropertyPixelWidth] as? Int == 100)
    #expect(result[kCGImagePropertyPixelHeight] as? Int == 50)
  }

  @Test func notAnImageGivesNil() {
    #expect(PhotoSanitizer.sanitized(Data("hello".utf8)) == nil)
  }
}
