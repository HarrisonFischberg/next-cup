import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

/// Live check of brew advice on real bag photos with Apple's on-device model: each photo goes
/// through the production bag reading (PhotoSanitizer → BagRecognition → AppleIntelligence),
/// the bean is saved, then BeanBrewAI is asked with no goal and with a taste goal. Skipped
/// unless `TEST_RUNNER_BREW_EVAL_DIR` names a folder of photos; results are written to
/// `results.json` there. Photos are never sent anywhere: the model runs on this machine.
@MainActor
@Suite(
  "Brew advice eval (live)", .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["BREW_EVAL_DIR"] != nil))
struct BeanBrewEvalTests {
  private static var containers: [ModelContainer] = []

  @Test func everyBagGetsThreeBrews() async throws {
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BREW_EVAL_DIR"]!)
    let photos = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil
    )
    .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    let store = Store(context: container.mainContext)
    let suite = "BeanBrewEval.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    _ = BuiltInSeeder(store: store, defaults: defaults).seed(try BuiltInContent(bundle: .main))
    let send: (AIRequestPayload) async throws -> (answer: [String: Any], source: String) = {
      let result = try await AppleIntelligence.send($0)
      let answer = try #require(
        try JSONSerialization.jsonObject(with: result.json) as? [String: Any])
      return (answer, "On this iPhone")
    }
    var results: [[String: Any]] = []
    for photo in photos {
      var row: [String: Any] = ["photo": photo.lastPathComponent]
      do {
        let image = try #require(PhotoSanitizer.sanitized(try Data(contentsOf: photo)))
        let read = try await AppleIntelligence.send(
          BagRecognition.payload(photo: image, feature: .bagRecognition))
        let raw = (try? JSONSerialization.jsonObject(with: read.json)) as? [String: Any]
        row["raw"] = "\(raw?["name"] ?? "") | \(raw?["roaster"] ?? "")"
        let request = AIRequest()
        request.feature = .bagRecognition
        request.status = .done
        request.resultJSON = read.json
        container.mainContext.insert(request)
        var fields = try BagRecognition.draft(from: request).get()
        if fields.name.trimmingCharacters(in: .whitespaces).isEmpty { fields.name = "Unnamed bag" }
        let bean = try BeanService(store: store).save(fields).get()
        row["bean"] =
          "\(bean.name) | \(bean.roaster?.name ?? "-") | \(bean.roastLevel?.rawValue ?? "-")"
        let goals =
          ProcessInfo.processInfo.environment["BREW_EVAL_SCAN_ONLY"] == nil
          ? ["", "chocolatey and full-bodied"] : []
        for goal in goals {
          let key = goal.isEmpty ? "recommend3" : "chocolatey"
          do {
            let outcome = try await BeanBrewAI.ask(
              bean: bean, goal: goal, store: store, grinder: nil, send: send)
            row[key] = outcome.picks.map { pick -> String in
              let d = pick.draft
              return "\(pick.methodName): \(d.name), \(SuggestionApplication.number(d.doseG)) g / "
                + "\(SuggestionApplication.number(d.waterG)) g, \(d.tempC.map { "\(Int($0)) C" } ?? "-"), "
                + "\(d.totalTimeS.map { "\($0) s" } ?? "-"), \(d.steps.count) steps"
            }
            #expect(
              outcome.picks.count == BeanBrewAI.pickCount, "\(photo.lastPathComponent) \(key)")
          } catch {
            row[key] = "FAILED: \(error)"
            Issue.record("\(photo.lastPathComponent) \(key): \(error)")
          }
        }
      } catch {
        row["error"] = "\(error) \(AppleIntelligence.lastFailure ?? "")"
        Issue.record("\(photo.lastPathComponent) scan: \(error)")
      }
      results.append(row)
      print("EVAL", row)
    }
    let data = try JSONSerialization.data(
      withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: folder.appending(path: "results.json"))
  }
}
