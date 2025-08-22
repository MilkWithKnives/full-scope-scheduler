import Foundation
import Combine
import Charts
import SwiftUI

// Type aliases to resolve ambiguity with basic models
typealias AnalyticsEmployee = Employee
typealias AnalyticsShift = Shift
typealias AnalyticsWeekday = Weekday

/// Advanced analytics and business intelligence engine for workforce management
@MainActor
class AnalyticsEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var laborCostTrends: [LaborCostDataPoint] = []
    @Published var attendanceMetrics: AttendanceMetrics?
    @Published var productivityInsights: ProductivityInsights?
    @Published var forecastData: [ForecastDataPoint] = []
    @Published var realTimeMetrics: RealTimeMetrics?
    
    @Published var isGeneratingReport = false
    @Published var lastAnalysisDate: Date?
    
    // MARK: - Dependencies
    private let dataService: DataService
    private var cancellables = Set<AnyCancellable>()
    
    // Analytics configuration
    private let analysisInterval: TimeInterval = 3600 // 1 hour
    private let forecastHorizon: TimeInterval = 30 * 24 * 3600 // 30 days
    
    init(dataService: DataService) {
        self.dataService = dataService
        setupRealTimeAnalytics()
        startPeriodicAnalysis()
    }
    
    // MARK: - Labor Cost Analytics
    
    func generateLaborCostAnalysis(for period: DateInterval, locationId: UUID? = nil) async -> LaborCostAnalysis {
        isGeneratingReport = true
        defer { isGeneratingReport = false }
        
        do {
            // Fetch relevant data
            let schedules = try await dataService.fetchSchedules(
                for: locationId ?? UUID(),
                startDate: period.start,
                endDate: period.end
            )
            
            let employees: [AnalyticsEmployee] = try await dataService.fetchEmployees()
            
            // Calculate comprehensive labor costs
            var totalCost: Decimal = 0
            var overtimeCost: Decimal = 0
            var breakdown: [String: Decimal] = [:]
            var dailyBreakdown: [Date: Decimal] = [:]
            
            // Process each schedule
            for schedule in schedules {
                for shift in schedule.shifts {
                    let shiftCost = calculateShiftCost(shift, employees: employees)
                    totalCost += shiftCost.total
                    overtimeCost += shiftCost.overtime
                    
                    // Department breakdown
                    if let deptId = shift.departmentId {
                        let deptName = "Department \(deptId)" // In real app, fetch department name
                        breakdown[deptName, default: 0] += shiftCost.total
                    }
                    
                    // Daily breakdown
                    let day = Calendar.current.startOfDay(for: shift.startTime)
                    dailyBreakdown[day, default: 0] += shiftCost.total
                }
            }
            
            // Generate trend data
            let trendData = generateLaborCostTrends(from: dailyBreakdown)
            
            // Calculate variance against budget
            let budget = await fetchLaborBudget(for: locationId, period: period)
            let variance = totalCost - (budget?.weeklyBudget ?? 0)
            
            return LaborCostAnalysis(
                totalCost: totalCost,
                currency: "USD",
                savings: variance < 0 ? abs(variance) : nil
            )
            
        } catch {
            // Return empty analysis on error
            return LaborCostAnalysis(
                totalCost: 0,
                currency: "USD"
            )
        }
    }
    
    private func calculateShiftCost(_ shift: AnalyticsShift, employees: [AnalyticsEmployee]) -> (total: Decimal, overtime: Decimal) {
        // Simplified implementation to avoid type conflicts
        // TODO: Implement proper shift cost calculation with enterprise models
        let estimatedCost: Decimal = 200 // Placeholder
        return (total: estimatedCost, overtime: 50)
    }
    
    private func generateLaborCostTrends(from dailyData: [Date: Decimal]) -> [LaborCostDataPoint] {
        return dailyData.map { date, cost in
            LaborCostDataPoint(date: date, cost: cost)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Attendance Analytics
    
    func generateAttendanceAnalysis(for period: DateInterval) async -> AttendanceMetrics {
        do {
            let schedules = try await dataService.fetchSchedules(
                for: UUID(), // In real app, iterate through all locations
                startDate: period.start,
                endDate: period.end
            )
            
            // Simplified attendance calculation to avoid type conflicts
            // TODO: Implement proper attendance analysis with enterprise models
            let totalShifts = schedules.flatMap { $0.shifts }.count * 2 // Estimate 2 employees per shift
            let attendedShifts = Int(Double(totalShifts) * 0.85) // 85% attendance rate
            let lateArrivals = Int(Double(attendedShifts) * 0.1) // 10% late
            let noShows = totalShifts - attendedShifts
            let employeeAttendance: [UUID: EmployeeAttendanceRecord] = [:] // Placeholder
            
            let attendanceRate = totalShifts > 0 ? Double(attendedShifts) / Double(totalShifts) : 0
            let punctualityRate = attendedShifts > 0 ? Double(attendedShifts - lateArrivals) / Double(attendedShifts) : 0
            
            return AttendanceMetrics(
                period: period,
                overallAttendanceRate: attendanceRate,
                punctualityRate: punctualityRate,
                noShowRate: totalShifts > 0 ? Double(noShows) / Double(totalShifts) : 0,
                totalScheduledShifts: totalShifts,
                totalAttendedShifts: attendedShifts,
                lateArrivals: lateArrivals,
                employeeRecords: employeeAttendance
            )
            
        } catch {
            return AttendanceMetrics(
                period: period,
                overallAttendanceRate: 0,
                punctualityRate: 0,
                noShowRate: 0,
                totalScheduledShifts: 0,
                totalAttendedShifts: 0,
                lateArrivals: 0,
                employeeRecords: [:]
            )
        }
    }
    
    // MARK: - Productivity Analytics
    
    func generateProductivityInsights(for period: DateInterval) async -> ProductivityInsights {
        // Calculate various productivity metrics
        let scheduleOptimization = await calculateScheduleOptimization()
        let skillUtilization = await calculateSkillUtilization()
        let departmentEfficiency = await calculateDepartmentEfficiency()
        let peakHoursAnalysis = await analyzePeakHours()
        
        return ProductivityInsights(
            period: period,
            scheduleOptimizationScore: scheduleOptimization,
            skillUtilizationRate: skillUtilization,
            departmentEfficiencyScores: departmentEfficiency,
            peakHoursAnalysis: peakHoursAnalysis,
            recommendedActions: generateRecommendations()
        )
    }
    
    private func calculateScheduleOptimization() async -> Double {
        // AI-powered analysis of schedule efficiency
        // This would analyze factors like:
        // - Coverage vs demand
        // - Employee satisfaction
        // - Cost optimization
        // - Constraint satisfaction
        return 0.87 // Simplified
    }
    
    private func calculateSkillUtilization() async -> Double {
        // Analyze how well employee skills are being utilized
        return 0.78 // Simplified
    }
    
    private func calculateDepartmentEfficiency() async -> [UUID: Double] {
        // Calculate efficiency scores for each department
        return [:] // Simplified
    }
    
    private func analyzePeakHours() async -> PeakHoursAnalysis {
        // Analyze when the business is busiest
        return PeakHoursAnalysis(
            peakDays: [AnalyticsWeekday.friday, AnalyticsWeekday.saturday],
            peakHours: [(18, 22)], // 6 PM - 10 PM
            lowActivityPeriods: [(2, 6)] // 2 AM - 6 AM
        )
    }
    
    private func generateRecommendations() -> [ProductivityRecommendation] {
        return [
            ProductivityRecommendation(
                type: .staffingOptimization,
                title: "Optimize Weekend Staffing",
                description: "Consider increasing staff by 15% on weekend evenings to handle peak demand",
                impact: .high,
                estimatedSavings: 2500
            ),
            ProductivityRecommendation(
                type: .skillDevelopment,
                title: "Cross-Training Opportunity",
                description: "Train 3 employees in customer service skills to increase flexibility",
                impact: .medium,
                estimatedSavings: 800
            )
        ]
    }
    
    // MARK: - Forecasting
    
    func generateForecast(for futurePeriod: DateInterval) async -> [ForecastDataPoint] {
        // Generate predictive analytics for future labor needs
        let historicalData = await gatherHistoricalData()
        let trends = analyzeHistoricalTrends(historicalData)
        let seasonalFactors = calculateSeasonalFactors(historicalData)
        
        var forecast: [ForecastDataPoint] = []
        let calendar = Calendar.current
        var currentDate = futurePeriod.start
        
        while currentDate < futurePeriod.end {
            let dayOfWeek = calendar.component(.weekday, from: currentDate)
            let month = calendar.component(.month, from: currentDate)
            
            // Apply trend and seasonal adjustments
            let baseDemand = trends.averageDailyDemand
            let seasonalAdjustment = seasonalFactors[month] ?? 1.0
            let weekdayAdjustment = getWeekdayMultiplier(dayOfWeek)
            
            let predictedDemand = baseDemand * seasonalAdjustment * weekdayAdjustment
            let predictedCost = predictedDemand * trends.averageCostPerHour
            
            forecast.append(ForecastDataPoint(
                date: currentDate,
                predictedDemand: predictedDemand,
                predictedCost: Decimal(predictedCost),
                confidenceInterval: 0.85
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return forecast
    }
    
    private func gatherHistoricalData() async -> HistoricalData {
        // Gather historical scheduling and performance data
        return HistoricalData(
            laborCosts: [],
            attendanceRates: [],
            demandPatterns: []
        )
    }
    
    private func analyzeHistoricalTrends(_ data: HistoricalData) -> TrendAnalysis {
        return TrendAnalysis(
            averageDailyDemand: 45.0, // hours
            averageCostPerHour: 25.0,
            growthRate: 0.03 // 3% monthly growth
        )
    }
    
    private func calculateSeasonalFactors(_ data: HistoricalData) -> [Int: Double] {
        // Calculate monthly seasonal adjustment factors
        return [
            1: 0.85, 2: 0.82, 3: 0.90, 4: 0.95, 5: 1.05, 6: 1.10,
            7: 1.15, 8: 1.12, 9: 1.00, 10: 0.98, 11: 1.08, 12: 1.20
        ]
    }
    
    private func getWeekdayMultiplier(_ weekday: Int) -> Double {
        // 1 = Sunday, 7 = Saturday
        switch weekday {
        case 1: return 1.2 // Sunday
        case 2: return 0.7 // Monday
        case 3: return 0.8 // Tuesday
        case 4: return 0.9 // Wednesday
        case 5: return 1.0 // Thursday
        case 6: return 1.3 // Friday
        case 7: return 1.4 // Saturday
        default: return 1.0
        }
    }
    
    // MARK: - Real-Time Analytics
    
    private func setupRealTimeAnalytics() {
        // Update real-time metrics every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.updateRealTimeMetrics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateRealTimeMetrics() async {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        
        // Calculate today's metrics
        let todaySchedules = try? await dataService.fetchSchedules(
            for: UUID(), // All locations
            startDate: today,
            endDate: today.addingTimeInterval(24 * 3600)
        )
        
        guard let schedules = todaySchedules else { return }
        
        var activeShifts = 0
        var totalStaffScheduled = 0
        var currentLaborCost: Decimal = 0
        
        for schedule in schedules {
            for shift in schedule.shifts {
                // Check if shift is currently active
                if shift.startTime <= now && shift.endTime > now {
                    activeShifts += 1
                    totalStaffScheduled += shift.assignedEmployees.count
                    
                    // Calculate current labor cost
                    let hourlyRate: Decimal = 25.0 // Simplified - would fetch from employee data
                    currentLaborCost += Decimal(shift.assignedEmployees.count) * hourlyRate
                }
            }
        }
        
        realTimeMetrics = RealTimeMetrics(
            timestamp: now,
            activeShifts: activeShifts,
            staffCurrentlyWorking: totalStaffScheduled,
            currentHourlyLaborCost: currentLaborCost,
            todayAttendanceRate: 0.94 // Would calculate from actual data
        )
    }
    
    private func startPeriodicAnalysis() {
        // Run comprehensive analysis periodically
        Timer.publish(every: analysisInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.runPeriodicAnalysis()
                }
            }
            .store(in: &cancellables)
    }
    
    private func runPeriodicAnalysis() async {
        let now = Date()
        let lastWeek = now.addingTimeInterval(-7 * 24 * 3600)
        let period = DateInterval(start: lastWeek, end: now)
        
        // Update published analytics data
        async let attendanceTask = generateAttendanceAnalysis(for: period)
        async let productivityTask = generateProductivityInsights(for: period)
        
        attendanceMetrics = await attendanceTask
        productivityInsights = await productivityTask
        lastAnalysisDate = now
    }
    
    private func fetchLaborBudget(for locationId: UUID?, period: DateInterval) async -> LaborBudget? {
        // In a real app, this would fetch the actual budget from the data service
        return LaborBudget(
            weeklyBudget: 15000,
            dailyBudget: 2500,
            currency: "USD"
        )
    }
}

// MARK: - Analytics Data Models

struct LaborCostDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let cost: Decimal
}

struct AttendanceMetrics {
    let period: DateInterval
    let overallAttendanceRate: Double
    let punctualityRate: Double
    let noShowRate: Double
    let totalScheduledShifts: Int
    let totalAttendedShifts: Int
    let lateArrivals: Int
    let employeeRecords: [UUID: EmployeeAttendanceRecord]
}

struct EmployeeAttendanceRecord {
    var totalScheduled: Int = 0
    var attended: Int = 0
    var lateCount: Int = 0
    var noShows: Int = 0
    
    var attendanceRate: Double {
        totalScheduled > 0 ? Double(attended) / Double(totalScheduled) : 0
    }
    
    var punctualityRate: Double {
        attended > 0 ? Double(attended - lateCount) / Double(attended) : 0
    }
}

struct ProductivityInsights {
    let period: DateInterval
    let scheduleOptimizationScore: Double
    let skillUtilizationRate: Double
    let departmentEfficiencyScores: [UUID: Double]
    let peakHoursAnalysis: PeakHoursAnalysis
    let recommendedActions: [ProductivityRecommendation]
}

struct PeakHoursAnalysis {
    let peakDays: [AnalyticsWeekday]
    let peakHours: [(start: Int, end: Int)]
    let lowActivityPeriods: [(start: Int, end: Int)]
}

struct ProductivityRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let impact: Impact
    let estimatedSavings: Decimal
}

enum RecommendationType {
    case staffingOptimization
    case skillDevelopment
    case scheduleAdjustment
    case costReduction
}

enum Impact {
    case low, medium, high
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct ForecastDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let predictedDemand: Double // in hours
    let predictedCost: Decimal
    let confidenceInterval: Double
}

struct RealTimeMetrics {
    let timestamp: Date
    let activeShifts: Int
    let staffCurrentlyWorking: Int
    let currentHourlyLaborCost: Decimal
    let todayAttendanceRate: Double
}

// Supporting data structures for internal calculations
struct HistoricalData {
    let laborCosts: [LaborCostDataPoint]
    let attendanceRates: [Double]
    let demandPatterns: [DemandPattern]
}

struct DemandPattern {
    let date: Date
    let hoursRequired: Double
    let actualHoursWorked: Double
}

struct TrendAnalysis {
    let averageDailyDemand: Double
    let averageCostPerHour: Double
    let growthRate: Double
}

// Note: Enhanced LaborCostAnalysis extension removed to fix compilation errors
// Extensions cannot contain stored properties
