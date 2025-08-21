import Foundation
import Combine

/// Intelligent automation engine with workflow orchestration and smart triggers
@MainActor
class AutomationEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeAutomations: [AutomationRule] = []
    @Published var workflowTemplates: [WorkflowTemplate] = []
    @Published var executionHistory: [AutomationExecution] = []
    @Published var automationStats: AutomationStatistics?
    
    @Published var isProcessingAutomations = false
    @Published var lastExecutionTime: Date?
    
    // MARK: - Private Properties
    private var eventStream = PassthroughSubject<SystemEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var executionQueue = DispatchQueue(label: "automation.execution", qos: .userInitiated)
    
    // Dependencies
    private weak var dataService: DataService?
    private weak var notificationService: NotificationService?
    private weak var schedulingEngine: AdvancedSchedulingEngine?
    
    // Smart Learning Components
    private let patternAnalyzer = AutomationPatternAnalyzer()
    private let workflowOptimizer = WorkflowOptimizer()
    private let intelligentTrigger = IntelligentTriggerSystem()
    
    init() {
        setupBuiltInAutomations()
        setupEventProcessing()
        setupSmartTriggers()
    }
    
    func configure(
        dataService: DataService,
        notificationService: NotificationService,
        schedulingEngine: AdvancedSchedulingEngine
    ) {
        self.dataService = dataService
        self.notificationService = notificationService
        self.schedulingEngine = schedulingEngine
        
        observeSystemEvents()
    }
    
    // MARK: - Smart Automation Rules
    
    private func setupBuiltInAutomations() {
        activeAutomations = [
            // Intelligent Schedule Publishing
            AutomationRule(
                id: UUID(),
                name: "Smart Schedule Publisher",
                description: "Automatically publishes schedules when optimization threshold is met",
                trigger: .composite([
                    .scheduleGenerated,
                    .customCondition("optimizationScore >= 90")
                ]),
                conditions: [
                    .scheduleQualityThreshold(90.0),
                    .noUnresolvedConflicts,
                    .withinPublishingWindow
                ],
                actions: [
                    .publishSchedule,
                    .sendNotificationToManagers("New schedule published with 90%+ optimization"),
                    .logAction("Auto-published schedule with score: {optimizationScore}")
                ],
                priority: .high,
                category: .scheduling,
                isEnabled: true,
                learningEnabled: true
            ),
            
            // Proactive Understaffing Prevention
            AutomationRule(
                id: UUID(),
                name: "Understaffing Prevention System",
                description: "Detects and prevents understaffing before it occurs",
                trigger: .composite([
                    .timeScheduled(.hoursBeforeShift(4)),
                    .predictiveAnalysis(.understaffingRisk(0.7))
                ]),
                conditions: [
                    .understaffingProbability(0.7),
                    .availableBackupStaff
                ],
                actions: [
                    .findCoverageOptions,
                    .notifyAvailableEmployees("Coverage needed for upcoming shift"),
                    .alertManagers("Potential understaffing detected - automated response initiated"),
                    .logAction("Proactive understaffing prevention triggered")
                ],
                priority: .critical,
                category: .operational,
                isEnabled: true,
                learningEnabled: true
            ),
            
            // Dynamic Overtime Management
            AutomationRule(
                id: UUID(),
                name: "Smart Overtime Controller",
                description: "Automatically manages overtime to optimize costs while maintaining coverage",
                trigger: .laborCostThresholdExceeded(0.9),
                conditions: [
                    .budgetVariance(0.1),
                    .noEssentialShifts
                ],
                actions: [
                    .optimizeStaffingLevels,
                    .suggestScheduleAdjustments,
                    .sendCostAlert("Overtime optimization suggestions available"),
                    .generateCostReport
                ],
                priority: .high,
                category: .financial,
                isEnabled: true,
                learningEnabled: false
            ),
            
            // Employee Satisfaction Monitor
            AutomationRule(
                id: UUID(),
                name: "Employee Experience Guardian",
                description: "Monitors and improves employee satisfaction through automated adjustments",
                trigger: .satisfactionScoreChanged,
                conditions: [
                    .employeeSatisfactionBelow(80.0),
                    .consecutiveDecline(3)
                ],
                actions: [
                    .analyzePreferenceViolations,
                    .suggestScheduleAdjustments,
                    .scheduleManagerReview,
                    .sendSatisfactionReport
                ],
                priority: .medium,
                category: .hrOptimization,
                isEnabled: true,
                learningEnabled: true
            ),
            
            // Intelligent Swap Facilitation
            AutomationRule(
                id: UUID(),
                name: "Smart Swap Matchmaker",
                description: "Automatically matches compatible employees for shift swaps",
                trigger: .swapRequestCreated,
                conditions: [
                    .compatibleEmployeesAvailable,
                    .noScheduleConflicts,
                    .swapBeneficial
                ],
                actions: [
                    .findOptimalSwapMatches,
                    .notifyCompatibleEmployees("Perfect swap match found!"),
                    .preApproveIfEligible,
                    .trackSwapSuccess
                ],
                priority: .medium,
                category: .collaboration,
                isEnabled: true,
                learningEnabled: true
            ),
            
            // Predictive Maintenance Scheduler
            AutomationRule(
                id: UUID(),
                name: "Schedule Health Monitor",
                description: "Predicts and prevents schedule-breaking events",
                trigger: .timeScheduled(.dailyAt(hour: 6, minute: 0)),
                conditions: [
                    .scheduleIntegrityRisk(0.6),
                    .predictiveModelConfidence(0.8)
                ],
                actions: [
                    .runScheduleHealthCheck,
                    .identifyRiskFactors,
                    .generatePreventionPlan,
                    .alertIfCritical
                ],
                priority: .high,
                category: .maintenance,
                isEnabled: true,
                learningEnabled: true
            )
        ]
    }
    
    // MARK: - Event Processing
    
    private func setupEventProcessing() {
        eventStream
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] event in
                Task { [weak self] in
                    await self?.processEvent(event)
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeSystemEvents() {
        guard let dataService = dataService else { return }
        
        // Observe data changes and convert to system events
        dataService.$schedules
            .dropFirst()
            .sink { [weak self] schedules in
                self?.eventStream.send(.scheduleChanged(schedules))
            }
            .store(in: &cancellables)
        
        dataService.$employees
            .dropFirst()
            .sink { [weak self] employees in
                self?.eventStream.send(.employeeDataChanged(employees))
            }
            .store(in: &cancellables)
        
        // Monitor real-time metrics
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.checkRealtimeConditions()
                }
            }
            .store(in: &cancellables)
    }
    
    private func processEvent(_ event: SystemEvent) async {
        isProcessingAutomations = true
        defer { isProcessingAutomations = false }
        
        let applicableRules = activeAutomations.filter { rule in
            rule.isEnabled && rule.trigger.matches(event)
        }
        
        for rule in applicableRules {
            await executeAutomationRule(rule, triggeredBy: event)
        }
        
        lastExecutionTime = Date()
    }
    
    // MARK: - Rule Execution
    
    private func executeAutomationRule(_ rule: AutomationRule, triggeredBy event: SystemEvent) async {
        let execution = AutomationExecution(
            id: UUID(),
            ruleId: rule.id,
            ruleName: rule.name,
            trigger: event,
            startTime: Date()
        )
        
        do {
            // Check conditions
            let conditionResults = await evaluateConditions(rule.conditions, for: event)
            execution.conditionResults = conditionResults
            
            let allConditionsMet = conditionResults.allSatisfy { $0.satisfied }
            
            if allConditionsMet {
                // Execute actions
                let actionResults = await executeActions(rule.actions, for: event, rule: rule)
                execution.actionResults = actionResults
                execution.status = .completed
                
                // Learn from successful execution if enabled
                if rule.learningEnabled {
                    await patternAnalyzer.recordSuccessfulExecution(rule, event: event, results: actionResults)
                }
                
            } else {
                execution.status = .conditionsNotMet
                execution.failureReason = "Conditions not satisfied: \(conditionResults.compactMap { !$0.satisfied ? $0.condition.description : nil }.joined(separator: ", "))"
            }
            
        } catch {
            execution.status = .failed
            execution.failureReason = error.localizedDescription
            execution.error = error
        }
        
        execution.endTime = Date()
        executionHistory.append(execution)
        
        // Update statistics
        updateAutomationStatistics()
        
        // Optimize rule if learning is enabled
        if rule.learningEnabled {
            await optimizeRule(rule, execution: execution)
        }
    }
    
    // MARK: - Condition Evaluation
    
    private func evaluateConditions(_ conditions: [AutomationCondition], for event: SystemEvent) async -> [ConditionResult] {
        var results: [ConditionResult] = []
        
        for condition in conditions {
            let result = await evaluateCondition(condition, for: event)
            results.append(result)
        }
        
        return results
    }
    
    private func evaluateCondition(_ condition: AutomationCondition, for event: SystemEvent) async -> ConditionResult {
        let startTime = Date()
        var satisfied = false
        var details: [String: Any] = [:]
        var confidence: Double = 1.0
        
        switch condition {
        case .scheduleQualityThreshold(let threshold):
            if case .scheduleGenerated(let schedule) = event {
                let quality = await calculateScheduleQuality(schedule)
                satisfied = quality >= threshold
                details["actualQuality"] = quality
                details["threshold"] = threshold
            }
            
        case .noUnresolvedConflicts:
            satisfied = await checkForUnresolvedConflicts()
            details["conflictCount"] = await getConflictCount()
            
        case .withinPublishingWindow:
            satisfied = isWithinPublishingWindow()
            details["currentTime"] = Date()
            details["publishingWindow"] = getPublishingWindow()
            
        case .understaffingProbability(let threshold):
            let probability = await calculateUnderstaffingProbability()
            satisfied = probability >= threshold
            details["probability"] = probability
            details["threshold"] = threshold
            confidence = await getUnderstaffingPredictionConfidence()
            
        case .availableBackupStaff:
            let backupCount = await getAvailableBackupStaffCount()
            satisfied = backupCount > 0
            details["backupStaffCount"] = backupCount
            
        case .budgetVariance(let allowedVariance):
            let variance = await calculateBudgetVariance()
            satisfied = abs(variance) <= allowedVariance
            details["variance"] = variance
            details["allowedVariance"] = allowedVariance
            
        case .noEssentialShifts:
            satisfied = await checkForEssentialShifts() == false
            details["essentialShiftCount"] = await getEssentialShiftCount()
            
        case .employeeSatisfactionBelow(let threshold):
            let avgSatisfaction = await calculateAverageEmployeeSatisfaction()
            satisfied = avgSatisfaction < threshold
            details["averageSatisfaction"] = avgSatisfaction
            details["threshold"] = threshold
            
        case .consecutiveDecline(let periods):
            satisfied = await checkConsecutiveSatisfactionDecline(periods: periods)
            details["periods"] = periods
            
        case .compatibleEmployeesAvailable:
            if case .swapRequestCreated(let request) = event {
                let compatibleCount = await findCompatibleEmployeesForSwap(request).count
                satisfied = compatibleCount > 0
                details["compatibleEmployees"] = compatibleCount
            }
            
        case .noScheduleConflicts:
            satisfied = await checkForScheduleConflicts() == false
            
        case .swapBeneficial:
            if case .swapRequestCreated(let request) = event {
                satisfied = await evaluateSwapBenefit(request) > 0.5
                details["benefit"] = await evaluateSwapBenefit(request)
            }
            
        case .scheduleIntegrityRisk(let threshold):
            let riskScore = await calculateScheduleIntegrityRisk()
            satisfied = riskScore >= threshold
            details["riskScore"] = riskScore
            details["threshold"] = threshold
            
        case .predictiveModelConfidence(let threshold):
            confidence = await getPredictiveModelConfidence()
            satisfied = confidence >= threshold
            details["confidence"] = confidence
            details["threshold"] = threshold
        }
        
        return ConditionResult(
            condition: condition,
            satisfied: satisfied,
            evaluationTime: Date().timeIntervalSince(startTime),
            details: details,
            confidence: confidence
        )
    }
    
    // MARK: - Action Execution
    
    private func executeActions(_ actions: [AutomationAction], for event: SystemEvent, rule: AutomationRule) async -> [ActionResult] {
        var results: [ActionResult] = []
        
        for action in actions {
            let result = await executeAction(action, for: event, rule: rule)
            results.append(result)
        }
        
        return results
    }
    
    private func executeAction(_ action: AutomationAction, for event: SystemEvent, rule: AutomationRule) async -> ActionResult {
        let startTime = Date()
        var success = false
        var details: [String: Any] = [:]
        var error: Error?
        
        do {
            switch action {
            case .publishSchedule:
                if case .scheduleGenerated(let schedule) = event {
                    try await dataService?.publishSchedule(schedule.id)
                    success = true
                    details["scheduleId"] = schedule.id.uuidString
                }
                
            case .sendNotificationToManagers(let message):
                await sendNotificationToManagers(message, context: event)
                success = true
                details["message"] = message
                
            case .logAction(let message):
                logAction(message, rule: rule, event: event)
                success = true
                details["logMessage"] = message
                
            case .findCoverageOptions:
                let options = await findCoverageOptions(for: event)
                success = !options.isEmpty
                details["optionsFound"] = options.count
                
            case .notifyAvailableEmployees(let message):
                let notifiedCount = await notifyAvailableEmployees(message, for: event)
                success = notifiedCount > 0
                details["employeesNotified"] = notifiedCount
                
            case .alertManagers(let message):
                await alertManagers(message, priority: rule.priority)
                success = true
                details["message"] = message
                
            case .optimizeStaffingLevels:
                let optimizationResult = await optimizeStaffingLevels()
                success = optimizationResult.success
                details["optimization"] = optimizationResult
                
            case .suggestScheduleAdjustments:
                let suggestions = await generateScheduleAdjustmentSuggestions()
                success = !suggestions.isEmpty
                details["suggestions"] = suggestions.count
                
            case .sendCostAlert(let message):
                await sendCostAlert(message)
                success = true
                details["message"] = message
                
            case .generateCostReport:
                let report = await generateCostReport()
                success = true
                details["reportId"] = report.id
                
            case .analyzePreferenceViolations:
                let violations = await analyzePreferenceViolations()
                success = true
                details["violationsFound"] = violations.count
                
            case .scheduleManagerReview:
                await scheduleManagerReview()
                success = true
                
            case .sendSatisfactionReport:
                await sendSatisfactionReport()
                success = true
                
            case .findOptimalSwapMatches:
                if case .swapRequestCreated(let request) = event {
                    let matches = await findOptimalSwapMatches(for: request)
                    success = !matches.isEmpty
                    details["matchesFound"] = matches.count
                }
                
            case .notifyCompatibleEmployees(let message):
                if case .swapRequestCreated(let request) = event {
                    let notifiedCount = await notifyCompatibleEmployeesForSwap(message, request: request)
                    success = notifiedCount > 0
                    details["employeesNotified"] = notifiedCount
                }
                
            case .preApproveIfEligible:
                if case .swapRequestCreated(let request) = event {
                    success = await preApproveSwapIfEligible(request)
                    details["preApproved"] = success
                }
                
            case .trackSwapSuccess:
                await trackSwapSuccessMetrics()
                success = true
                
            case .runScheduleHealthCheck:
                let healthScore = await runScheduleHealthCheck()
                success = true
                details["healthScore"] = healthScore
                
            case .identifyRiskFactors:
                let risks = await identifyScheduleRiskFactors()
                success = true
                details["risksIdentified"] = risks.count
                
            case .generatePreventionPlan:
                let plan = await generatePreventionPlan()
                success = true
                details["planId"] = plan.id
                
            case .alertIfCritical:
                let isCritical = await assessCriticalRisk()
                if isCritical {
                    await sendCriticalRiskAlert()
                }
                success = true
                details["wasCritical"] = isCritical
            }
            
        } catch let actionError {
            success = false
            error = actionError
            details["error"] = actionError.localizedDescription
        }
        
        return ActionResult(
            action: action,
            success: success,
            executionTime: Date().timeIntervalSince(startTime),
            details: details,
            error: error
        )
    }
    
    // MARK: - Smart Learning and Optimization
    
    private func optimizeRule(_ rule: AutomationRule, execution: AutomationExecution) async {
        await workflowOptimizer.optimizeRule(rule, basedOn: execution)
    }
    
    private func setupSmartTriggers() {
        // Configure intelligent trigger system with pattern recognition
        intelligentTrigger.configure(
            patternAnalyzer: patternAnalyzer,
            minimumConfidence: 0.8,
            learningRate: 0.1
        )
    }
    
    private func checkRealtimeConditions() async {
        // Periodically check for conditions that might trigger automations
        let currentMetrics = await getCurrentSystemMetrics()
        
        // Generate synthetic events based on real-time analysis
        if currentMetrics.understaffingRisk > 0.7 {
            eventStream.send(.understaffingRiskDetected(risk: currentMetrics.understaffingRisk))
        }
        
        if currentMetrics.employeeSatisfactionChange < -5.0 {
            eventStream.send(.satisfactionScoreChanged)
        }
        
        if currentMetrics.budgetVariance > 0.9 {
            eventStream.send(.laborCostThresholdExceeded(currentMetrics.budgetVariance))
        }
    }
    
    // MARK: - Statistics and Analytics
    
    private func updateAutomationStatistics() {
        let totalExecutions = executionHistory.count
        let successfulExecutions = executionHistory.filter { $0.status == .completed }.count
        let failedExecutions = executionHistory.filter { $0.status == .failed }.count
        
        let averageExecutionTime = executionHistory.compactMap { execution in
            guard let endTime = execution.endTime else { return nil }
            return endTime.timeIntervalSince(execution.startTime)
        }.reduce(0, +) / Double(max(1, executionHistory.count))
        
        let ruleEffectiveness = Dictionary(grouping: executionHistory) { $0.ruleId }
            .mapValues { executions in
                let successful = executions.filter { $0.status == .completed }.count
                return Double(successful) / Double(executions.count)
            }
        
        automationStats = AutomationStatistics(
            totalExecutions: totalExecutions,
            successfulExecutions: successfulExecutions,
            failedExecutions: failedExecutions,
            successRate: Double(successfulExecutions) / Double(max(1, totalExecutions)),
            averageExecutionTime: averageExecutionTime,
            ruleEffectiveness: ruleEffectiveness,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Workflow Templates
    
    func createWorkflowTemplate(name: String, description: String, steps: [WorkflowStep]) -> WorkflowTemplate {
        let template = WorkflowTemplate(
            id: UUID(),
            name: name,
            description: description,
            steps: steps,
            category: .custom,
            isActive: true
        )
        
        workflowTemplates.append(template)
        return template
    }
    
    // MARK: - Helper Methods (Implementation Placeholders)
    
    private func calculateScheduleQuality(_ schedule: Schedule) async -> Double {
        // Implementation would calculate comprehensive schedule quality
        return 92.0
    }
    
    private func checkForUnresolvedConflicts() async -> Bool {
        return false // Placeholder
    }
    
    private func getConflictCount() async -> Int {
        return 0 // Placeholder
    }
    
    private func isWithinPublishingWindow() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 8 && hour <= 18 // 8 AM to 6 PM
    }
    
    private func getPublishingWindow() -> String {
        return "8:00 AM - 6:00 PM"
    }
    
    private func calculateUnderstaffingProbability() async -> Double {
        return 0.75 // Placeholder
    }
    
    private func getUnderstaffingPredictionConfidence() async -> Double {
        return 0.85 // Placeholder
    }
    
    private func getAvailableBackupStaffCount() async -> Int {
        return 3 // Placeholder
    }
    
    private func calculateBudgetVariance() async -> Double {
        return 0.05 // 5% over budget
    }
    
    private func checkForEssentialShifts() async -> Bool {
        return false // Placeholder
    }
    
    private func getEssentialShiftCount() async -> Int {
        return 0 // Placeholder
    }
    
    private func calculateAverageEmployeeSatisfaction() async -> Double {
        return 78.0 // Below threshold
    }
    
    private func checkConsecutiveSatisfactionDecline(periods: Int) async -> Bool {
        return true // Placeholder
    }
    
    private func findCompatibleEmployeesForSwap(_ request: SwapRequest) async -> [Employee] {
        return [] // Placeholder
    }
    
    private func checkForScheduleConflicts() async -> Bool {
        return false // Placeholder
    }
    
    private func evaluateSwapBenefit(_ request: SwapRequest) async -> Double {
        return 0.7 // Beneficial
    }
    
    private func calculateScheduleIntegrityRisk() async -> Double {
        return 0.65 // Moderate risk
    }
    
    private func getPredictiveModelConfidence() async -> Double {
        return 0.88 // High confidence
    }
    
    private func sendNotificationToManagers(_ message: String, context: SystemEvent) async {
        // Implementation would send notifications to managers
    }
    
    private func logAction(_ message: String, rule: AutomationRule, event: SystemEvent) {
        print("[\(rule.name)] \(message)")
    }
    
    private func findCoverageOptions(for event: SystemEvent) async -> [CoverageOption] {
        return [] // Placeholder
    }
    
    private func notifyAvailableEmployees(_ message: String, for event: SystemEvent) async -> Int {
        return 5 // Placeholder - notified 5 employees
    }
    
    private func alertManagers(_ message: String, priority: AutomationPriority) async {
        // Implementation would alert managers
    }
    
    private func optimizeStaffingLevels() async -> AutomationOptimizationResult {
        return AutomationOptimizationResult(success: true, details: [:])
    }
    
    private func generateScheduleAdjustmentSuggestions() async -> [ScheduleAdjustment] {
        return [] // Placeholder
    }
    
    private func sendCostAlert(_ message: String) async {
        // Implementation would send cost alert
    }
    
    private func generateCostReport() async -> CostReport {
        return CostReport(id: UUID())
    }
    
    private func analyzePreferenceViolations() async -> [PreferenceViolation] {
        return [] // Placeholder
    }
    
    private func scheduleManagerReview() async {
        // Implementation would schedule manager review
    }
    
    private func sendSatisfactionReport() async {
        // Implementation would send satisfaction report
    }
    
    private func findOptimalSwapMatches(for request: SwapRequest) async -> [SwapMatch] {
        return [] // Placeholder
    }
    
    private func notifyCompatibleEmployeesForSwap(_ message: String, request: SwapRequest) async -> Int {
        return 3 // Placeholder
    }
    
    private func preApproveSwapIfEligible(_ request: SwapRequest) async -> Bool {
        return true // Placeholder
    }
    
    private func trackSwapSuccessMetrics() async {
        // Implementation would track swap metrics
    }
    
    private func runScheduleHealthCheck() async -> Double {
        return 95.0 // Health score
    }
    
    private func identifyScheduleRiskFactors() async -> [RiskFactor] {
        return [] // Placeholder
    }
    
    private func generatePreventionPlan() async -> PreventionPlan {
        return PreventionPlan(id: UUID())
    }
    
    private func assessCriticalRisk() async -> Bool {
        return false // Placeholder
    }
    
    private func sendCriticalRiskAlert() async {
        // Implementation would send critical alert
    }
    
    private func getCurrentSystemMetrics() async -> SystemMetrics {
        return SystemMetrics(
            understaffingRisk: 0.3,
            employeeSatisfactionChange: -2.0,
            budgetVariance: 0.05
        )
    }
}

