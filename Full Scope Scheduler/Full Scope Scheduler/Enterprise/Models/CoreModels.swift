import Foundation
import SwiftUI
import CloudKit

// MARK: - Core Domain Models

/// Organization/Company level model for multi-tenancy
struct Organization: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var subscriptionTier: SubscriptionTier
    var settings: OrganizationSettings
    var locations: [Location] = []
    var departments: [Department] = []
    var createdAt: Date = Date()
    var isActive: Bool = true
    
    // Enterprise features
    var maxEmployees: Int { subscriptionTier.maxEmployees }
    var maxLocations: Int { subscriptionTier.maxLocations }
    var hasAdvancedAnalytics: Bool { subscriptionTier.hasAdvancedAnalytics }
}

/// Location/Branch model for multi-location businesses
struct Location: Identifiable, Codable, Hashable {
    let id = UUID()
    var organizationId: UUID
    var name: String
    var address: Address
    var timeZone: TimeZone
    var operatingHours: [Weekday: OperatingHours]
    var departments: [UUID] = [] // Department IDs
    var settings: LocationSettings
    var isActive: Bool = true
    
    // Labor cost settings per location
    var baseLaborRate: Decimal = 15.00
    var overtimeMultiplier: Decimal = 1.5
    var laborBudget: LaborBudget?
}

/// Enhanced Employee model with enterprise features
struct Employee: Identifiable, Codable, Hashable {
    let id = UUID()
    var organizationId: UUID
    var locationIds: [UUID] = [] // Can work at multiple locations
    var departmentIds: [UUID] = []
    
    // Personal Information
    var personalInfo: PersonalInfo
    var contact: ContactInfo
    var emergencyContacts: [EmergencyContact] = []
    
    // Employment Details  
    var employment: EmploymentInfo
    var compensation: CompensationInfo
    var skills: [Skill] = []
    var certifications: [Certification] = []
    
    // Scheduling
    var availability: WeeklyAvailability
    var timeOffRequests: [TimeOffRequest] = []
    var preferences: EmployeePreferences
    
    // Performance & Analytics
    var performanceMetrics: PerformanceMetrics?
    var schedulingHistory: [SchedulingEvent] = []
    
    // System
    var createdAt: Date = Date()
    var isActive: Bool = true
    var lastLoginAt: Date?
}

/// Department/Team organizational structure
struct Department: Identifiable, Codable, Hashable {
    let id = UUID()
    var organizationId: UUID
    var locationId: UUID?
    var name: String
    var description: String
    var color: CodableColor
    var managerId: UUID? // Employee ID of department manager
    var requiredSkills: [Skill] = []
    var laborBudget: LaborBudget?
    var settings: DepartmentSettings
}

/// Advanced shift model with enterprise features
struct Shift: Identifiable, Codable, Hashable {
    let id = UUID()
    var organizationId: UUID
    var locationId: UUID
    var departmentId: UUID?
    
    // Timing
    var startTime: Date
    var endTime: Date
    var isRecurring: Bool = false
    var recurrenceRule: RecurrenceRule?
    
    // Staffing
    var requiredSkills: [Skill] = []
    var assignedEmployees: [ShiftAssignment] = []
    var requiredStaffCount: Int = 1
    var priority: ShiftPriority = .normal
    
    // Business Logic
    var role: String?
    var notes: String = ""
    var laborCost: LaborCost?
    var status: ShiftStatus = .published
    
    // Compliance & Tracking
    var createdBy: UUID // Employee ID
    var createdAt: Date = Date()
    var lastModifiedBy: UUID?
    var lastModifiedAt: Date?
    var publishedAt: Date?
    
    // AI Optimization Data
    var difficultyScore: Double = 0.5 // 0-1, used for AI scheduling
    var historicalPerformance: ShiftPerformanceData?
}

/// Shift assignment linking employees to shifts
struct ShiftAssignment: Identifiable, Codable, Hashable {
    let id = UUID()
    var shiftId: UUID
    var employeeId: UUID
    var status: AssignmentStatus = .assigned
    var confirmedAt: Date?
    var swapRequests: [SwapRequest] = []
    var actualStartTime: Date?
    var actualEndTime: Date?
    var performanceRating: Double?
}

// MARK: - Supporting Models

struct PersonalInfo: Codable, Hashable {
    var firstName: String
    var lastName: String
    var preferredName: String?
    var dateOfBirth: Date?
    var profilePhoto: String? // URL or asset name
    
