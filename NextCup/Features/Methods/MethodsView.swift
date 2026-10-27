import SwiftData
import SwiftUI

/// S09: brew methods. Add a method, rename it, choose the fields its brew form
/// shows, hide it, and put the list in the order the method picker uses.
/// Reordering is a drag in Edit mode, and also "Move up" / "Move down" in a
/// row's menu, its VoiceOver actions and the editor.
struct MethodsView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dynamicTypeSize) private var dts
  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @State private var target: EditorTarget?
  @State private var error: String?

  var body: some View {
    Group {
      if methods.isEmpty {
        ScrollView {
          EmptyState(
            title: "No methods", message: "Add a method to choose it when you log a brew.",
            actionTitle: "Add a method", action: { target = .new })
        }
      } else {
        list
      }
    }
    .background(DS.bg)
    .navigationTitle("Brew methods")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        if methods.count > 1 { EditButton().accessibilityIdentifier("methods.reorder") }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          target = .new
        } label: {
          Label("Add method", systemImage: "plus")
        }
        .accessibilityIdentifier("methods.add")
      }
    }
    .sheet(item: $target) { target in
      MethodEditorView(target: target, service: service) { self.target = nil }
    }
    .accessibilityIdentifier("methods.screen")
  }

  private var service: MethodsService { MethodsService(store: Store(context: context)) }

  private var list: some View {
    List {
      if let error {
        StateBanner(
          kind: .error, message: error, actionTitle: "Dismiss", action: { self.error = nil }
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(DS.bg)
        .accessibilityIdentifier("methods.error")
      }
      Section {
        ForEach(methods) { method in
          row(method)
        }
        .onMove { source, destination in
          report(service.move(from: source, to: destination))
        }
      }
      Text(
        "Hiding a method removes it from the method picker. Brews logged with it stay in your journal."
      )
      .font(.footnote).foregroundStyle(DS.ink2)
      .listRowBackground(DS.bg).listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .accessibilityIdentifier("methods.list")
  }

  private func row(_ method: BrewMethod) -> some View {
    let position = (methods.firstIndex { $0.id == method.id } ?? 0)
    return Button {
      target = .existing(method.id)
    } label: {
      HStack(spacing: DS.Space.md) {
        // The icon is decoration; at accessibility sizes it would crowd the text.
        if !dts.isAccessibilitySize {
          BrewMedallion(method.glyph, dimmed: method.isHidden).frame(width: 40)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(method.name).font(DS.Font.headline)
            .foregroundStyle(method.isHidden ? DS.ink2 : DS.ink)
          Text(subtitle(method)).font(.footnote).foregroundStyle(DS.ink2)
          if method.isHidden && dts.isAccessibilitySize { hiddenBadge }
        }
        Spacer(minLength: DS.Space.sm)
        if method.isHidden && !dts.isAccessibilitySize { hiddenBadge }
      }
      .frame(minHeight: DS.Size.control, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .listRowBackground(DS.paper)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(method.name), \(subtitle(method))" + (method.isHidden ? ", hidden" : "")
    )
    .accessibilityHint("Opens the method to rename it or change its fields")
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("methods.row.\(method.name)")
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button {
        report(service.setHidden(method, !method.isHidden))
      } label: {
        Label(method.isHidden ? "Show" : "Hide", systemImage: method.isHidden ? "eye" : "eye.slash")
      }
      .tint(DS.steel)
    }
    .contextMenu {
      Button("Rename or edit fields", systemImage: "pencil") { target = .existing(method.id) }
      Button(method.isHidden ? "Show" : "Hide", systemImage: method.isHidden ? "eye" : "eye.slash")
      { report(service.setHidden(method, !method.isHidden)) }
      if position > 0 {
        Button("Move up", systemImage: "arrow.up") { report(service.step(method, by: -1)) }
      }
      if position < methods.count - 1 {
        Button("Move down", systemImage: "arrow.down") { report(service.step(method, by: 1)) }
      }
    }
    .accessibilityAction(named: method.isHidden ? "Show" : "Hide") {
      report(service.setHidden(method, !method.isHidden))
    }
    .accessibilityAction(named: "Move up") { report(service.step(method, by: -1)) }
    .accessibilityAction(named: "Move down") { report(service.step(method, by: 1)) }
  }

  private var hiddenBadge: some View {
    Text("HIDDEN").font(DS.Font.label).foregroundStyle(DS.ink2)
      .padding(.horizontal, DS.Space.sm).padding(.vertical, 2)
      .overlay(Rectangle().strokeBorder(DS.line, lineWidth: DS.rule))
  }

  private func subtitle(_ method: BrewMethod) -> String {
    let fields = MethodParameters.shown(tracked: method.trackedParameters).count
    return "\(method.style.title) · \(fields) fields"
  }

  private func report(_ result: Result<Void, MethodsError>) {
    switch result {
    case .success: error = nil
    case .failure(let failure): error = failure.message
    }
  }
}

/// What the editor sheet is opened for.
enum EditorTarget: Identifiable, Hashable {
  case new
  case existing(UUID)

  var id: String {
    switch self {
    case .new: "new"
    case .existing(let id): id.uuidString
    }
  }
}

/// Adds a method, or renames one and changes which fields its form shows.
struct MethodEditorView: View {
  let target: EditorTarget
  let service: MethodsService
  let close: () -> Void

  @Query(sort: \BrewMethod.sortOrder) private var methods: [BrewMethod]
  @State private var name = ""
  @State private var style = BrewStyle.pourOver
  @State private var chosen = Set(MethodParameters.optional)
  @State private var loaded = false
  @State private var error: String?
  @FocusState private var nameFocused: Bool

  private var method: BrewMethod? {
    guard case .existing(let id) = target else { return nil }
    return methods.first { $0.id == id }
  }

  private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  var body: some View {
    NavigationStack {
      Form {
        if let error {
          StateBanner(kind: .error, message: error)
            .listRowInsets(EdgeInsets()).listRowBackground(DS.bg)
            .accessibilityIdentifier("methods.editor.error")
        }
        Section("Name") {
          TextField("e.g. Moka pot", text: $name)
            .textInputAutocapitalization(.words)
            .submitLabel(.done).focused($nameFocused).onSubmit { nameFocused = false }
            .frame(minHeight: DS.Size.control)
            .accessibilityLabel("Method name")
            .accessibilityIdentifier("methods.editor.name")
        }
        .listRowBackground(DS.paper)
        if method == nil {
          Section("Style") {
            Picker("Style", selection: $style) {
              ForEach(BrewStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .frame(minHeight: DS.Size.control)
            .accessibilityIdentifier("methods.editor.style")
          }
          .listRowBackground(DS.paper)
        }
        Section {
          ForEach(MethodParameters.required, id: \.self) { parameter in
            Toggle(MethodParameters.title(parameter), isOn: .constant(true))
              .disabled(true).frame(minHeight: DS.Size.control)
              .accessibilityValue("On, needed to save a brew")
          }
          ForEach(MethodParameters.optional, id: \.self) { parameter in
            Toggle(
              MethodParameters.title(parameter),
              isOn: Binding(
                get: { chosen.contains(parameter) },
                set: { isOn in
                  if isOn { chosen.insert(parameter) } else { chosen.remove(parameter) }
                })
            )
            .frame(minHeight: DS.Size.control)
            .accessibilityIdentifier("methods.editor.field.\(parameter.rawValue)")
          }
        } header: {
          Text("Fields on the brew form")
        } footer: {
          Text("Dose and water are always shown. Values already saved in a brew are never removed.")
        }
        .listRowBackground(DS.paper)
        if let method {
          position(method)
        }
      }
      .scrollContentBackground(.hidden)
      .background(DS.bg)
      .navigationTitle(method == nil ? "New method" : "Edit method")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: close).accessibilityIdentifier("methods.editor.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save).disabled(!canSave)
            .accessibilityIdentifier("methods.editor.save")
        }
      }
      .task {
        guard !loaded else { return }
        loaded = true
        if let method {
          name = method.name
          style = method.style
          chosen = Set(method.trackedParameters).intersection(MethodParameters.optional)
        }
      }
    }
    .accessibilityIdentifier("methods.editor")
  }

  /// Visible, non-gesture reordering.
  private func position(_ method: BrewMethod) -> some View {
    let index = methods.firstIndex { $0.id == method.id } ?? 0
    return Section {
      Button("Move up", systemImage: "arrow.up") { move(method, by: -1) }
        .disabled(index == 0).frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("methods.editor.up")
      Button("Move down", systemImage: "arrow.down") { move(method, by: 1) }
        .disabled(index >= methods.count - 1).frame(minHeight: DS.Size.control)
        .accessibilityIdentifier("methods.editor.down")
    } header: {
      Text("Position \(index + 1) of \(methods.count)")
    }
    .listRowBackground(DS.paper)
  }

  private func move(_ method: BrewMethod, by offset: Int) {
    if case .failure(let failure) = service.step(method, by: offset) { error = failure.message }
  }

  private func save() {
    let result: Result<Void, MethodsError>
    if let method {
      result = service.update(method, name: name, chosen: chosen)
    } else {
      result = service.add(name: name, style: style, chosen: chosen).map { _ in () }
    }
    switch result {
    case .success: close()
    case .failure(let failure): error = failure.message
    }
  }
}