// MARK: - Supporting Classes

class AutomationPatternAnalyzer {
    func recordSuccessfulExecution(_ rule: AutomationRule, event: SystemEvent, results: [ActionResult]) async {
        // Learn from successful executions
    }
}

class WorkflowOptimizer {
    func optimizeRule(_ rule: AutomationRule, basedOn execution: AutomationExecution) async {
        // Optimize rule based on execution results
    }
}

class IntelligentTriggerSystem {
    func configure(patternAnalyzer: AutomationPatternAnalyzer, minimumConfidence: Double, learningRate: Double) {
        // Configure intelligent triggers
    }
}

// MARK: - Data Models

struct AutomationRule: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var trigger: AutomationTrigger
    var conditions: [AutomationCondition]
    var actions: [AutomationAction]
    var priority: AutomationPriority
    var category: AutomationCategory
    var isEnabled: Bool
    var learningEnabled: Bool
    var createdAt: Date = Date()
    var lastExecuted: Date?
    var executionCount: Int = 0
    var successRate: Double = 0.0
}

enum AutomationTrigger {
    case scheduleGenerated
    case scheduleChanged([Schedule])
    case employeeDataChanged([Employee])
    case swapRequestCreated
    case satisfactionScoreChanged
    case laborCostThresholdExceeded(Double)
    case understaffingRiskDetected(risk: Double)
    case timeScheduled(TimeSchedule)
    case composite([AutomationTrigger])
    case predictiveAnalysis(PredictiveAnalysis)
    case customCondition(String)
    
