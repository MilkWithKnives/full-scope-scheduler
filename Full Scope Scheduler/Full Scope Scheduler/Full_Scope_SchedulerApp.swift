import SwiftUI

@main
struct FullScopeSchedulerApp: App {
    @StateObject private var dataService = DataService()
    @StateObject private var legacyStore = DataStore() // Keep for backwards compatibility
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("useEnterpriseFeatures") private var useEnterpriseFeatures: Bool = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if useEnterpriseFeatures {
                    // New Enterprise Interface
                    MainAppView()
                        .environmentObject(dataService)
                } else {
                    // Legacy Interface (for migration)
                    ContentView()
                        .environmentObject(legacyStore)
                }
            }
            .preferredColorScheme(
                appearance == "light" ? .light :
                appearance == "dark"  ? .dark  : nil
            )
        }
        .commands {
            CommandGroup(after: .newItem) {
                if useEnterpriseFeatures {
                    // Enterprise commands
                    Button("Generate AI Schedule") {
                        Task {
                            await generateAISchedule()
                        }
                    }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    
                    Button("Export Reports") {
                        exportEnterpriseReports()
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    
                    Divider()
                    
                    Button("Invite Employee") {
                        showInviteEmployee()
                    }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                    
                    Button("Add Location") {
                        showAddLocation()
                    }
                    .keyboardShortcut("l", modifiers: [.command, .option])
                } else {
                    // Legacy commands
                    Button("Export Schedule as CSV") {
                        legacyStore.exportCSV()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                }
                
                Divider()
                
                Button("Toggle Enterprise Features") {
                    useEnterpriseFeatures.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .control])
            }
            
            // Help Menu
            CommandGroup(replacing: .help) {
                Button("SchedulePro Help") {
                    openHelp()
                }
                
                Button("Video Tutorials") {
                    openVideoTutorials()
                }
                
                Button("Contact Support") {
                    openSupport()
                }
                
                Divider()
                
                Button("Feature Request") {
                    openFeatureRequest()
                }
                
                Button("Report Bug") {
                    openBugReport()
                }
            }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)

        // Settings window
        Settings {
            if useEnterpriseFeatures {
                EnterpriseSettingsView()
                    .environmentObject(dataService)
                    .frame(minWidth: 800, minHeight: 600)
            } else {
                LegacySettingsView()
                    .environmentObject(legacyStore)
                    .frame(minWidth: 680, minHeight: 420)
            }
        }
        
        // Additional windows for enterprise features
        if useEnterpriseFeatures {
            WindowGroup("Analytics Dashboard", id: "analytics") {
                AnalyticsDashboardWindow()
                    .environmentObject(dataService)
            }
            .windowStyle(.automatic)
            .defaultSize(width: 1200, height: 800)
            
            WindowGroup("Employee Details", id: "employee-detail") {
                EmployeeDetailWindow()
                    .environmentObject(dataService)
            }
            .windowStyle(.automatic)
            .defaultSize(width: 600, height: 800)
        }
    }
    
    // MARK: - Command Handlers
    
    private func generateAISchedule() async {
        // Implementation for AI schedule generation
        print("Generating AI-optimized schedule...")
    }
    
    private func exportEnterpriseReports() {
        // Implementation for enterprise report export
        print("Exporting enterprise reports...")
    }
    
    private func showInviteEmployee() {
        // Implementation for showing invite employee dialog
        print("Showing invite employee...")
    }
    
    private func showAddLocation() {
        // Implementation for showing add location dialog
        print("Showing add location...")
    }
    
    private func openHelp() {
        if let url = URL(string: "https://schedulepro.app/help") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openVideoTutorials() {
        if let url = URL(string: "https://schedulepro.app/tutorials") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openSupport() {
        if let url = URL(string: "https://schedulepro.app/support") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openFeatureRequest() {
        if let url = URL(string: "https://schedulepro.app/feature-request") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openBugReport() {
        if let url = URL(string: "https://schedulepro.app/bug-report") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct EnterpriseSettingsView: View {
    @EnvironmentObject var dataService: DataService
    
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            
            OrganizationSettingsTab()
                .tabItem { Label("Organization", systemImage: "building.2") }
            
            SecuritySettingsTab()
                .tabItem { Label("Security", systemImage: "lock.shield") }
            
            IntegrationsSettingsTab()
                .tabItem { Label("Integrations", systemImage: "arrow.triangle.branch") }
            
            BillingSettingsTab()
                .tabItem { Label("Billing", systemImage: "creditcard") }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct LegacySettingsView: View {
    @EnvironmentObject var store: DataStore
    
    var body: some View {
        SettingsView()
            .environmentObject(store)
    }
}

struct AnalyticsDashboardWindow: View {
    @EnvironmentObject var dataService: DataService
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Analytics Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Advanced workforce analytics and insights")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Analytics")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        }
    }
}

struct EmployeeDetailWindow: View {
    @EnvironmentObject var dataService: DataService
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Employee Details")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Comprehensive employee information and performance")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Employee")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        }
    }
}

// Settings tab implementations
struct GeneralSettingsTab: View {
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("language") private var language: String = "en"
    @AppStorage("useEnterpriseFeatures") private var useEnterpriseFeatures: Bool = true
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            
            Section("Features") {
                Toggle("Enable Enterprise Features", isOn: $useEnterpriseFeatures)
                    .help("Enables advanced scheduling, analytics, and multi-tenant features")
            }
            
            Section("Language") {
                Picker("Language", selection: $language) {
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

struct OrganizationSettingsTab: View {
    var body: some View {
        Form {
            Section("Organization Info") {
                TextField("Organization Name", text: .constant("Acme Corp"))
                TextField("Industry", text: .constant("Retail"))
                TextField("Time Zone", text: .constant("America/New_York"))
            }
            
            Section("Locations") {
                Text("Manage your business locations")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Organization")
    }
}

struct SecuritySettingsTab: View {
    var body: some View {
        Form {
            Section("Access Control") {
                Toggle("Two-Factor Authentication", isOn: .constant(true))
                Toggle("Single Sign-On (SSO)", isOn: .constant(false))
            }
            
            Section("Data & Privacy") {
                Toggle("Data Encryption", isOn: .constant(true))
                Toggle("Audit Logging", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Security")
    }
}

struct IntegrationsSettingsTab: View {
    var body: some View {
        Form {
            Section("Payroll Integration") {
                Text("Connect with payroll systems")
                    .foregroundStyle(.secondary)
            }
            
            Section("Communication") {
                Toggle("Slack Integration", isOn: .constant(false))
                Toggle("Microsoft Teams", isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Integrations")
    }
}

struct BillingSettingsTab: View {
    var body: some View {
        Form {
            Section("Subscription") {
                HStack {
                    Text("Current Plan")
                    Spacer()
                    Text("Enterprise")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Monthly Cost")
                    Spacer()
                    Text("$299.99")
                        .fontWeight(.semibold)
                }
            }
            
            Section("Usage") {
                HStack {
                    Text("Employees")
                    Spacer()
                    Text("87 / ∞")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Locations")
                    Spacer()
                    Text("3 / ∞")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Billing")
    }
}