    var displayName: String {
        preferredName ?? "\(firstName) \(lastName)"
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct ContactInfo: Codable, Hashable {
    var email: String
    var phone: String?
    var address: Address?
    var preferredContactMethod: ContactMethod = .email
}

struct EmergencyContact: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var relationship: String
    var phone: String
    var email: String?
}

struct Address: Codable, Hashable {
    var street: String
    var city: String
    var state: String
    var zipCode: String
    var country: String = "US"
    
    var formatted: String {
        "\(street), \(city), \(state) \(zipCode)"
    }
}

struct EmploymentInfo: Codable, Hashable {
    var employeeNumber: String?
    var hireDate: Date
    var status: EmploymentStatus = .active
    var employmentType: EmploymentType = .partTime
    var jobTitle: String
    var reports_to: UUID? // Manager's employee ID
}

struct CompensationInfo: Codable, Hashable {
    var hourlyRate: Decimal
    var overtimeRate: Decimal?
    var currency: String = "USD"
    var paySchedule: PaySchedule = .biweekly
    var maxHoursPerWeek: Int = 40
    var maxHoursPerDay: Int = 8
}

struct Skill: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var description: String
    var category: SkillCategory
    var proficiencyLevel: ProficiencyLevel = .beginner
    var isRequired: Bool = false
    var certificationRequired: Bool = false
}

struct Certification: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var issuedBy: String
    var issuedDate: Date
    var expiryDate: Date?
    var certificateUrl: String?
    
    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }
    
    var isExpiringSoon: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date().addingTimeInterval(30 * 24 * 3600) // 30 days
    }
}

// MARK: - Enums

enum SubscriptionTier: String, Codable, CaseIterable {
    case starter = "starter"
    case professional = "professional"
    case enterprise = "enterprise"
    
    var displayName: String {
        switch self {
        case .starter: return "Starter"
        case .professional: return "Professional"
        case .enterprise: return "Enterprise"
        }
    }
    
    var maxEmployees: Int {
        switch self {
        case .starter: return 25
        case .professional: return 100
        case .enterprise: return .max
        }
    }
    
    var maxLocations: Int {
        switch self {
        case .starter: return 1
        case .professional: return 5
        case .enterprise: return .max
        }
    }
    
    var hasAdvancedAnalytics: Bool {
        switch self {
        case .starter: return false
        case .professional: return true
        case .enterprise: return true
        }
    }
    
    var monthlyPrice: Decimal {
        switch self {
        case .starter: return 29.99
        case .professional: return 99.99
        case .enterprise: return 299.99
        }
    }
}

enum ShiftStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case published = "published"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .published: return "Published"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .orange
        case .published: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

enum AssignmentStatus: String, Codable, CaseIterable {
    case assigned = "assigned"
    case confirmed = "confirmed"
    case declined = "declined"
    case swapRequested = "swap_requested"
    case noShow = "no_show"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .assigned: return "Assigned"
        case .confirmed: return "Confirmed"
        case .declined: return "Declined"  
        case .swapRequested: return "Swap Requested"
        case .noShow: return "No Show"
        case .completed: return "Completed"
        }
    }
}

enum ShiftPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum EmploymentStatus: String, Codable, CaseIterable {
    case active = "active"
    case inactive = "inactive"
    case terminated = "terminated"
    case onLeave = "on_leave"
}

enum EmploymentType: String, Codable, CaseIterable {
    case fullTime = "full_time"
    case partTime = "part_time"
    case contract = "contract"
    case intern = "intern"
    
    var displayName: String {
        switch self {
        case .fullTime: return "Full Time"
        case .partTime: return "Part Time"
        case .contract: return "Contract"
        case .intern: return "Intern"
        }
    }
}

enum ContactMethod: String, Codable, CaseIterable {
    case email = "email"
    case sms = "sms"
    case phone = "phone"
    case push = "push"
}

enum PaySchedule: String, Codable, CaseIterable {
    case weekly = "weekly"
    case biweekly = "biweekly"
    case semiMonthly = "semi_monthly"
    case monthly = "monthly"
}

