import Foundation
import UserNotifications
import Combine

/// Enterprise notification and communication service
@MainActor
class NotificationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var pendingNotifications: [ScheduleNotification] = []
    @Published var notificationHistory: [ScheduleNotification] = []
    @Published var isNotificationEnabled: Bool = false
    @Published var notificationSettings: NotificationSettings = NotificationSettings()
    
    // MARK: - Private Properties
    private let userNotificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // Dependencies
    private weak var dataService: DataService?
    
    override init() {
        super.init()
        userNotificationCenter.delegate = self
        setupNotifications()
    }
    
    func configure(with dataService: DataService) {
        self.dataService = dataService
        observeDataChanges()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await userNotificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .provisional, .criticalAlert]
            )
            
            await updateNotificationStatus()
            return granted
        } catch {
            print("Failed to request notification permissions: \(error)")
            return false
        }
    }
    
    private func updateNotificationStatus() async {
        let settings = await userNotificationCenter.notificationSettings()
        isNotificationEnabled = settings.authorizationStatus == .authorized || 
                                settings.authorizationStatus == .provisional
    }
    
    // MARK: - Schedule Notifications
    
    func scheduleShiftReminder(for assignment: ShiftAssignment, shift: Shift, employee: Employee) {
        guard notificationSettings.shiftReminders else { return }
        
        let reminderTime = shift.startTime.addingTimeInterval(-notificationSettings.reminderMinutesBefore * 60)
        
        guard reminderTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Shift Reminder"
        content.body = "Your shift at \(formatTime(shift.startTime)) starts in \(notificationSettings.reminderMinutesBefore) minutes"
        content.sound = .default
        content.categoryIdentifier = "SHIFT_REMINDER"
        content.userInfo = [
            "type": "shift_reminder",
            "shiftId": shift.id.uuidString,
            "employeeId": employee.id.uuidString
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "shift_reminder_\(assignment.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        userNotificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule shift reminder: \(error)")
            }
        }
        
        // Add to tracking
        let notification = ScheduleNotification(
            id: UUID(),
            type: .shiftReminder,
            title: content.title,
            message: content.body,
            scheduledFor: reminderTime,
            targetEmployees: [employee.id],
            shiftId: shift.id,
            status: .scheduled
        )
        
        pendingNotifications.append(notification)
    }
    
    func notifySchedulePublished(schedule: Schedule, affectedEmployees: [Employee]) {
        guard notificationSettings.scheduleUpdates else { return }
        
        for employee in affectedEmployees {
            let content = UNMutableNotificationContent()
            content.title = "New Schedule Published"
            content.body = "Your schedule for the week of \(formatDate(schedule.weekOf)) has been published"
            content.sound = .default
            content.categoryIdentifier = "SCHEDULE_PUBLISHED"
            content.userInfo = [
                "type": "schedule_published",
                "scheduleId": schedule.id.uuidString,
                "employeeId": employee.id.uuidString
            ]
            
            let request = UNNotificationRequest(
                identifier: "schedule_published_\(schedule.id.uuidString)_\(employee.id.uuidString)",
                content: content,
                trigger: nil
            )
            
            userNotificationCenter.add(request) { error in
                if let error = error {
                    print("Failed to send schedule published notification: \(error)")
                }
            }
        }
        
        // Track notification
        let notification = ScheduleNotification(
            id: UUID(),
            type: .schedulePublished,
            title: "New Schedule Published",
            message: "Schedule for week of \(formatDate(schedule.weekOf)) published",
            scheduledFor: Date(),
            targetEmployees: affectedEmployees.map(\.id),
            scheduleId: schedule.id,
            status: .sent
        )
        
        notificationHistory.append(notification)
    }
    
    func notifyShiftSwapRequest(_ swapRequest: SwapRequest, from fromEmployee: Employee, to toEmployee: Employee?, shift: Shift) {
        guard notificationSettings.swapRequests else { return }
        
        let content = UNMutableNotificationContent()
        
        if let toEmployee = toEmployee {
            // Direct swap request
            content.title = "Shift Swap Request"
            content.body = "\(fromEmployee.personalInfo.displayName) wants to swap their \(formatTime(shift.startTime)) shift with you"
            
            let request = UNNotificationRequest(
                identifier: "swap_request_\(swapRequest.id.uuidString)",
                content: content,
                trigger: nil
            )
            
            userNotificationCenter.add(request)
        } else {
            // Open swap request - notify all eligible employees
            // Implementation would find eligible employees and notify them
        }
        
        // Track notification
        let notification = ScheduleNotification(
            id: UUID(),
            type: .swapRequest,
            title: content.title,
            message: content.body,
            scheduledFor: Date(),
            targetEmployees: [toEmployee?.id].compactMap { $0 },
            shiftId: shift.id,
            swapRequestId: swapRequest.id,
            status: .sent
        )
        
        notificationHistory.append(notification)
    }
    
    func notifyTimeOffRequestUpdate(_ request: TimeOffRequest, status: TimeOffStatus, employee: Employee) {
        let content = UNMutableNotificationContent()
        content.title = "Time Off Request \(status.rawValue.capitalized)"
        content.body = "Your time off request for \(formatDateRange(request.startDate, request.endDate)) has been \(status.rawValue)"
        content.sound = status == .approved ? .default : .defaultCritical
        content.categoryIdentifier = "TIME_OFF_UPDATE"
        
        let request = UNNotificationRequest(
            identifier: "time_off_\(request.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        userNotificationCenter.add(request)
        
        let notification = ScheduleNotification(
            id: UUID(),
            type: .timeOffUpdate,
            title: content.title,
            message: content.body,
            scheduledFor: Date(),
            targetEmployees: [employee.id],
            timeOffRequestId: request.id,
            status: .sent
        )
        
        notificationHistory.append(notification)
    }
    
    // MARK: - Operational Notifications
    
    func notifyUnderstaffedShift(_ shift: Shift, location: Location) {
        guard notificationSettings.operationalAlerts else { return }
        
        // Notify managers and available employees
        let content = UNMutableNotificationContent()
        content.title = "Understaffed Shift Alert"
        content.body = "Shift at \(location.name) on \(formatTime(shift.startTime)) needs additional coverage"
        content.sound = .defaultCritical
        content.categoryIdentifier = "UNDERSTAFFED_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "understaffed_\(shift.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        userNotificationCenter.add(request)
    }
    
    func notifyLateArrival(employee: Employee, shift: Shift, minutesLate: Int) {
        guard notificationSettings.attendanceAlerts else { return }
        
        // Notify managers
        let content = UNMutableNotificationContent()
        content.title = "Late Arrival"
        content.body = "\(employee.personalInfo.displayName) is \(minutesLate) minutes late for their shift"
        content.sound = .default
        content.categoryIdentifier = "LATE_ARRIVAL"
        
        let request = UNNotificationRequest(
            identifier: "late_arrival_\(shift.id.uuidString)_\(employee.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        userNotificationCenter.add(request)
    }
    
    func notifyNoShow(employee: Employee, shift: Shift) {
        guard notificationSettings.attendanceAlerts else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "No Show Alert"
        content.body = "\(employee.personalInfo.displayName) has not checked in for their \(formatTime(shift.startTime)) shift"
        content.sound = .defaultCritical
        content.categoryIdentifier = "NO_SHOW_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "no_show_\(shift.id.uuidString)_\(employee.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        userNotificationCenter.add(request)
    }
    
    // MARK: - Bulk Communications
    
    func sendBulkNotification(
        title: String,
        message: String,
        to employees: [Employee],
        type: NotificationType = .announcement
    ) {
        for employee in employees {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            content.categoryIdentifier = "BULK_NOTIFICATION"
            
            let request = UNNotificationRequest(
                identifier: "bulk_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            userNotificationCenter.add(request)
        }
        
        let notification = ScheduleNotification(
            id: UUID(),
            type: type,
            title: title,
            message: message,
            scheduledFor: Date(),
            targetEmployees: employees.map(\.id),
            status: .sent
        )
        
        notificationHistory.append(notification)
    }
    
    // MARK: - Smart Notifications
    
    func scheduleIntelligentReminders() {
        // AI-powered notification scheduling based on employee preferences and behavior patterns
        Task {
            await generatePersonalizedNotifications()
        }
    }
    
    private func generatePersonalizedNotifications() async {
        // This would analyze employee behavior and preferences to optimize notification timing
        guard let dataService = dataService else { return }
        
        let employees = try? await dataService.fetchEmployees()
        // Implementation would use machine learning to determine optimal notification times
    }
    
    // MARK: - Data Observation
    
    private func observeDataChanges() {
        guard let dataService = dataService else { return }
        
        // Observe schedule changes
        dataService.$schedules
            .sink { [weak self] schedules in
                Task { [weak self] in
                    await self?.handleScheduleChanges(schedules)
                }
            }
            .store(in: &cancellables)
        
        // Observe employee changes
        dataService.$employees
            .sink { [weak self] employees in
                Task { [weak self] in
                    await self?.handleEmployeeChanges(employees)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleScheduleChanges(_ schedules: [Schedule]) async {
        // Auto-generate notifications for schedule changes
        for schedule in schedules where schedule.publishedAt != nil {
            // Check if we've already notified about this schedule
            let alreadyNotified = notificationHistory.contains { notification in
                notification.scheduleId == schedule.id && notification.type == .schedulePublished
            }
            
            if !alreadyNotified {
                // Generate notifications for affected employees
                let employees = try? await dataService?.fetchEmployees()
                if let employees = employees {
                    notifySchedulePublished(schedule: schedule, affectedEmployees: employees)
                }
            }
        }
    }
    
    private func handleEmployeeChanges(_ employees: [Employee]) async {
        // Handle employee-related notifications
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        setupNotificationCategories()
        
        Task {
            await updateNotificationStatus()
        }
    }
    
    private func setupNotificationCategories() {
        let shiftReminderCategory = UNNotificationCategory(
            identifier: "SHIFT_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "CONFIRM_SHIFT",
                    title: "Confirm",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "REQUEST_SWAP",
                    title: "Request Swap",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let swapRequestCategory = UNNotificationCategory(
            identifier: "SWAP_REQUEST",
            actions: [
                UNNotificationAction(
                    identifier: "ACCEPT_SWAP",
                    title: "Accept",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "DECLINE_SWAP",
                    title: "Decline",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        userNotificationCenter.setNotificationCategories([
            shiftReminderCategory,
            swapRequestCategory
        ])
    }
    
    // MARK: - Utility Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateRange(_ startDate: Date, _ endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return formatter.string(from: startDate)
        } else {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "CONFIRM_SHIFT":
            handleShiftConfirmation(userInfo: userInfo)
        case "REQUEST_SWAP":
            handleSwapRequest(userInfo: userInfo)
        case "ACCEPT_SWAP":
            handleSwapAcceptance(userInfo: userInfo)
        case "DECLINE_SWAP":
            handleSwapDecline(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            handleDefaultNotificationTap(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleShiftConfirmation(userInfo: [AnyHashable: Any]) {
        guard let shiftIdString = userInfo["shiftId"] as? String,
              let shiftId = UUID(uuidString: shiftIdString) else { return }
        
        Task {
            // Mark shift as confirmed
            // await dataService?.confirmShift(shiftId)
        }
    }
    
    private func handleSwapRequest(userInfo: [AnyHashable: Any]) {
        // Open swap request interface
    }
    
    private func handleSwapAcceptance(userInfo: [AnyHashable: Any]) {
        // Process swap acceptance
    }
    
    private func handleSwapDecline(userInfo: [AnyHashable: Any]) {
        // Process swap decline
    }
    
    private func handleDefaultNotificationTap(userInfo: [AnyHashable: Any]) {
        // Navigate to relevant screen based on notification type
        if let type = userInfo["type"] as? String {
            switch type {
            case "shift_reminder":
                // Navigate to today's schedule
                break
            case "schedule_published":
                // Navigate to schedule view
                break
            case "swap_request":
                // Navigate to swap requests
                break
            default:
                break
            }
        }
    }
}

// MARK: - Data Models

struct ScheduleNotification: Identifiable, Codable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let scheduledFor: Date
    let sentAt: Date?
    let targetEmployees: [UUID]
    let shiftId: UUID?
    let scheduleId: UUID?
    let swapRequestId: UUID?
    let timeOffRequestId: UUID?
    let status: NotificationStatus
    
    init(
        id: UUID = UUID(),
        type: NotificationType,
        title: String,
        message: String,
        scheduledFor: Date,
        sentAt: Date? = nil,
        targetEmployees: [UUID],
        shiftId: UUID? = nil,
        scheduleId: UUID? = nil,
        swapRequestId: UUID? = nil,
        timeOffRequestId: UUID? = nil,
        status: NotificationStatus
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.scheduledFor = scheduledFor
        self.sentAt = sentAt
        self.targetEmployees = targetEmployees
        self.shiftId = shiftId
        self.scheduleId = scheduleId
        self.swapRequestId = swapRequestId
        self.timeOffRequestId = timeOffRequestId
        self.status = status
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case shiftReminder = "shift_reminder"
    case schedulePublished = "schedule_published"
    case scheduleChanged = "schedule_changed"
    case swapRequest = "swap_request"
    case swapApproved = "swap_approved"
    case swapDeclined = "swap_declined"
    case timeOffUpdate = "time_off_update"
    case operationalAlert = "operational_alert"
    case attendanceAlert = "attendance_alert"
    case announcement = "announcement"
    case systemUpdate = "system_update"
    
    var displayName: String {
        switch self {
        case .shiftReminder: return "Shift Reminder"
        case .schedulePublished: return "Schedule Published"
        case .scheduleChanged: return "Schedule Changed"
        case .swapRequest: return "Swap Request"
        case .swapApproved: return "Swap Approved"
        case .swapDeclined: return "Swap Declined"
        case .timeOffUpdate: return "Time Off Update"
        case .operationalAlert: return "Operational Alert"
        case .attendanceAlert: return "Attendance Alert"
        case .announcement: return "Announcement"
        case .systemUpdate: return "System Update"
        }
    }
    
    var icon: String {
        switch self {
        case .shiftReminder: return "clock.badge"
        case .schedulePublished: return "calendar.badge.plus"
        case .scheduleChanged: return "calendar.badge.exclamationmark"
        case .swapRequest: return "arrow.triangle.swap"
        case .swapApproved: return "checkmark.circle"
        case .swapDeclined: return "xmark.circle"
        case .timeOffUpdate: return "airplane.departure"
        case .operationalAlert: return "exclamationmark.triangle"
        case .attendanceAlert: return "person.badge.clock"
        case .announcement: return "megaphone"
        case .systemUpdate: return "gear.badge"
        }
    }
}

enum NotificationStatus: String, Codable {
    case scheduled = "scheduled"
    case sent = "sent"
    case delivered = "delivered"
    case failed = "failed"
    case cancelled = "cancelled"
}

struct NotificationSettings: Codable {
    var shiftReminders: Bool = true
    var scheduleUpdates: Bool = true
    var swapRequests: Bool = true
    var timeOffUpdates: Bool = true
    var operationalAlerts: Bool = true
    var attendanceAlerts: Bool = true
    var announcements: Bool = true
    
    var reminderMinutesBefore: Double = 30 // Default 30 minutes before shift
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0))! // 10 PM
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))! // 7 AM
    var enableQuietHours: Bool = true
    
    // Advanced settings
    var enableSmartTiming: Bool = true // AI-powered optimal notification timing
    var preferredContactMethod: ContactMethod = .push
    var urgentNotificationsOnly: Bool = false
}

extension ContactMethod {
    case push
}