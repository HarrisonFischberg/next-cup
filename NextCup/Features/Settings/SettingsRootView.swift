import NextCupKit
import SwiftUI

/// The Settings root: appearance, units, brewing, AI, data, privacy and about.
struct SettingsRootView: View {
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue

  private var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = info?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  }

  var body: some View {
    ScrollViewReader { proxy in
      list
        .onAppear {
          // Changing a flavor rebuilds the app; come back to the section being edited.
          let defaults = UserDefaults.standard
          guard defaults.bool(forKey: FlavorPicker.returnKey) else { return }
          defaults.removeObject(forKey: FlavorPicker.returnKey)
          proxy.scrollTo("appearance", anchor: .top)
        }
    }
  }

  private var list: some View {
    List {
      Section {
        Picker("Appearance", selection: $appearance) {
          ForEach(AppearanceMode.allCases) { Text($0.title).tag($0.rawValue) }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: DS.Size.control)
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("settings.appearance")
        FlavorPicker()
          .id("appearance")
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
      } header: {
        Text("Appearance")
      } footer: {
        Text("A flavor sets colors, type, corners and spacing. Pick one to try it.")
      }
      Section {
        Picker("Weight", selection: $weightUnit) {
          Text("Grams (g)").tag(WeightUnit.grams.rawValue)
          Text("Ounces (oz)").tag(WeightUnit.ounces.rawValue)
        }
        .pickerStyle(.segmented)
        .frame(minHeight: DS.Size.control)
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("settings.units.weight")
        Picker("Temperature", selection: $temperatureUnit) {
          Text("Celsius (°C)").tag(TemperatureUnit.celsius.rawValue)
          Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit.rawValue)
        }
        .pickerStyle(.segmented)
        .frame(minHeight: DS.Size.control)
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("settings.units.temperature")
      } header: {
        Text("Units")
      } footer: {
        Text(
          "Applies to the journal, recipes, timer and brew form. Values are stored in grams and °C."
        )
      }
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
          AISettingsView()
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text("AI").font(DS.Font.headline).foregroundStyle(DS.ink)
            Text("Apple AI, or your own Anthropic or OpenAI key").font(.footnote)
              .foregroundStyle(DS.ink2)
          }
          .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("settings.ai")
      } header: {
        Text("AI")
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
      }
      Section {
        NavigationLink {
          PrivacySummaryView()
        } label: {
          Text("What stays on this iPhone").font(DS.Font.headline).foregroundStyle(DS.ink)
            .frame(minHeight: DS.Size.control, alignment: .leading)
        }
        .listRowBackground(DS.paper)
        .accessibilityIdentifier("settings.privacy")
      } header: {
        Text("Privacy")
      }
      Section {
        LabeledContent("Version", value: appVersion)
          .listRowBackground(DS.paper)
          .accessibilityIdentifier("settings.about.version")
      } header: {
        Text("About")
      } footer: {
        Text("Next Cup is free, has no ads and needs no account.")
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

/// Plain-language summary of what the app stores and what leaves the device.
struct PrivacySummaryView: View {
  var body: some View {
    List {
      Section {
        row("Your brews, beans, recipes and photos are stored only on this iPhone.")
        row("There is no account, no analytics and no advertising.")
        row("Photos are saved without location or camera metadata.")
        row(
          "Nothing is sent anywhere. AI features, if added later, stay off until you add "
            + "your own key and agree to a disclosure."
        )
        row("Export your data or delete all of it under Settings → Your data.")
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(DS.bg)
    .navigationTitle("Privacy")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("settings.privacy.summary")
  }

  private func row(_ text: String) -> some View {
    Text(text).font(.body).foregroundStyle(DS.ink)
      .listRowBackground(DS.paper)
  }
}
