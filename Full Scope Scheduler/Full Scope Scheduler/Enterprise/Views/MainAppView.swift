import SwiftUI

/// Main application interface following Apple's latest design guidelines
struct MainAppView: View {
    @StateObject private var dataService = DataService()
    @StateObject private var navigationModel = NavigationModel()
    @StateObject private var notificationCenter = NotificationCenter()
    
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var showingOnboarding = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(
                selectedItem: $selectedSidebarItem,
                dataService: dataService
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
        } detail: {
            // Main content area
            DetailContentView(
                selectedItem: selectedSidebarItem,
                dataService: dataService,
                navigationModel: navigationModel
            )
        }
        .environmentObject(dataService)
        .environmentObject(navigationModel)
        .environmentObject(notificationCenter)
        .onAppear {
            Task {
                await initializeApp()
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingFlow(dataService: dataService)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(dataService)
        }
        .overlay {
            if dataService.isLoading {
                LoadingOverlay()
            }
        }
        .alert("Error", isPresented: .constant(dataService.error != nil)) {
            Button("OK") {
                dataService.error = nil
            }
        } message: {
            Text(dataService.error?.localizedDescription ?? "Unknown error occurred")
        }
    }
    
    private func initializeApp() async {
        do {
            let user = try await dataService.authenticateUser()
            
            if user == nil || dataService.currentOrganization == nil {
                showingOnboarding = true
            } else {
                // Load initial data
                async let employees = dataService.fetchEmployees()
                async let locations = dataService.fetchLocations()
                
                _ = try await (employees, locations)
            }
        } catch {
            showingOnboarding = true
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @ObservedObject var dataService: DataService
    
    var body: some View {
        List(selection: $selectedItem) {
            // Dashboard Section
            Section("Overview") {
                SidebarRow(
                    item: .dashboard,
                    icon: "chart.bar.doc.horizontal",
                    title: "Dashboard",
                    isSelected: selectedItem == .dashboard
                )
                
                SidebarRow(
                    item: .analytics,
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Analytics",
                    isSelected: selectedItem == .analytics
                )
            }
            
            // Scheduling Section
            Section("Scheduling") {
                SidebarRow(
                    item: .schedule,
                    icon: "calendar",
                    title: "Schedule",
                    isSelected: selectedItem == .schedule
                )
                
                SidebarRow(
                    item: .shifts,
                    icon: "clock.badge.checkmark",
                    title: "Shifts",
                    isSelected: selectedItem == .shifts
                )
                
                SidebarRow(
                    item: .timeOff,
                    icon: "airplane.departure",
                    title: "Time Off",
                    isSelected: selectedItem == .timeOff
                )
            }
            
            // People Section
            Section("People") {
                SidebarRow(
                    item: .employees,
                    icon: "person.3",
                    title: "Employees",
                    badge: "\(dataService.employees.count)",
                    isSelected: selectedItem == .employees
                )
                
                SidebarRow(
                    item: .departments,
                    icon: "building.2",
                    title: "Departments",
                    isSelected: selectedItem == .departments
                )
            }
            
            // Organization Section
            Section("Organization") {
                ForEach(dataService.locations, id: \.id) { location in
                    SidebarRow(
                        item: .location(location.id),
                        icon: "building.2.crop.circle",
                        title: location.name,
                        isSelected: selectedItem == .location(location.id)
                    )
                }
                
                SidebarRow(
                    item: .settings,
                    icon: "gearshape",
                    title: "Settings",
                    isSelected: selectedItem == .settings
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SchedulePro")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add Location", systemImage: "plus.circle") {
                        // Show add location sheet
                    }
                    
                    Button("Invite Employee", systemImage: "person.badge.plus") {
                        // Show invite employee sheet
                    }
                    
                    Divider()
                    
                    Button("Generate Schedule", systemImage: "sparkles") {
                        // Show schedule generation
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
            }
        }
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let icon: String
    let title: String
    let badge: String?
    let isSelected: Bool
    
    init(item: SidebarItem, icon: String, title: String, badge: String? = nil, isSelected: Bool) {
        self.item = item
        self.icon = icon
        self.title = title
        self.badge = badge
        self.isSelected = isSelected
    }
    
    var body: some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                if let badge = badge {
                    BadgeView(text: badge)
                }
            }
        } icon: {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
        }
        .tag(item)
    }
}

// MARK: - Detail Content

struct DetailContentView: View {
    let selectedItem: SidebarItem
    @ObservedObject var dataService: DataService
    @ObservedObject var navigationModel: NavigationModel
    
