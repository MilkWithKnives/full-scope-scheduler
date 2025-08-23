import Foundation
import SwiftUI

struct Employee: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var maxHoursPerWeek: Int = 40
    var roles: [String] = []
    var availability: [Weekday: [TimeRange]] = [:]
    
    init(name: String, maxHoursPerWeek: Int = 40, roles: [String] = []) {
        self.id = UUID()
        self.name = name
        self.maxHoursPerWeek = maxHoursPerWeek
        self.roles = roles
        
        // Initialize availability with empty arrays for each day
        for day in Weekday.allCases {
            self.availability[day] = []
        }
    }
}

enum Weekday: Int, CaseIterable, Codable, Hashable {
    case sun = 1, mon, tue, wed, thu, fri, sat
    var label: String {
        switch self {
        case .sun: return "Sun"
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        }
    }
}

struct TimeRange: Codable, Hashable {
    var start: DateComponents // hour/minute
    var end: DateComponents   // hour/minute
}

struct ShiftDefinition: Codable {
    var startHour: Int
    var endHour: Int
    var requiredStaff: Int
    var role: String?
}

struct ScheduleSettings: Codable {
    var weekStart: Weekday = .mon
    var templates: [Weekday: [ShiftDefinition]] = [:]
    var defaultShiftLengthHours: Int = 8
    /// Minimum rest between two shifts (hours).
    var minRestHours: Int = 10
    
    init() {
        self.weekStart = .mon
        self.defaultShiftLengthHours = 8
        self.minRestHours = 10
        
        // Initialize templates with default shifts for each day
        for day in Weekday.allCases {
            self.templates[day] = [ShiftDefinition(startHour: 9, endHour: 17, requiredStaff: 2, role: nil)]
        }
    }
}

struct Shift: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var endDate: Date
    var role: String?
    var requiredStaff: Int
    var assignments: [UUID] = []
}

struct Schedule: Codable {
    var weekOf: Date
    var shifts: [Shift]
}

extension Shift {
    enum CoverageStatus {
        case empty, partial, full, over
        var label: String {
            switch self {
            case .empty: return "Uncovered"
            case .partial: return "Understaffed"
            case .full: return "Covered"
            case .over: return "Overstaffed"
            }
        }
        var color: Color {
            switch self {
            case .empty: return .red
            case .partial: return .orange
            case .full: return .green
            case .over: return .blue
            }
        }
        var symbol: String {
            switch self {
            case .empty: return "xmark.octagon.fill"
            case .partial: return "exclamationmark.triangle.fill"
            case .full: return "checkmark.circle.fill"
            case .over: return "person.3.fill"
            }
        }
    }
    var coverageStatus: CoverageStatus {
        if assignments.isEmpty { return .empty }
        if assignments.count < requiredStaff { return .partial }
        if assignments.count == requiredStaff { return .full }
        return .over
    }
}//
//  Models.swift
//  Full Scope Scheduler
//
//  Created by Ryan Champion on 8/21/25.
//

