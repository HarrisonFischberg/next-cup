import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Next Cup on save")
struct NextCupAutoTests {
  @MainActor private final class Harness {
    let container: ModelContainer
    let store: Store
    let method: BrewMethod
    let defaults: UserDefaults
    var asked = 0

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      store = Store(context: container.mainContext)
      method = BrewMethod(name: "Test Dripper")
      container.mainContext.insert(method)
      defaults = try #require(UserDefaults(suiteName: "auto.\(UUID().uuidString)"))
    }

    func brew(
      _ verdict: Verdict? = .sour, dose: Double = 18, water: Double = 300,
      daysAgo: Int = 0, method: BrewMethod? = nil
    ) -> Brew {
      let brew = Brew()
      brew.method = method ?? self.method
      brew.verdict = verdict
      brew.doseG = dose
      brew.waterG = water
      brew.date = Date().addingTimeInterval(Double(-daysAgo) * 86400)
      container.mainContext.insert(brew)
      return brew
    }

    func auto(
      notice: AIProvider? = nil, available: Bool = true, failure: Error? = nil
    ) -> NextCupAuto {
      NextCupAuto(
        defaults: defaults, notice: { notice }, available: { available },
        ask: { [self] brew, store in
          asked += 1
          if let failure { throw failure }
          return try await NextCupAI.ask(
            about: brew, store: store, sameCategoryOnly: true, onDevice: false,
            research: { _ in nil },
            send: { _ in (NextCupAI.fakeAnswer(for: NextCupAI.base(for: brew, store: store)), "T") }
          )
        })
    }

    var nextCups: [Recipe] {
      ((try? container.mainContext.fetch(FetchDescriptor<Recipe>())) ?? []).filter(\.isNextCup)
    }
    var pending: String? { defaults.string(forKey: NextCupAuto.pendingKey) }
  }

  @Test func savingAReviewedBrewPutsItsNextCupOnTheBrewTab() async throws {
    let harness = try Harness()
    let auto = harness.auto()
    let brew = harness.brew()
    auto.brewReviewed(brew.id, store: harness.store)
    #expect(auto.status == .working)
    await auto.job?.value
    #expect(auto.status == .idle)
    #expect(harness.nextCups.count == 1)
    #expect(harness.pending == nil)
    // The next save replaces it rather than adding another.
    let next = harness.brew(.bitter)
    auto.brewReviewed(next.id, store: harness.store)
    await auto.job?.value
    #expect(harness.nextCups.count == 1)
  }

  @Test func theSwitchOffOrNoAISendsNothing() async throws {
    let harness = try Harness()
    let brew = harness.brew()
    harness.defaults.set(false, forKey: NextCupAuto.enabledKey)
    harness.auto().brewReviewed(brew.id, store: harness.store)
    #expect(harness.pending == nil)

    harness.defaults.removeObject(forKey: NextCupAuto.enabledKey)
    let unavailable = harness.auto(available: false)
    unavailable.brewReviewed(brew.id, store: harness.store)
    await unavailable.job?.value
    #expect(harness.asked == 0)
    #expect(unavailable.status == .idle)
    #expect(harness.nextCups.isEmpty)
  }

  @Test func anUnacceptedNoticeSendsNothingUntilItIsAccepted() async throws {
    let harness = try Harness()
    let brew = harness.brew()
    let waiting = harness.auto(notice: .anthropic)
    waiting.brewReviewed(brew.id, store: harness.store)
    #expect(waiting.status == .needsNotice(.anthropic))
    #expect(waiting.job == nil && harness.asked == 0)
    #expect(harness.pending == brew.id.uuidString)

    let accepted = harness.auto()
    accepted.resume(store: harness.store)
    await accepted.job?.value
    #expect(harness.asked == 1 && harness.nextCups.count == 1)
  }

  @Test func decliningTheNoticeForgetsTheBrew() throws {
    let harness = try Harness()
    let auto = harness.auto(notice: .openAI)
    auto.brewReviewed(harness.brew().id, store: harness.store)
    auto.cancel()
    #expect(auto.status == .idle && harness.pending == nil)
  }

  @Test func anUnreviewedOrOlderBrewChangesNothing() async throws {
    let harness = try Harness()
    let auto = harness.auto()
    let untasted = harness.brew(nil)
    auto.brewReviewed(untasted.id, store: harness.store)
    #expect(harness.asked == 0)
    untasted.verdict = .sour

    let older = harness.brew(.sour, daysAgo: 3)
    auto.brewReviewed(older.id, store: harness.store)
    #expect(harness.asked == 0)
    #expect(NextCupAuto.applies(to: older, among: [older, untasted]) == false)
    #expect(NextCupAuto.applies(to: untasted, among: [older, untasted]))
    let otherMethod = BrewMethod(name: "Other")
    harness.container.mainContext.insert(otherMethod)
    let another = harness.brew(.sour, daysAgo: 5, method: otherMethod)
    #expect(NextCupAuto.applies(to: another, among: [older, untasted, another]))
  }

  @Test func aFailureKeepsTheOldRecipeAndCanBeRetried() async throws {
    let harness = try Harness()
    let brew = harness.brew()
    let first = harness.auto()
    first.brewReviewed(brew.id, store: harness.store)
    await first.job?.value
    let before = try #require(harness.nextCups.first?.updatedAt)

    let failing = harness.auto(failure: AIError.keyRejected)
    failing.brewReviewed(brew.id, store: harness.store)
    await failing.job?.value
    guard case .failed = failing.status else {
      Issue.record("expected a failure, got \(failing.status)")
      return
    }
    #expect(harness.pending == nil)
    #expect(harness.nextCups.first?.updatedAt == before)
    let asked = harness.asked
    failing.retry(store: harness.store)
    await failing.job?.value
    #expect(harness.asked == asked + 1)
  }

  @Test func noConnectionKeepsTheBrewWaitingAndADeletedOneIsDropped() async throws {
    let harness = try Harness()
    let brew = harness.brew()
    let offline = harness.auto(failure: AIError.offline)
    offline.brewReviewed(brew.id, store: harness.store)
    await offline.job?.value
    #expect(harness.pending == brew.id.uuidString)

    harness.container.mainContext.delete(brew)
    _ = harness.store.save()
    let asked = harness.asked
    let later = harness.auto()
    later.resume(store: harness.store)
    #expect(harness.pending == nil && harness.asked == asked)
  }

  @Test func onlyReviewedBrewsOfTheSameCategoryAreRead() throws {
    let harness = try Harness()
    let brew = harness.brew()
    let match = harness.brew(.balanced, dose: 19, water: 310, daysAgo: 1)
    let unreviewed = harness.brew(nil, daysAgo: 1)
    let otherSize = harness.brew(.sour, dose: 40, water: 650, daysAgo: 1)
    let pool = NextCupAI.sameCategory(as: brew, in: [brew, match, unreviewed, otherSize])
    let read = NextCupAI.similarBrews(to: brew, in: pool, limit: 8)
    #expect(read.map(\.id) == [match.id])
  }

  @Test func theDisclosureSaysItSendsOnSave() {
    let sends = AIFeature.diagnosis.sends
    #expect(sends.contains("When you save a brew with a taste or rating"))
    #expect(sends.contains("Settings → AI"))
  }
}