    var body: some View {
        Group {
            switch selectedItem {
            case .dashboard:
                DashboardView()
            case .analytics:
                AnalyticsView()
            case .schedule:
                ScheduleView()
            case .shifts:
                ShiftsManagementView()
            case .timeOff:
                TimeOffView()
            case .employees:
                EmployeesView()
            case .departments:
                DepartmentsView()
            case .location(let locationId):
                LocationDetailView(locationId: locationId)
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var dataService: DataService
    @State private var selectedMetricsPeriod: MetricsPeriod = .thisWeek
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Header with metrics period selector
                HStack {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Picker("Period", selection: $selectedMetricsPeriod) {
                        ForEach(MetricsPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }
                .padding(.horizontal)
                
                // Key Metrics Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MetricCard(
                        title: "Total Employees",
                        value: "\(dataService.employees.count)",
                        icon: "person.3.fill",
                        color: .blue,
                        trend: .up(8)
                    )
                    
                    MetricCard(
                        title: "Active Shifts",
                        value: "247",
                        icon: "clock.fill",
                        color: .green,
                        trend: .up(12)
                    )
                    
                    MetricCard(
                        title: "Labor Cost",
                        value: "$12,450",
                        icon: "dollarsign.circle.fill",
                        color: .orange,
                        trend: .down(5)
                    )
                    
                    MetricCard(
                        title: "Attendance Rate",
                        value: "94.2%",
                        icon: "checkmark.circle.fill",
                        color: .purple,
                        trend: .up(2)
                    )
                }
                .padding(.horizontal)
                
                // Recent Activity and Quick Actions
                HStack(alignment: .top, spacing: 20) {
                    // Recent Activity
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Activity")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        ActivityFeedView()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        QuickActionsView()
                    }
                    .frame(width: 300)
                }
                .padding(.horizontal)
                
                // Schedule Overview
                VStack(alignment: .leading, spacing: 16) {
                    Text("This Week's Schedule")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    WeeklyScheduleOverview()
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Trend?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Spacer()
                
                if let trend = trend {
                    TrendIndicator(trend: trend)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

struct TrendIndicator: View {
    let trend: Trend
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trend.icon)
                .font(.caption2)
                .fontWeight(.semibold)
            
            Text(trend.displayValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(trend.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(trend.color.opacity(0.1), in: Capsule())
    }
}

struct BadgeView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue, in: Capsule())
    }
}

struct ActivityFeedView: View {
    let activities = [
        Activity(icon: "person.badge.plus", title: "New employee added", subtitle: "Sarah Johnson joined Marketing", time: "2m ago", color: .green),
        Activity(icon: "calendar.badge.clock", title: "Schedule published", subtitle: "Week of Jan 15-21", time: "15m ago", color: .blue),
        Activity(icon: "arrow.triangle.2.circlepath", title: "Shift swap approved", title: "Mike → Jessica, Friday 3pm", time: "1h ago", color: .orange),
        Activity(icon: "exclamationmark.triangle", title: "Coverage alert", subtitle: "Saturday morning understaffed", time: "2h ago", color: .red)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(activities, id: \.title) { activity in
                HStack(spacing: 12) {
                    Image(systemName: activity.icon)
                        .font(.caption)
                        .foregroundStyle(activity.color)
                        .frame(width: 24, height: 24)
                        .background(activity.color.opacity(0.1), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(activity.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(activity.time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            QuickActionButton(
                icon: "sparkles",
                title: "Generate Schedule",
                subtitle: "AI-powered optimization",
                color: .purple
            )
            
            QuickActionButton(
                icon: "person.badge.plus",
                title: "Add Employee",
                subtitle: "Onboard new team member",
                color: .blue
            )
            
            QuickActionButton(
                icon: "calendar.badge.plus",
                title: "Create Shift",
                subtitle: "Quick shift creation",
                color: .green
            )
            
            QuickActionButton(
                icon: "chart.bar.doc.horizontal",
                title: "View Reports",
                subtitle: "Labor cost & performance",
                color: .orange
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        Button {
            // Handle action
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct WeeklyScheduleOverview: View {
    var body: some View {
        // Implementation for weekly schedule overview
        RoundedRectangle(cornerRadius: 12)
            .fill(.regularMaterial)
            .frame(height: 200)
            .overlay {
                Text("Weekly Schedule Overview")
                    .foregroundStyle(.secondary)
            }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Supporting Types

enum SidebarItem: Hashable {
    case dashboard
    case analytics
    case schedule
    case shifts
    case timeOff
    case employees
    case departments
    case location(UUID)
    case settings
}

enum MetricsPeriod: CaseIterable {
    case today, thisWeek, thisMonth, lastMonth
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        }
    }
}

enum Trend {
    case up(Int)
    case down(Int)
    case neutral
    
    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .neutral: return .gray
        }
    }
    
    var displayValue: String {
        switch self {
        case .up(let value): return "+\(value)%"
        case .down(let value): return "-\(value)%"
        case .neutral: return "0%"
        }
    }
}

struct Activity {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
}

@MainActor
class NavigationModel: ObservableObject {
    @Published var selectedTab: String = "dashboard"
    @Published var navigationPath = NavigationPath()
    
    func navigate(to destination: String) {
        navigationPath.append(destination)
    }
}

// Placeholder views for other sections
struct AnalyticsView: View {
    var body: some View {
        Text("Analytics View")
            .font(.title)
    }
}

struct ScheduleView: View {
    var body: some View {
        Text("Schedule View")
            .font(.title)
    }
}

struct ShiftsManagementView: View {
    var body: some View {
        Text("Shifts Management View")
            .font(.title)
    }
}

struct TimeOffView: View {
    var body: some View {
        Text("Time Off View")
            .font(.title)
    }
}

struct EmployeesView: View {
    var body: some View {
        Text("Employees View")
            .font(.title)
    }
}

struct DepartmentsView: View {
    var body: some View {
        Text("Departments View")
            .font(.title)
    }
}

struct LocationDetailView: View {
    let locationId: UUID
    
    var body: some View {
        Text("Location Detail View")
            .font(.title)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings View")
            .font(.title)
    }
}

struct OnboardingFlow: View {
    @ObservedObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to SchedulePro")
                    .font(.title)
                
                Text("Enterprise workforce management made simple")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Button("Get Started") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

class NotificationCenter: ObservableObject {
    // Notification center implementation
}