import NextCupKit
import SwiftData
import SwiftUI
@preconcurrency import UserNotifications

// The daily loop: brew, let the cup rest, taste it (a reminder 20 minutes after
// brewing), then one change for the next cup. The rules suggestion is stored by
// SuggestionService and the next brew of the same bean opens with it on offer.

/// Where today's cup is in the loop.
enum LoopStation: Int, CaseIterable {
  case brew, rest, taste, next
  var label: String { ["Brew", "Rest", "Taste", "Next"][rawValue] }
}

/// Four stations on a hairline: done ones filled, the current one ringed in the accent.
struct LoopStrip: View {
  let at: LoopStation
  var detail: String?
  @Environment(\.dynamicTypeSize) private var dts

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      HStack(spacing: 0) {
        ForEach(LoopStation.allCases, id: \.self) { station in
          let done = station.rawValue < at.rawValue
          let now = station == at
          HStack(spacing: 0) {
            ZStack {
              Circle().fill(done ? DS.signal : .clear).frame(width: 9, height: 9)
              Circle().stroke(done || now ? DS.signal : DS.line.opacity(0.5), lineWidth: 1.5)
                .frame(width: now ? 15 : 9, height: now ? 15 : 9)
            }
            .frame(width: 16)
            if station != .next {
              Rectangle().fill(done ? DS.signal : DS.line.opacity(0.5)).frame(height: 1.5)
            }
          }
        }
      }
      if dts.isAccessibilitySize {
        // Four labels cannot fit side by side at these sizes; name the current one.
        Text(at.label).font(.caption.weight(.semibold)).foregroundStyle(DS.signal)
      } else {
        labels
      }
      if let detail { Text(detail).font(.footnote).foregroundStyle(DS.ink2) }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Today's cup: \(at.label)\(detail.map { ". \($0)" } ?? "")")
  }

  private var labels: some View {
    HStack(spacing: 0) {
      ForEach(LoopStation.allCases, id: \.self) { station in
        Text(station.label).font(.caption.weight(station == at ? .semibold : .regular))
          .foregroundStyle(station == at ? DS.signal : DS.ink2)
          .frame(maxWidth: station == .next ? nil : .infinity, alignment: .leading)
      }
    }
  }
}

/// "Grind: 20 → 19", or "Grind: one step finer" when the brew had no value to start from.
func loopHeadline(_ suggestion: Suggestion) -> String {
  guard suggestion.fromValue.trimmingCharacters(in: .whitespaces).isEmpty else {
    return SuggestionFormat.headline(suggestion, UnitStorage.preferences())
  }
  return "\(SuggestionFormat.title(suggestion.field)): \(suggestion.toValue)"
}

// MARK: Reminder

/// A local notification 20 minutes after a brew is saved without a taste, so the
/// cup is tasted once it has cooled a little. Permission is asked here, in
/// context, the first time a brew is saved untasted; never at launch.
enum TasteReminder {
  static let delayS: TimeInterval = 20 * 60
  static let delegate = Delegate()

  static func id(_ brewID: UUID) -> String { "taste.\(brewID.uuidString)" }

  /// When to taste a brew saved at `brewedAt`.
  static func due(after brewedAt: Date) -> Date { brewedAt.addingTimeInterval(delayS) }

  static func schedule(brewID: UUID, beanName: String?, brewedAt: Date) {
    let wait = due(after: brewedAt).timeIntervalSinceNow
    guard wait > 0 else { return }
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { return }
      let content = UNMutableNotificationContent()
      content.title = beanName.map { "How's your \($0)?" } ?? "How's your coffee?"
      content.body = "Take a sip and note how it tastes. It takes ten seconds."
      content.sound = .default
      content.userInfo = ["url": DeepLink.taste(brewID).url.absoluteString]
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
      center.add(UNNotificationRequest(identifier: id(brewID), content: content, trigger: trigger))
    }
  }

  static func cancel(brewID: UUID) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
      id(brewID)
    ])
  }

  /// Opens the taste screen when the reminder is tapped, and shows it as a banner
  /// if the app is open when it fires.
  final class Delegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
      _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
      guard let text = response.notification.request.content.userInfo["url"] as? String,
        let url = URL(string: text), DeepLink(url: url) != nil
      else { return }
      await MainActor.run { UIApplication.shared.open(url) }
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
      [.banner, .sound]
    }
  }
}

// MARK: Today card

/// The top of the journal while today's cup is in the loop: resting and waiting to
/// be tasted, or tasted with one change ready for the next cup.
struct TodayCard: View {
  let brew: Brew
  let taste: () -> Void