    func matches(_ event: SystemEvent) -> Bool {
        switch (self, event) {
        case (.scheduleGenerated, .scheduleGenerated):
            return true
        case (.scheduleChanged, .scheduleChanged):
            return true
        case (.employeeDataChanged, .employeeDataChanged):
            return true
        case (.swapRequestCreated, .swapRequestCreated):
            return true
        case (.satisfactionScoreChanged, .satisfactionScoreChanged):
            return true
        case (.laborCostThresholdExceeded(let threshold), .laborCostThresholdExceeded(let actual)):
            return actual >= threshold
        case (.composite(let triggers), _):
            return triggers.contains { $0.matches(event) }
        default:
            return false
        }
    }
}

enum TimeSchedule {
    case hoursBeforeShift(Int)
    case dailyAt(hour: Int, minute: Int)
    case weeklyOn(day: Int, hour: Int, minute: Int)
    case monthly
}

enum PredictiveAnalysis {
    case understaffingRisk(Double)
    case satisfactionDrop(Double)
    case costOverrun(Double)
}

enum AutomationCondition {
    case scheduleQualityThreshold(Double)
    case noUnresolvedConflicts
    case withinPublishingWindow
    case understaffingProbability(Double)
    case availableBackupStaff
    case budgetVariance(Double)
    case noEssentialShifts
    case employeeSatisfactionBelow(Double)
    case consecutiveDecline(Int)
    case compatibleEmployeesAvailable
    case noScheduleConflicts
    case swapBeneficial
    case scheduleIntegrityRisk(Double)
    case predictiveModelConfidence(Double)
    
