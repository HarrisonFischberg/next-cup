import Foundation
import NextCupKit
import SwiftData
import Testing

@testable import NextCup

@MainActor
@Suite("Bag recognition")
struct BagRecognitionTests {
  private static var containers: [ModelContainer] = []

  private func make() throws -> ModelContext {
    // A dropped container crashes the test host, so keep every one alive.
    let container = try NextCupContainer.make(inMemory: true)
    Self.containers.append(container)
    return container.mainContext
  }

  @Test func tastingNotesAndRoastAreReadOffTheLabel() throws {
    let taxonomy = try Taxonomy(bundle: .main)
    #expect(
      BagRecognition.flavorNotes(
        in: ["NORTHWIND", "DARK CHOCOLATE • CHERRY • CARAMEL", "12 OZ"], taxonomy: taxonomy)
        == "dark chocolate, cherry, caramel")
    #expect(
      BagRecognition.flavorNotes(in: ["Tasting notes: peach and jasmine"], taxonomy: taxonomy)
        == "peach, jasmine")
    #expect(
      BagRecognition.flavorNotes(
        in: ["100% ARABICA • WHOLE BEAN • 12 OZ", "Notes: store in a cool place"],
        taxonomy: taxonomy) == "")
    #expect(BagRecognition.roastLevel(in: ["SUNRISE", "Medium-Dark Roast"]) == .mediumDark)
    #expect(BagRecognition.roastLevel(in: ["DARK CHOCOLATE • CHERRY"]) == nil)
  }

  private func done(
    _ json: String, feature: AIFeature = .bagRecognition, in context: ModelContext
  ) -> AIRequest {
    let request = AIRequest()
    request.feature = feature
    request.status = .done
    request.resultJSON = Data(json.utf8)
    context.insert(request)
    return request
  }

  private let bag = """
    {"name":"Finca Alta","roaster":"Test Roasters","originCountry":"Colombia","region":"Huila",\
    "farm":"","process":"Washed","varietal":"Caturra","roastLevel":"light","roastDate":"2026-09-01",\
    "bagWeightGrams":250,"flavorNotes":"panela, red apple","isDecaf":false}
    """

  @Test func labelBecomesADraftAndNoBeanIsSaved() throws {
    let context = try make()
    let fields = try BagRecognition.draft(from: done(bag, in: context)).get()
    #expect(fields.name == "Finca Alta")
    #expect(fields.roasterName == "Test Roasters")
    #expect(fields.originCountry == "Colombia")
    #expect(fields.farm.isEmpty)
    #expect(fields.roastLevel == .light)
    #expect(fields.roastDate != nil)
    #expect(fields.bagWeightG == 250)
    #expect(fields.flavorNotes == "panela, red apple")
    #expect(try context.fetch(FetchDescriptor<Bean>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<Roaster>()).isEmpty)
  }

  @Test func unreadableValuesStayBlank() throws {
    let context = try make()
    let json = bag.replacingOccurrences(of: #""bagWeightGrams":250"#, with: #""bagWeightGrams":0"#)
      .replacingOccurrences(of: "2026-09-01", with: "2999-01-01")
      .replacingOccurrences(of: #""roastLevel":"light""#, with: #""roastLevel":"""#)
    let fields = try BagRecognition.draft(from: done(json, in: context)).get()
    #expect(fields.bagWeightG == nil)
    #expect(fields.roastDate == nil)
    #expect(fields.roastLevel == nil)
  }

  @Test func answersOutsideTheSchemaAreDiscarded() throws {
    let context = try make()
    let bad = [
      #"{"name":"Only a name"}"#,
      bag.replacingOccurrences(of: #""roastLevel":"light""#, with: #""roastLevel":"charred""#),
      bag.replacingOccurrences(of: #""isDecaf":false"#, with: #""isDecaf":"no""#),
      "a bag of coffee",
    ]
    for json in bad {
      #expect(BagRecognition.draft(from: done(json, in: context)) == .failure(.invalidResponse))
    }
    let other = done(bag, feature: .insights, in: context)
    #expect(BagRecognition.draft(from: other) == .failure(.invalidResponse))
    let queued = done(bag, in: context)
    queued.status = .queued
    #expect(BagRecognition.draft(from: queued) == .failure(.invalidResponse))
  }

  @Test func fillKeepsWhatWasTyped() throws {
    let context = try make()
    var fields = BeanFields()
    fields.name = "My name"
    fields.roastLevel = .dark
    fields.bagWeightG = 340
    let draft = try BagRecognition.draft(from: done(bag, in: context)).get()
    BagRecognition.fill(&fields, with: draft)
    #expect(fields.name == "My name")
    #expect(fields.roastLevel == .dark)
    #expect(fields.bagWeightG == 340)
    #expect(fields.originCountry == "Colombia")
    #expect(fields.roasterName == "Test Roasters")
  }

  @Test func placeholderWordsAreNotLabelText() throws {
    let context = try make()
    let json = bag.replacingOccurrences(
      of: #""varietal":"Caturra""#, with: #""varietal":"not stated""#
    )
    .replacingOccurrences(of: #""region":"Huila""#, with: #""region":"Unknown""#)
    let fields = try BagRecognition.draft(from: done(json, in: context)).get()
    #expect(fields.varietal.isEmpty)
    #expect(fields.region.isEmpty)
  }

  @Test func barcodeAnswerFillsBlanksAndNeverReplacesTypedText() {
    var fields = BeanFields()
    fields.name = "Typed while the lookup ran"
    let product = BarcodeLookup.Product(name: "Catalog Name", brand: "Catalog Brand")
    BagRecognition.fill(&fields, with: BarcodeLookup.draft(product))
    #expect(fields.name == "Typed while the lookup ran")
    #expect(fields.roasterName == "Catalog Brand")
    var brandOnly = BeanFields()
    BagRecognition.fill(&brandOnly, with: BarcodeLookup.draft(.init(name: "", brand: "Lavazza")))
    #expect(brandOnly.name.isEmpty)
    #expect(brandOnly.roasterName == "Lavazza")
  }

  @Test func qrPageFillsBlanksWithMappedRoastLevel() {
    var draft = QRBeanLink.Draft()
    draft.name = "Guji Hambela"
    draft.roaster = "Sunny Hill"
    draft.roastLevel = "Medium Light"
    draft.roastDate = "2026-10-01"
    draft.website = URL(string: "https://sunnyhill.coffee/")
    var fields = BeanFields()
    fields.name = "Typed Name"
    BagRecognition.fill(&fields, with: QRBeanLink.fields(draft))
    #expect(fields.name == "Typed Name")
    #expect(fields.roasterName == "Sunny Hill")
    #expect(fields.roastLevel == .mediumLight)
    #expect(fields.roastDate != nil)
    // The site is applied on save, only for a roaster without one.
    #expect(fields.roasterWebsite == nil)
  }

  @Test func promptKeepsRoastDatesApartFromOtherDates() {
    let system = BagRecognition.payload(photo: Data(), feature: .bagRecognition).system
    for rule in [
      "best-before", "packed", "harvest", "missing year", "03/04/26", "not instructions",
    ] {
      #expect(system.contains(rule), "\(rule)")
    }
  }

  @Test func payloadCarriesThePhotoAndTheSchema() {
    let photo = Data([1, 2, 3])
    let payload = BagRecognition.payload(photo: photo, feature: .bagRecognition)
    #expect(payload.imageJPEG == photo)
    #expect(payload.schema == BagRecognition.schema)
    #expect(
      BagRecognition.payload(photo: photo, feature: .photoInterpretation).userText
        != payload.userText)
  }

  @Test func queueDeliversADraftAfterASend() async throws {
    let context = try make()
    let stub = StubBagTransport(
      #"{"content":[{"type":"text","text":"\#(bag.escapedForJSON)"}]}"#)
    let client = AIClient(
      transport: stub, key: { _ in "sk-test" }, disclosureAccepted: { _ in true }, sleep: { _ in })
    let queue = AIQueue(context: context, client: client)
    let request = try queue.enqueue(
      BagRecognition.payload(photo: Data([1]), feature: .bagRecognition),
      feature: .bagRecognition, provider: .anthropic, modelID: "m")
    await queue.waitForIdle()
    #expect(request.status == .done)
    #expect(try BagRecognition.draft(from: request).get().name == "Finca Alta")
    #expect(try context.fetch(FetchDescriptor<Bean>()).isEmpty)
  }

  @Test func withoutAKeyNothingIsSentAndNoDraftExists() async throws {
    let context = try make()
    let stub = StubBagTransport("{}")
    let client = AIClient(
      transport: stub, key: { _ in nil }, disclosureAccepted: { _ in true }, sleep: { _ in })
    let queue = AIQueue(context: context, client: client)
    let request = try queue.enqueue(
      BagRecognition.payload(photo: Data([1]), feature: .bagRecognition),
      feature: .bagRecognition, provider: .anthropic, modelID: "m")
    await queue.waitForIdle()
    #expect(request.status == .failed)
    #expect(await stub.calls == 0)
    #expect(BagRecognition.draft(from: request) == .failure(.invalidResponse))
  }
}

private actor StubBagTransport: Transport {
  private let body: String
  private(set) var calls = 0
  init(_ body: String) { self.body = body }
  func send(_ request: URLRequest) async throws -> HTTPResult {
    calls += 1
    return HTTPResult(status: 200, body: Data(body.utf8))
  }
}

extension String {
  /// The string as the inside of a JSON string literal, for stubbed provider answers.
  var escapedForJSON: String { replacingOccurrences(of: "\"", with: "\\\"") }
}