  private var name: String { brew.beanNames.first ?? brew.method?.name ?? "Today's cup" }
  private var due: Date { TasteReminder.due(after: brew.date) }
  private var proposal: Suggestion? {
    (brew.suggestionsMade ?? []).first { $0.source == .rules && $0.state == .proposed }
  }

  /// Shown for a brew from today that is untasted, or tasted with a change waiting.
  static func applies(to brew: Brew, now: Date = .now) -> Bool {
    guard Calendar.current.isDate(brew.date, inSameDayAs: now) else { return false }
    let waiting = (brew.suggestionsMade ?? []).contains {
      $0.source == .rules && $0.state == .proposed
    }
    return brew.verdict == nil || waiting
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      VStack(alignment: .leading, spacing: DS.Space.xs) {
        Text(name).font(.system(.title, design: .serif, weight: .medium)).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text(
          "Brewed at \(brew.date.formatted(date: .omitted, time: .shortened))"
            + (brew.method.map { " on the \($0.name.lowercased())" } ?? "")
        )
        .font(.subheadline).foregroundStyle(DS.ink2)
      }
      if brew.verdict == nil {
        TimelineView(.everyMinute) { context in
          let resting = context.date < due
          VStack(alignment: .leading, spacing: DS.Space.lg) {
            LoopStrip(
              at: resting ? .rest : .taste,
              detail: resting
                ? "Resting so the flavours open up. We'll ask how it tastes at \(due.formatted(date: .omitted, time: .shortened))."
                : "It has cooled a little. Note how it tastes.")
            Button(action: taste) {
              Text(resting ? "Taste it now" : "How does it taste?").font(.body.weight(.semibold))
                .padding(.horizontal, DS.Space.xl).frame(minHeight: 50)
                .foregroundStyle(DS.onSignal).background(DS.signal, in: Capsule())
            }
            .accessibilityIdentifier("today.taste")
          }
        }
      } else if let proposal {
        LoopStrip(at: .next, detail: "Tomorrow, change one thing.")
        Text(loopHeadline(proposal))
          .font(.system(.title3, design: .serif)).foregroundStyle(DS.ink)
          .accessibilityIdentifier("today.next")
        Text(proposal.rationale).font(.footnote).foregroundStyle(DS.ink2)
      }
    }
    .padding(DS.Space.xl)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper)
    // A marker, not an identifier on the card: that would replace its button's.
    .background { Color.clear.accessibilityElement().accessibilityIdentifier("journal.today") }
  }
}

// MARK: Taste, then the next cup

/// Opened from the reminder, the Today card or `nextcup://taste/<id>`: how the cup
/// tasted, then the one change the rules suggest for the next cup.
struct TasteView: View {
  let brew: Brew
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var tastes: [Verdict] = []
  @State private var tenths = 0
  @State private var notes = ""
  @FocusState private var notesFocused: Bool
  @State private var outcome: DialInOutcome?
  @State private var error: String?
  @Environment(\.dynamicTypeSize) private var dts

  private static let words: [(Verdict, String)] = [
    (.sour, "Sharp, thin, lemony"), (.bitter, "Dry, harsh, ashy"), (.weak, "Watery, light"),
    (.bright, "Lively, juicy, fruity"),
    (.strong, "Heavy, intense"), (.balanced, "Sweet, round, clean"),
  ]

