import SwiftUI

/// The Settings tab's root. It lists the controls that exist so far; units, data
/// and privacy controls arrive with T020.
struct SettingsRootView: View {
  var body: some View {
    List {
      Section {
        NavigationLink {
          MethodsView()
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text("Brew methods").font(DS.Font.headline).foregroundStyle(DS.ink)
            Text("Add, rename, reorder and hide methods").font(.footnote)
              .foregroundStyle(DS.ink2)
          }
          .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("settings.methods")
      } header: {
        Text("Brewing")
      }
      Section {
        NavigationLink {
          DataSettingsView()
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text("Your data").font(DS.Font.headline).foregroundStyle(DS.ink)
            Text("Export, import, backups and delete all").font(.footnote)
              .foregroundStyle(DS.ink2)
          }
          .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("settings.data")
      } header: {
        Text("Data")
      } footer: {
        Text("Units and privacy controls will be here.")
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(DS.bg)
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("tab.root.settings")
  }
}