    var description: String {
        switch self {
        case .scheduleQualityThreshold(let threshold):
            return "Schedule quality >= \(threshold)%"
        case .noUnresolvedConflicts:
            return "No unresolved conflicts"
        case .withinPublishingWindow:
            return "Within publishing window"
        case .understaffingProbability(let prob):
            return "Understaffing probability >= \(prob)"
        case .availableBackupStaff:
            return "Backup staff available"
        case .budgetVariance(let variance):
            return "Budget variance <= \(variance)"
        case .noEssentialShifts:
            return "No essential shifts affected"
        case .employeeSatisfactionBelow(let threshold):
            return "Employee satisfaction < \(threshold)%"
        case .consecutiveDecline(let periods):
            return "Consecutive decline for \(periods) periods"
        case .compatibleEmployeesAvailable:
            return "Compatible employees available"
        case .noScheduleConflicts:
            return "No schedule conflicts"
        case .swapBeneficial:
            return "Swap is beneficial"
        case .scheduleIntegrityRisk(let risk):
            return "Schedule integrity risk >= \(risk)"
        case .predictiveModelConfidence(let confidence):
            return "Predictive model confidence >= \(confidence)"
        }
    }
}

enum AutomationAction {
    case publishSchedule
    case sendNotificationToManagers(String)
    case logAction(String)
    case findCoverageOptions
    case notifyAvailableEmployees(String)
    case alertManagers(String)
    case optimizeStaffingLevels
    case suggestScheduleAdjustments
    case sendCostAlert(String)
    case generateCostReport
    case analyzePreferenceViolations
    case scheduleManagerReview
    case sendSatisfactionReport
    case findOptimalSwapMatches
    case notifyCompatibleEmployees(String)
    case preApproveIfEligible
    case trackSwapSuccess
    case runScheduleHealthCheck
    case identifyRiskFactors
    case generatePreventionPlan
    case alertIfCritical
}

