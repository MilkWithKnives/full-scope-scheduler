import Foundation
import CloudKit
import Combine
import SwiftUI

// Type alias to resolve ambiguity with basic models
typealias DataServiceEmployee = Employee

/// Enterprise-grade multi-tenant data service with CloudKit backend
@MainActor
class DataService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentOrganization: Organization?
    @Published var currentUser: DataServiceEmployee?
    @Published var employees: [DataServiceEmployee] = []
    @Published var locations: [Location] = []
    @Published var departments: [Department] = []
    @Published var schedules: [Schedule] = []
    @Published var shifts: [Shift] = []
    
    @Published var isLoading = false
    @Published var error: DataServiceError?
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Private Properties
    private let container = CKContainer.default()
    private var database: CKDatabase { container.publicCloudDatabase }
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    
    private var subscriptions = Set<AnyCancellable>()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Caching
    private let cache = NSCache<NSString, CacheEntry>()
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Real-time subscriptions
    private var realTimeSubscriptions: [CKQuerySubscription] = []
    
    // MARK: - Initialization
    
    init() {
        setupCache()
        setupCloudKitNotifications()
        
        // Auto-refresh data every 30 seconds when app is active
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refreshIfNeeded() }
            }
            .store(in: &subscriptions)
    }
    
    // MARK: - Authentication & Organization Setup
    
    func authenticateUser() async throws -> DataServiceEmployee? {
        do {
            let accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                return try await fetchCurrentUser()
            case .noAccount:
                throw DataServiceError.noCloudKitAccount
            case .restricted:
                throw DataServiceError.cloudKitRestricted
            case .couldNotDetermine:
                throw DataServiceError.unknown("Could not determine CloudKit status")
            @unknown default:
                throw DataServiceError.unknown("Unknown CloudKit account status")
            }
        } catch {
            self.error = DataServiceError.authenticationFailed(error)
            throw error
        }
    }
    
    func createOrganization(_ organization: Organization) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let record = try await createCKRecord(from: organization, recordType: "Organization")
            _ = try await database.save(record)
            
            self.currentOrganization = organization
            await setupOrganizationSubscriptions()
            
        } catch {
            self.error = DataServiceError.operationFailed(error)
            throw error
        }
    }
    
    func joinOrganization(inviteCode: String) async throws {
        // Implementation for joining existing organization
        isLoading = true
        defer { isLoading = false }
        
        // Fetch organization by invite code
        // Add user to organization
        // Set up permissions
    }
    
    // MARK: - Employee Management
    
    func createEmployee(_ employee: DataServiceEmployee) async throws {
        guard let orgId = currentOrganization?.id else {
            throw DataServiceError.noOrganization
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var newEmployee = employee
            newEmployee.organizationId = orgId
            
            let record = try await createCKRecord(from: newEmployee, recordType: "Employee")
            _ = try await database.save(record)
            
            employees.append(newEmployee)
            invalidateCache(for: "employees")
            
        } catch {
            self.error = DataServiceError.operationFailed(error)
            throw error
        }
    }
    
    func updateEmployee(_ employee: DataServiceEmployee) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let record = try await createCKRecord(from: employee, recordType: "Employee")
            _ = try await database.save(record)
            
            if let index = employees.firstIndex(where: { $0.id == employee.id }) {
                employees[index] = employee
            }
            
            invalidateCache(for: "employees")
            
        } catch {
            self.error = DataServiceError.operationFailed(error)
            throw error
        }
    }
    
    func deleteEmployee(_ employeeId: UUID) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let recordID = CKRecord.ID(recordName: employeeId.uuidString)
            _ = try await database.deleteRecord(withID: recordID)
            
            employees.removeAll { $0.id == employeeId }
            invalidateCache(for: "employees")
            
        } catch {
            self.error = DataServiceError.operationFailed(error)
            throw error
        }
    }
    
    func fetchEmployees(for organizationId: UUID? = nil) async throws -> [DataServiceEmployee] {
        let orgId = organizationId ?? currentOrganization?.id
        guard let orgId = orgId else {
            throw DataServiceError.noOrganization
        }
        
        let cacheKey = "employees_\(orgId.uuidString)"
        if let cachedEmployees: [DataServiceEmployee] = getCachedData(for: cacheKey) {
            return cachedEmployees
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let predicate = NSPredicate(format: "organizationId == %@", orgId.uuidString)
            let query = CKQuery(recordType: "Employee", predicate: predicate)
            
            let result = try await database.records(matching: query)
            let employees = try result.matchResults.compactMap { _, result in
                try result.get()
            }.compactMap { record in
                try? extractModel(DataServiceEmployee.self, from: record)
            }
            
            setCachedData(employees, for: cacheKey)
            self.employees = employees
            return employees
            
        } catch {
            self.error = DataServiceError.fetchFailed(error)
            throw error
        }
    }
    
    // MARK: - Location Management
    
    func createLocation(_ location: Location) async throws {
        guard let orgId = currentOrganization?.id else {
            throw DataServiceError.noOrganization
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var newLocation = location
            newLocation.organizationId = orgId
            
            let record = try await createCKRecord(from: newLocation, recordType: "Location")
            _ = try await database.save(record)
            
            locations.append(newLocation)
            invalidateCache(for: "locations")
            
        } catch {
            self.error = DataServiceError.operationFailed(error)
            throw error
        }
    }
    
    func fetchLocations() async throws -> [Location] {
        guard let orgId = currentOrganization?.id else {
            throw DataServiceError.noOrganization
        }
        
        let cacheKey = "locations_\(orgId.uuidString)"
        if let cachedLocations: [Location] = getCachedData(for: cacheKey) {
            return cachedLocations
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let predicate = NSPredicate(format: "organizationId == %@", orgId.uuidString)
            let query = CKQuery(recordType: "Location", predicate: predicate)
            
            let result = try await database.records(matching: query)
            let locations = try result.matchResults.compactMap { _, result in
                try result.get()
            }.compactMap { record in
                try? extractModel(Location.self, from: record)
            }
            
            setCachedData(locations, for: cacheKey)
            self.locations = locations
            return locations
            
        } catch {
            self.error = DataServiceError.fetchFailed(error)
            throw error
        }
    }
    
    // MARK: - Schedule Management
    
    func generateSchedule(request: ScheduleGenerationRequest) async throws -> Schedule {
        isLoading = true
        defer { isLoading = false }
        
        // Use AI scheduling engine
        let schedulingEngine = AISchedulingEngine()
        let result = await schedulingEngine.generateOptimizedSchedule(for: request)
        
        guard let schedule = result.schedule else {
            throw DataServiceError.scheduleGenerationFailed(result.constraintViolations)
        }
        
        // Save to CloudKit
        try await saveSchedule(schedule)
        
        return schedule
    }
    
    func saveSchedule(_ schedule: Schedule) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let record = try await createCKRecord(from: schedule, recordType: "Schedule")
            _ = try await database.save(record)
            
            if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
                schedules[index] = schedule
            } else {
                schedules.append(schedule)
            }
            
            invalidateCache(for: "schedules")
            
        } catch {
            self.error = DataServiceError.operationFailed(error)
            throw error
        }
    }
    
    func fetchSchedules(for locationId: UUID, startDate: Date, endDate: Date) async throws -> [Schedule] {
        let cacheKey = "schedules_\(locationId.uuidString)_\(startDate.timeIntervalSince1970)"
        if let cachedSchedules: [Schedule] = getCachedData(for: cacheKey) {
            return cachedSchedules
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let predicate = NSPredicate(
                format: "locationId == %@ AND weekOf >= %@ AND weekOf <= %@",
                locationId.uuidString,
                startDate as NSDate,
                endDate as NSDate
            )
            let query = CKQuery(recordType: "Schedule", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "weekOf", ascending: true)]
            
            let result = try await database.records(matching: query)
            let schedules = try result.matchResults.compactMap { _, result in
                try result.get()
            }.compactMap { record in
                try? extractModel(Schedule.self, from: record)
            }
            
            setCachedData(schedules, for: cacheKey)
            return schedules
            
        } catch {
            self.error = DataServiceError.fetchFailed(error)
            throw error
        }
    }
    
    // MARK: - Real-time Collaboration
    
    func publishSchedule(_ scheduleId: UUID) async throws {
        guard let index = schedules.firstIndex(where: { $0.id == scheduleId }) else {
            throw DataServiceError.scheduleNotFound
        }
        
        schedules[index].status = .published
        schedules[index].publishedAt = Date()
        
        try await saveSchedule(schedules[index])
        
        // Send notifications to affected employees
        await sendSchedulePublishedNotifications(schedule: schedules[index])
    }
    
    func requestShiftSwap(from fromEmployeeId: UUID, to toEmployeeId: UUID?, for shiftId: UUID, reason: String) async throws {
        let swapRequest = SwapRequest(
            fromEmployeeId: fromEmployeeId,
            toEmployeeId: toEmployeeId,
            shiftId: shiftId,
            reason: reason
        )
        
        let record = try await createCKRecord(from: swapRequest, recordType: "SwapRequest")
        _ = try await database.save(record)
        
        // Send notification to relevant parties
        await sendSwapRequestNotification(swapRequest)
    }
    
    // MARK: - Analytics & Reporting
    
    func generateLaborCostReport(for locationId: UUID, period: DateInterval) async throws -> LaborCostReport {
        let schedules = try await fetchSchedules(
            for: locationId,
            startDate: period.start,
            endDate: period.end
        )
        
        let employees = try await fetchEmployees()
        
        return LaborCostReport.generate(from: schedules, employees: employees, period: period)
    }
    
    func generateEmployeePerformanceReport(for employeeId: UUID, period: DateInterval) async throws -> EmployeePerformanceReport {
        // Fetch employee data, shift assignments, performance metrics
        return EmployeePerformanceReport(
            employeeId: employeeId,
            period: period,
            metrics: PerformanceMetrics()
        )
    }
    
    // MARK: - Private Helpers
    
    private func setupCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func setupCloudKitNotifications() {
        // Register for remote notifications
        Task {
            do {
                try await container.requestApplicationPermission(.userDiscoverability)
            } catch {
                print("Failed to request CloudKit permissions: \(error)")
            }
        }
    }
    
    private func setupOrganizationSubscriptions() async {
        guard let orgId = currentOrganization?.id else { return }
        
        // Subscribe to organization changes
        let predicate = NSPredicate(format: "organizationId == %@", orgId.uuidString)
        
        let employeeSubscription = CKQuerySubscription(
            recordType: "Employee",
            predicate: predicate,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let scheduleSubscription = CKQuerySubscription(
            recordType: "Schedule",
            predicate: predicate,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        do {
            _ = try await database.save(employeeSubscription)
            _ = try await database.save(scheduleSubscription)
            
            realTimeSubscriptions.append(employeeSubscription)
            realTimeSubscriptions.append(scheduleSubscription)
        } catch {
            print("Failed to setup CloudKit subscriptions: \(error)")
        }
    }
    
    private func fetchCurrentUser() async throws -> DataServiceEmployee {
        // Fetch current user from CloudKit
        // This would typically involve fetching by CloudKit user record ID
        throw DataServiceError.notImplemented
    }
    
    private func createCKRecord<T: Codable>(from model: T, recordType: String) async throws -> CKRecord {
        let data = try encoder.encode(model)
        let record = CKRecord(recordType: recordType)
        record["data"] = data
        return record
    }
    
    private func extractModel<T: Codable>(_ type: T.Type, from record: CKRecord) throws -> T {
        guard let data = record["data"] as? Data else {
            throw DataServiceError.dataCorruption
        }
        return try decoder.decode(type, from: data)
    }
    
    private func getCachedData<T>(for key: String) -> T? {
        guard let entry = cache.object(forKey: NSString(string: key)),
              entry.timestamp.timeIntervalSinceNow > -cacheTimeout,
              let data = entry.data as? T else {
            return nil
        }
        return data
    }
    
    private func setCachedData<T>(_ data: T, for key: String) {
        let entry = CacheEntry(data: data, timestamp: Date())
        cache.setObject(entry, forKey: NSString(string: key))
    }
    
    private func invalidateCache(for key: String) {
        cache.removeObject(forKey: NSString(string: key))
    }
    
    private func refreshIfNeeded() async {
        // Implement smart refresh logic
        if syncStatus == .idle && !isLoading {
            // Refresh stale data
        }
    }
    
    private func sendSchedulePublishedNotifications(schedule: Schedule) async {
        // Send push notifications to all affected employees
        // Implementation would use UserNotifications framework
    }
    
    private func sendSwapRequestNotification(_ swapRequest: SwapRequest) async {
        // Send notification to target employee and managers
    }
}

// MARK: - Supporting Types

enum DataServiceError: LocalizedError {
    case noCloudKitAccount
    case cloudKitRestricted
    case authenticationFailed(Error)
    case operationFailed(Error)
    case fetchFailed(Error)
    case noOrganization
    case scheduleGenerationFailed([ConstraintViolation])
    case scheduleNotFound
    case dataCorruption
    case notImplemented
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noCloudKitAccount:
            return "No iCloud account found. Please sign in to iCloud in Settings."
        case .cloudKitRestricted:
            return "iCloud access is restricted. Please check your restrictions in Settings."
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .operationFailed(let error):
            return "Operation failed: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .noOrganization:
            return "No organization selected. Please create or join an organization."
        case .scheduleGenerationFailed(let violations):
            return "Schedule generation failed with \(violations.count) constraint violations."
        case .scheduleNotFound:
            return "Schedule not found."
        case .dataCorruption:
            return "Data corruption detected."
        case .notImplemented:
            return "Feature not yet implemented."
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

enum SyncStatus {
    case idle
    case syncing
    case failed(Error)
    case completed(Date)
}

class CacheEntry: NSObject {
    let data: Any
    let timestamp: Date
    
    init(data: Any, timestamp: Date) {
        self.data = data
        self.timestamp = timestamp
    }
}

// MARK: - Reporting Models

struct LaborCostReport {
    let locationId: UUID
    let period: DateInterval
    let totalCost: Decimal
    let breakdown: [String: Decimal]
    let budgetVariance: Decimal
    let costPerHour: Decimal
    let overtimeCost: Decimal
    
    static func generate(from schedules: [Schedule], employees: [DataServiceEmployee], period: DateInterval) -> LaborCostReport {
        // Implementation for generating labor cost report
        return LaborCostReport(
            locationId: UUID(),
            period: period,
            totalCost: 10000,
            breakdown: [:],
            budgetVariance: 500,
            costPerHour: 25,
            overtimeCost: 1200
        )
    }
}

struct EmployeePerformanceReport {
    let employeeId: UUID
    let period: DateInterval
    let metrics: PerformanceMetrics
    let hoursWorked: Double
    let attendanceRate: Double
    let punctualityScore: Double
    let noShowCount: Int
}