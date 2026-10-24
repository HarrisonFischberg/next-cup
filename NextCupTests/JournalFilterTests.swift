import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("JournalFilter")
struct JournalFilterTests {
  @MainActor
  private struct Harness {
    let container: ModelContainer
    let pour: BrewMethod
    let press: BrewMethod
    let brews: [Brew]

    init() throws {
      container = try NextCupContainer.make(inMemory: true)
      let context = container.mainContext
      pour = BrewMethod(name: "Cone", style: .pourOver)
      press = BrewMethod(name: "Press", style: .immersion)
      context.insert(pour)
      context.insert(press)

      func brew(
        _ daysAgo: Int, method: BrewMethod, notes: String = "", grade: Int? = nil,
        bean: String? = nil
      ) -> Brew {
        let brew = Brew(date: Date(timeIntervalSince1970: 1_800_000_000 - Double(daysAgo) * 86_400))
        brew.method = method
        brew.notes = notes
        brew.ratingHalfSteps = grade
        context.insert(brew)
        if let bean {
          let use = BrewBean(grams: 15, beanNameSnapshot: bean)
          context.insert(use)
          use.brew = brew
        }
        return brew
      }
      brews = [
        brew(1, method: pour, notes: "Sweet and clean", grade: 8, bean: "Ethiopia Guji"),
        brew(2, method: press, notes: "Heavy body", grade: 6, bean: "Colombia Huila"),
        brew(3, method: pour, notes: "Sour, grind finer", grade: 4, bean: "Ethiopia Guji"),
        brew(4, method: pour),
      ]
    }
  }

  @Test("no filter keeps everything, newest first")
  func defaultOrder() throws {
    let h = try Harness()
    let result = JournalFilter().apply(to: h.brews.reversed())
    #expect(result.map(\.date) == result.map(\.date).sorted(by: >))
    #expect(result.count == 4)
    #expect(!JournalFilter().isNarrowing)
  }

  @Test("search reads notes, method, grind and bean names")
  func search() throws {
    let h = try Harness()
    #expect(JournalFilter(search: "sweet").apply(to: h.brews).count == 1)
    #expect(JournalFilter(search: "press").apply(to: h.brews).count == 1)
    #expect(JournalFilter(search: "guji").apply(to: h.brews).count == 2)
    #expect(JournalFilter(search: "  ").apply(to: h.brews).count == 4)
    #expect(JournalFilter(search: "zzzz").apply(to: h.brews).isEmpty)
    #expect(JournalFilter(search: "zzzz").isNarrowing)
  }

  @Test("method and bean filters combine with search")
  func filters() throws {
    let h = try Harness()
    #expect(JournalFilter(methodID: h.pour.id).apply(to: h.brews).count == 3)
    #expect(JournalFilter(beanName: "Colombia Huila").apply(to: h.brews).count == 1)
    let both = JournalFilter(search: "sour", methodID: h.pour.id, beanName: "Ethiopia Guji")
    #expect(both.apply(to: h.brews).count == 1)
    #expect(
      JournalFilter(methodID: h.press.id, beanName: "Ethiopia Guji").apply(to: h.brews).isEmpty)
  }

  @Test("highest grade puts unrated brews last and ties by date")
  func topGrade() throws {
    let h = try Harness()
    let result = JournalFilter(sort: .topGrade).apply(to: h.brews)
    #expect(result.map(\.ratingHalfSteps) == [8, 6, 4, nil])
    let oldest = JournalFilter(sort: .oldest).apply(to: h.brews)
    #expect(oldest.first?.date == h.brews.last?.date)
  }
}