  private var proposal: Suggestion? {
    (brew.suggestionsMade ?? []).first { $0.source == .rules && $0.state == .proposed }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Space.xl) {
        if let outcome { next(outcome) } else { taste }
        if let error {
          StateBanner(kind: .error, message: error, actionTitle: "Dismiss") { self.error = nil }
        }
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle(brew.beanNames.first ?? "Taste")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarVisibility(.hidden, for: .tabBar)
    .safeAreaInset(edge: .bottom, spacing: 0) { actions.hiddenWhileTyping() }
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { notesFocused = false }
      }
    }
    .onAppear {
      tastes = brew.verdicts
      tenths = brew.ratingTenths ?? 0
      notes = brew.notes
    }
    .accessibilityIdentifier("taste.screen")
  }

  private var taste: some View {
    VStack(alignment: .leading, spacing: DS.Space.xl) {
      LoopStrip(
        at: .taste,
        detail: "Brewed at \(brew.date.formatted(date: .omitted, time: .shortened)).")
      Text("How does it taste?").font(DS.Font.display).foregroundStyle(DS.ink)
        .dynamicTypeSize(...DS.displayCap).accessibilityAddTraits(.isHeader)
      Text("Pick all that apply.").font(.footnote).foregroundStyle(DS.ink2)
      VStack(spacing: 0) {
        ForEach(Self.words, id: \.0) { option, words in
          let on = tastes.contains(option)
          Button {
            tastes = Verdict.picked(Verdict.toggled(option, in: Verdict.joined(tastes)))
          } label: {
            HStack(spacing: DS.Space.md) {
              VStack(alignment: .leading, spacing: 2) {
                Text(option.rawValue.capitalized).font(.body.weight(on ? .semibold : .regular))
                  .foregroundStyle(DS.ink)
                Text(words).font(.footnote).foregroundStyle(DS.ink2)
              }
              Spacer(minLength: DS.Space.sm)
              Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title2)
                .foregroundStyle(on ? DS.signal : DS.line)
            }
            .padding(.horizontal, DS.Space.lg).frame(minHeight: 64).contentShape(Rectangle())
            .background(on ? DS.signal.opacity(0.08) : .clear)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(on ? .isSelected : [])
          .accessibilityIdentifier("taste.\(option.rawValue)")
          .sensoryFeedback(.selection, trigger: on)
          if option != .balanced {
            Rectangle().fill(DS.line.opacity(0.3)).frame(height: 1).padding(.leading, DS.Space.lg)
          }
        }
      }
      .panel(DS.paper)
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text("Overall").font(DS.Font.headline).foregroundStyle(DS.ink)
        GradeScale(tenths: $tenths)
      }
      TextField("Anything else you notice? (optional)", text: $notes, axis: .vertical)
        .focused($notesFocused)
        .lineLimit(1...4).padding(DS.Space.lg)
        .panel(DS.paper)
    }
  }

  @ViewBuilder private func next(_ outcome: DialInOutcome) -> some View {
    LoopStrip(
      at: .next,
      detail: "You said \(tastes.isEmpty ? "–" : tastes.map(\.rawValue).joined(separator: ", "))"
        + (tenths > 0 ? ", \(Rating.text(tenths)) of 10." : "."))
    VStack(alignment: .leading, spacing: DS.Space.lg) {
      switch outcome {
      case .change:
        if let proposal {
          Text("Change one thing").font(DS.Font.display).foregroundStyle(DS.ink)
            .dynamicTypeSize(...DS.displayCap)
          Text(loopHeadline(proposal))
            .font(.system(.title, design: .serif, weight: .medium)).foregroundStyle(DS.signal)
            .accessibilityIdentifier("taste.change")
          Text(proposal.rationale).font(.body).foregroundStyle(DS.ink2)
          Text(
            "The next brew of this bean opens with this change on offer. You can still adjust it."
          )
          .font(.footnote).foregroundStyle(DS.ink2)
        }
      case .keep(let reason):
        Text("Brew it the same way").font(DS.Font.display).foregroundStyle(DS.ink)
          .dynamicTypeSize(...DS.displayCap)
        Text(reason).font(.body).foregroundStyle(DS.ink2)
          .accessibilityIdentifier("taste.keep")
      }
    }
    .padding(DS.Space.xl)
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(DS.paper)
  }

  private var actions: some View {
    // Side by side, or stacked when the text is too large to share a row.
    (dts.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: DS.Space.sm))
      : AnyLayout(HStackLayout(spacing: DS.Space.md))) {
        if outcome == nil {
          SteelButton(title: "See tomorrow's change") { save() }
            .disabled(tastes.isEmpty)
            .accessibilityIdentifier("taste.save")
        } else {
          if let proposal {
            SteelButton(title: "Not this time", kind: .secondary) { answer(proposal, .dismissed) }
              .accessibilityIdentifier("taste.dismiss")
          }
          SteelButton(title: proposal == nil ? "Done" : "Use tomorrow") { dismiss() }
            .accessibilityIdentifier("taste.done")
        }
      }
      .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
      .background(DS.bg)
  }

  private func save() {
    let store = Store(context: context)
    brew.verdict = tastes.first
    brew.alsoTasted = tastes.count > 1 ? tastes.dropFirst().map(\.rawValue) : nil
    brew.ratingTenths = tenths > 0 ? tenths : nil
    brew.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    brew.updatedAt = Date()
    if case .failure(let failure) = store.save() {
      error = failure.localizedDescription
      return
    }
    TasteReminder.cancel(brewID: brew.id)
    NextCupAuto.shared.brewReviewed(brew.id, store: store)
    switch SuggestionService(store: store).propose(for: brew) {
    case .success(let result):
      withAnimation(.smooth(duration: 0.35)) { outcome = result }
    case .failure(let failure):
      error = failure.localizedDescription
    }
  }

  private func answer(_ suggestion: Suggestion, _ state: SuggestionState) {
    suggestion.state = state
    suggestion.updatedAt = Date()
    if case .failure(let failure) = Store(context: context).save() {
      error = failure.localizedDescription
      return
    }
    dismiss()
  }
}
