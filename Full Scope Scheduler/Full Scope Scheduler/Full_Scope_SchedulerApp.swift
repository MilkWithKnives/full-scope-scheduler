import SwiftUI

@main
struct FullScopeSchedulerApp: App {
    @StateObject private var store = DataStore()
    @AppStorage("appearance") private var appearance: String = "system" // system | light | dark

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(
                    appearance == "light" ? .light :
                    appearance == "dark"  ? .dark  : nil
                )
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Export Schedule as CSV") {
                    store.exportCSV()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        // Native Settings window (App Menu → Settings…)
        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(minWidth: 680, minHeight: 420)
        }
    }
}