enum SkillCategory: String, Codable, CaseIterable {
    case technical = "technical"
    case customer_service = "customer_service"
    case management = "management"
    case safety = "safety"
    case specialized = "specialized"
    
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

enum ProficiencyLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var score: Double {
        switch self {
        case .beginner: return 0.25
        case .intermediate: return 0.5
        case .advanced: return 0.75
        case .expert: return 1.0
        }
    }
}

// MARK: - Helper Types for SwiftUI

struct CodableColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1.0
    
    init(_ color: Color) {
        // This is a simplified approach - in production you'd use UIColor/NSColor
        self.red = 0.5
        self.green = 0.5 
        self.blue = 0.5
        self.alpha = 1.0
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Advanced Models (to be implemented in separate files)

struct WeeklyAvailability: Codable, Hashable {
    var patterns: [Weekday: [AvailabilityWindow]] = [:]
    var blackoutDates: [Date] = []
    var preferredHours: PreferredHours?
}

struct AvailabilityWindow: Codable, Hashable {
    var startTime: TimeComponents
    var endTime: TimeComponents
    var isPreferred: Bool = false
}

struct TimeComponents: Codable, Hashable {
    var hour: Int
    var minute: Int
    
    var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}

struct PreferredHours: Codable, Hashable {
    var minHoursPerWeek: Int?
    var maxHoursPerWeek: Int?
    var preferredDaysOff: [Weekday] = []
    var maxConsecutiveDays: Int = 6
}

// Placeholder structs for complex models
struct OrganizationSettings: Codable, Hashable {
    var timeZone: String = "America/New_York"
    var weekStartsOn: Weekday = .monday
    var fiscalYearStart: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1))!
}

struct LocationSettings: Codable, Hashable {
    var autoApproveSwaps: Bool = false
    var requireShiftConfirmation: Bool = true
    var sendReminders: Bool = true
}

struct DepartmentSettings: Codable, Hashable {
    var allowSelfScheduling: Bool = false
    var requireManagerApproval: Bool = true
}

struct EmployeePreferences: Codable, Hashable {
    var notificationPreferences: NotificationPreferences = NotificationPreferences()
    var workPreferences: WorkPreferences = WorkPreferences()
}

struct NotificationPreferences: Codable, Hashable {
    var scheduleUpdates: Bool = true
    var shiftReminders: Bool = true
    var swapRequests: Bool = true
}

struct WorkPreferences: Codable, Hashable {
    var preferredShiftLength: Int = 8
    var preferredStartTime: TimeComponents?
    var willingToTravel: Bool = false
}

struct OperatingHours: Codable, Hashable {
    var open: TimeComponents
    var close: TimeComponents
    var isClosed: Bool = false
}

struct LaborBudget: Codable, Hashable {
    var weeklyBudget: Decimal
    var dailyBudget: Decimal
    var currency: String = "USD"
}

struct LaborCost: Codable, Hashable {
    var estimatedCost: Decimal
    var actualCost: Decimal?
    var currency: String = "USD"
}

struct PerformanceMetrics: Codable, Hashable {
    var attendanceRate: Double = 1.0
    var punctualityScore: Double = 1.0
    var overallRating: Double = 5.0
}

struct SchedulingEvent: Codable, Hashable {
    var eventType: String
    var timestamp: Date
    var details: [String: String] = [:]
}

struct RecurrenceRule: Codable, Hashable {
    var frequency: RecurrenceFrequency
    var interval: Int = 1
    var endDate: Date?
    var occurrences: Int?
}

enum RecurrenceFrequency: String, Codable {
    case daily, weekly, monthly
}

struct ShiftPerformanceData: Codable, Hashable {
    var averageRating: Double
    var completionRate: Double
    var noShowRate: Double
}

struct TimeOffRequest: Identifiable, Codable, Hashable {
    let id = UUID()
    var employeeId: UUID
    var startDate: Date
    var endDate: Date
    var reason: String
    var status: TimeOffStatus = .pending
    var approvedBy: UUID?
}

enum TimeOffStatus: String, Codable {
    case pending, approved, denied
}

struct SwapRequest: Identifiable, Codable, Hashable {
    let id = UUID()
    var fromEmployeeId: UUID
    var toEmployeeId: UUID?
    var shiftId: UUID
    var reason: String
    var status: SwapStatus = .pending
    var createdAt: Date = Date()
}

enum SwapStatus: String, Codable {
    case pending, approved, denied, cancelled
}

enum Weekday: Int, CaseIterable, Codable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var label: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday" 
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue" 
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}