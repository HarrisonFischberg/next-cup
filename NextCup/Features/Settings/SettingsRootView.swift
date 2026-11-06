import NextCupKit
import SwiftUI

/// The Settings root: appearance, units, brewing, AI, data, privacy and about.
struct SettingsRootView: View {
  @AppStorage(UnitStorage.weightKey) private var weightUnit = WeightUnit.grams.rawValue
  @AppStorage(UnitStorage.temperatureKey) private var temperatureUnit = TemperatureUnit.celsius
    .rawValue

  @AppStorage(SystemTimerHaptics.soundKey) private var sound = true
  @AppStorage(BrewAudio.tickKey) private var tick = true
  @AppStorage(BrewAudio.musicKey) private var music = true
  @AppStorage(AppearanceMode.storageKey) private var appearance = AppearanceMode.system.rawValue
  @State private var showsExperiments = false

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
        Toggle("Brew sounds", isOn: $sound)
          .listRowBackground(DS.paper).accessibilityIdentifier("settings.sound")
        if sound {
          Toggle("Ticking timer", isOn: $tick)
            .listRowBackground(DS.paper).accessibilityIdentifier("settings.sound.tick")
          if !BrewAudio.tracks.isEmpty {
            Toggle("Music while brewing", isOn: $music)
              .listRowBackground(DS.paper).accessibilityIdentifier("settings.sound.music")
          }
        }
      } header: {
        Text("Brewing")
      } footer: {
        Text(
          "Brew sounds play even with the ringer switch off, and music plays at 34% volume. Music stays off while something else is playing."
        )
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
          // Debug and TestFlight only: a long press opens the hidden Experiments screen.
          .contentShape(Rectangle())
          .onLongPressGesture { if Experiments.canOverride { showsExperiments = true } }
          .accessibilityActions {
            if Experiments.canOverride { Button("Experiments") { showsExperiments = true } }
          }
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
    .navigationDestination(isPresented: $showsExperiments) { ExperimentsView() }
    .accessibilityIdentifier("tab.root.settings")
  }
}

/// Plain-language summary of what the app stores and what leaves the device.
struct PrivacySummaryView: View {
  static let policyURL = URL(string: "https://rarecreatures.app/apps/next-cup/privacy/")!
  static let supportURL = URL(string: "https://rarecreatures.app/apps/next-cup/support/")!

  var body: some View {
    List {
      Section {
        row("Your brews, beans, recipes and photos are stored only on this iPhone.")
        row("There is no account, no analytics, no advertising and no server of ours.")
        row("Photos are saved without location or camera metadata.")
        row(
          "With no AI key, AI features use Apple's on-device model where it is available, "
            + "and nothing leaves your iPhone."
        )
        row(
          "With your own OpenAI or Anthropic key, a request goes straight to that provider "
            + "only after you accept its notice and tap."
        )
        row(
          "Roaster search sends your search to Apple Maps, and a barcode scan sends only the "
            + "barcode number to Open Food Facts."
        )
        row(
          "Scanning a QR code on a bag opens its link once to read the coffee's page, "
            + "like a browser would, without cookies."
        )
        row("Export your data or delete all of it under Settings → Your data.")
      }
      Section {
        Link("Read the full privacy policy", destination: Self.policyURL)
          .foregroundStyle(DS.accent)
          .listRowBackground(DS.paper)
          .accessibilityIdentifier("settings.privacy.policy")
        Link("Get help", destination: Self.supportURL)
          .foregroundStyle(DS.accent)
          .listRowBackground(DS.paper)
          .accessibilityIdentifier("settings.privacy.support")
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
