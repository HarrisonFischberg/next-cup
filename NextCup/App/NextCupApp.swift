import NextCupKit
import SwiftUI

@main
struct NextCupApp: App {
  var body: some Scene {
    WindowGroup {
      LaunchView()
    }
  }
}

/// Placeholder root so the empty app launches; replaced by the tab shell in T006.
struct LaunchView: View {
  var body: some View {
    VStack(spacing: 8) {
      Text("Next Cup")
        .font(.largeTitle.bold())
      Text("Version \(NextCupKit.version)")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding()
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("launch.root")
  }
}
