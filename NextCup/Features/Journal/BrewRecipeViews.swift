import SwiftData
import SwiftUI
import UIKit

/// What a brew's card and page show of its recipe: the live recipe while it exists, the
/// brew's snapshot of it once deleted. `nil` for a brew made without a recipe.
struct BrewRecipeInfo {
  var name: String
  var symbol: String
  var isDeleted: Bool

  init?(_ brew: Brew) {
    if let recipe = brew.recipe {
      (name, isDeleted) = (recipe.name, false)
      symbol = recipe.method?.symbol ?? brew.method?.symbol ?? "cup.and.saucer"
    } else if let snapshot = brew.recipeSnapshot {
      (name, isDeleted) = (snapshot.name, true)
      symbol = snapshot.methodSymbol ?? brew.method?.symbol ?? "cup.and.saucer"
    } else {
      return nil
    }
  }

  /// "Recipe: Kasuya 4:6" or "Recipe: Kasuya 4:6, Recipe deleted".
  var accessibilityLabel: String { "Recipe: \(name)" + (isDeleted ? ", Recipe deleted" : "") }
}

/// The recipe line on a journal card and a brew's page: the brewer's symbol and the recipe's
/// name in an outlined capsule (the taste tags are filled), and "Recipe deleted" once it is
/// gone. The card's one star covers the brew and its recipe.
struct BrewRecipeChip: View {
  let info: BrewRecipeInfo

  var body: some View {
    HStack(spacing: DS.Space.xs) {
      Image(systemName: info.symbol).font(.caption.weight(.semibold))
        .foregroundStyle(DS.ink2)
      Text(info.name).font(.caption.weight(.semibold)).foregroundStyle(DS.ink)
        .lineLimit(1)
      if info.isDeleted {
        Text("Recipe deleted").font(.caption).foregroundStyle(DS.ink2).lineLimit(1)
      }
    }
    .padding(.horizontal, DS.Space.sm).padding(.vertical, 4)
    .overlay(Capsule().strokeBorder(DS.ink.opacity(0.18), lineWidth: 1))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(info.accessibilityLabel)
  }
}

/// The recipe action a brew offers, on the journal's long-press menu and the brew's page:
/// save a deleted recipe again from what the brew kept of it. (The recipe's star follows the
/// brew's: `Store.toggleFavorite(_:)`.)
@MainActor
enum BrewRecipeAction {
  case restore

  init?(_ brew: Brew) {
    guard brew.recipe == nil, brew.recipeSnapshotJSON != nil else { return nil }
    self = .restore
  }

  var title: String { "Save recipe again" }
  var symbol: String { "arrow.uturn.backward" }
  var identifier: String { "journal.restoreRecipe" }

  /// Runs the action with a light tap on success; a failure returns the message to show.
  func perform(on brew: Brew, store: Store, reduceMotion: Bool) -> String? {
    var failure: StoreError?
    withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
      if case .failure(let error) = store.restoreRecipe(for: brew) { failure = error }
    }
    guard case .saveFailed(let message) = failure else {
      Feedback.tap()
      return nil
    }
    Feedback.error()
    return "The recipe was not saved. \(message)"
  }
}

/// A saved brew's recipe, on its page: the recipe line (opening the recipe while it exists)
/// and its one action beside it.
struct BrewRecipeSection: View {
  let brew: Brew
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var error: String?

  var body: some View {
    if let info = BrewRecipeInfo(brew) {
      VStack(alignment: .leading, spacing: DS.Space.sm) {
        Text("RECIPE").font(DS.Font.label).foregroundStyle(DS.ink2)
        HStack(spacing: DS.Space.md) {
          if let recipe = brew.recipe {
            NavigationLink(value: DeepLink.recipe(recipe.id)) { BrewRecipeChip(info: info) }
              .buttonStyle(PressableStyle())
              .frame(minHeight: DS.Size.minTap)
              .accessibilityHint("Opens the recipe")
              .accessibilityIdentifier("brewform.recipe")
          } else {
            BrewRecipeChip(info: info).frame(minHeight: DS.Size.minTap)
              .accessibilityIdentifier("brewform.recipe")
          }
          Spacer(minLength: 0)
          if let action = BrewRecipeAction(brew) {
            Button {
              error = action.perform(
                on: brew, store: Store(context: context), reduceMotion: reduceMotion)
            } label: {
              Label(action.title, systemImage: action.symbol)
                .font(.subheadline.weight(.semibold)).foregroundStyle(DS.ink)
                .frame(minHeight: DS.Size.minTap)
            }
            .accessibilityIdentifier(
              action.identifier.replacingOccurrences(of: "journal.", with: "brewform."))
          }
        }
        if let error {
          StateBanner(kind: .error, message: error).accessibilityIdentifier("brewform.recipeError")
        }
      }
    }
  }
}