enum AutomationPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

enum AutomationCategory {
    case scheduling
    case operational
    case financial
    case hrOptimization
    case collaboration
    case maintenance
    case compliance
    case custom
    
    var displayName: String {
        switch self {
        case .scheduling: return "Scheduling"
        case .operational: return "Operational"
        case .financial: return "Financial"
        case .hrOptimization: return "HR Optimization"
        case .collaboration: return "Collaboration"
        case .maintenance: return "Maintenance"
        case .compliance: return "Compliance"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .scheduling: return "calendar.badge.clock"
        case .operational: return "gear.badge"
        case .financial: return "dollarsign.circle"
        case .hrOptimization: return "person.badge.plus"
        case .collaboration: return "person.2.badge.gearshape"
        case .maintenance: return "wrench.and.screwdriver"
        case .compliance: return "checkmark.shield"
        case .custom: return "slider.horizontal.3"
        }
    }
}

enum SystemEvent {
    case scheduleGenerated(Schedule)
    case scheduleChanged([Schedule])
    case employeeDataChanged([Employee])
    case swapRequestCreated(SwapRequest)
    case satisfactionScoreChanged
    case laborCostThresholdExceeded(Double)
    case understaffingRiskDetected(risk: Double)
}

struct AutomationExecution: Identifiable {
    let id: UUID
    let ruleId: UUID
    let ruleName: String
    let trigger: SystemEvent
    let startTime: Date
    var endTime: Date?
    var status: ExecutionStatus = .running
    var conditionResults: [ConditionResult] = []
    var actionResults: [ActionResult] = []
    var failureReason: String?
    var error: Error?
}

