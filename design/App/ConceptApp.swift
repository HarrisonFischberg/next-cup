import SwiftUI

@main
struct ConceptApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-gallery") { Gallery() } else { ConceptRoot() }
        }
    }
}
