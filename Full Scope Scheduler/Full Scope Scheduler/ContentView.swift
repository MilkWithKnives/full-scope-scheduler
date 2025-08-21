import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            EmployeesView()
                .tabItem { Label("Employees", systemImage: "person.3") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .frame(minWidth: 980, minHeight: 620)
    }
}