enum ExecutionStatus {
    case running
    case completed
    case failed
    case conditionsNotMet
    case cancelled
}

struct ConditionResult {
    let condition: AutomationCondition
    let satisfied: Bool
    let evaluationTime: TimeInterval
    let details: [String: Any]
    let confidence: Double
}

struct ActionResult {
    let action: AutomationAction
    let success: Bool
    let executionTime: TimeInterval
    let details: [String: Any]
    let error: Error?
}

struct AutomationStatistics {
    let totalExecutions: Int
    let successfulExecutions: Int
    let failedExecutions: Int
    let successRate: Double
    let averageExecutionTime: TimeInterval
    let ruleEffectiveness: [UUID: Double]
    let lastUpdated: Date
}

struct WorkflowTemplate: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var steps: [WorkflowStep]
    var category: WorkflowCategory
    var isActive: Bool
    var createdAt: Date = Date()
}

struct WorkflowStep {
    let id: UUID
    var name: String
    var action: AutomationAction
    var conditions: [AutomationCondition]
    var order: Int
}

enum WorkflowCategory {
    case onboarding
    case scheduling
    case performance
    case compliance
    case custom
}

// Placeholder data structures
struct CoverageOption {
    let id: UUID
}

struct AutomationOptimizationResult {
    let success: Bool
    let details: [String: Any]
}

struct ScheduleAdjustment {
    let id: UUID
}

struct CostReport {
    let id: UUID
}

struct PreferenceViolation {
    let id: UUID
}

struct SwapMatch {
    let id: UUID
}

struct RiskFactor {
    let id: UUID
}

struct PreventionPlan {
    let id: UUID
}

struct SystemMetrics {
    let understaffingRisk: Double
    let employeeSatisfactionChange: Double
    let budgetVariance: Double
}