import SwiftData
import SwiftUI
import UIKit

/// What a brew's card and page show of its recipe: the live recipe while it exists, the
/// brew's snapshot of it once deleted. `nil` for a brew made without a recipe.
struct BrewRecipeInfo {
  var name: String
  var symbol: String
  var isDeleted: Bool
  var isFavorite: Bool

  init?(_ brew: Brew) {
    if let recipe = brew.recipe {
      (name, isDeleted, isFavorite) = (recipe.name, false, recipe.isFavorite)
      symbol = recipe.method?.symbol ?? brew.method?.symbol ?? "cup.and.saucer"
    } else if let snapshot = brew.recipeSnapshot {
      (name, isDeleted, isFavorite) = (snapshot.name, true, false)
      symbol = snapshot.methodSymbol ?? brew.method?.symbol ?? "cup.and.saucer"
    } else {
      return nil
    }
  }

  /// "Recipe: Kasuya 4:6, favorite recipe" or "Recipe: Kasuya 4:6, Recipe deleted".
  var accessibilityLabel: String {
    "Recipe: \(name)" + (isDeleted ? ", Recipe deleted" : "")
      + (isFavorite ? ", favorite recipe" : "")
  }
}

/// The recipe line on a journal card and a brew's page: the brewer's symbol and the recipe's
/// name in an outlined capsule (the taste tags are filled), the favorite star when the recipe
/// is starred, and "Recipe deleted" once it is gone.
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
      if info.isFavorite {
        Image(systemName: "star.fill").font(.caption2.weight(.bold))
          .foregroundStyle(DS.favorite)
          .transition(.scale(scale: 0.5).combined(with: .opacity))
      }
    }
    .padding(.horizontal, DS.Space.sm).padding(.vertical, 4)
    .overlay(Capsule().strokeBorder(DS.ink.opacity(0.18), lineWidth: 1))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(info.accessibilityLabel)
  }
}

/// The recipe actions a brew offers, for the journal's long-press menu and the brew's page:
/// star or unstar the recipe (its own star on the Brew tab, apart from the brew's), or save a
/// deleted recipe again from what the brew kept of it.
@MainActor
enum BrewRecipeAction {
  case favorite(Recipe)
  case restore

  init?(_ brew: Brew) {
    if let recipe = brew.recipe {
      self = .favorite(recipe)
    } else if brew.recipeSnapshotJSON != nil {
      self = .restore
    } else {
      return nil
    }
  }

  var title: String {
    switch self {
    case .favorite(let recipe): recipe.isFavorite ? "Unfavorite recipe" : "Favorite recipe"
    case .restore: "Save recipe again"
    }
  }

  var symbol: String {
    switch self {
    case .favorite(let recipe): recipe.isFavorite ? "star.slash" : "star.circle"
    case .restore: "arrow.uturn.backward"
    }
  }

  var identifier: String {
    switch self {
    case .favorite: "journal.favoriteRecipe"
    case .restore: "journal.restoreRecipe"
    }
  }

  /// Runs the action with a light tap on success; a failure returns the message to show.
  func perform(on brew: Brew, store: Store, reduceMotion: Bool) -> String? {
    var failure: StoreError?
    withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
      switch self {
      case .favorite(let recipe):
        if case .failure(let error) = store.toggleFavorite(recipe, \.isFavorite) { failure = error }
      case .restore:
        if case .failure(let error) = store.restoreRecipe(for: brew) { failure = error }
      }
    }
    guard case .saveFailed(let message) = failure else {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      return nil
    }
    UINotificationFeedbackGenerator().notificationOccurred(.error)
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
              .buttonStyle(.plain)
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
