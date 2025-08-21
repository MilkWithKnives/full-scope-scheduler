import Foundation

struct ScheduleGenerator {
    let employees: [Employee]
    let settings: ScheduleSettings

    func generate(weekOf: Date) -> Schedule {
        let calendar = Calendar.current
        let normalizedWeekStart = calendar.startOfDay(for: weekStart(base: weekOf, starting: settings.weekStart))

        // Build shifts from templates
        var shifts: [Shift] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: normalizedWeekStart) else { continue }
            let wd = weekday(from: day)
            let defs = settings.templates[wd] ?? []
            for def in defs {
                let start = calendar.date(bySettingHour: def.startHour, minute: 0, second: 0, of: day)!
                let end = calendar.date(bySettingHour: def.endHour, minute: 0, second: 0, of: day)!
                shifts.append(Shift(date: start, endDate: end, role: def.role, requiredStaff: def.requiredStaff, assignments: []))
            }
        }

        // State while assigning
        var hoursAssigned: [UUID: Int] = Dictionary(uniqueKeysWithValues: employees.map { ($0.id, 0) })
        var lastShiftEnd: [UUID: Date] = [:]
        var queue = employees

        func shiftHours(_ s: Shift) -> Int {
            Int(s.endDate.timeIntervalSince(s.date) / 3600.0)
        }

        func employeeIsEligible(_ emp: Employee, _ shift: Shift) -> Bool {
            // Role
            if let requiredRole = shift.role, !emp.roles.contains(requiredRole) { return false }

            // Availability
            let cal = Calendar.current
            let wd = weekday(from: shift.date)
            guard let ranges = emp.availability[wd], !ranges.isEmpty else { return false }
            let compsStart = cal.dateComponents([.hour, .minute], from: shift.date)
            let compsEnd   = cal.dateComponents([.hour, .minute], from: shift.endDate)
            guard ranges.contains(where: { r in
                let sOk = (r.start.hour ?? 0, r.start.minute ?? 0) <= (compsStart.hour ?? 0, compsStart.minute ?? 0)
                let eOk = (r.end.hour ?? 0, r.end.minute ?? 0)   >= (compsEnd.hour ?? 0, compsEnd.minute ?? 0)
                return sOk && eOk
            }) else { return false }

            // Max hours
            let projected = hoursAssigned[emp.id, default: 0] + shiftHours(shift)
            guard projected <= emp.maxHoursPerWeek else { return false }

            // Minimum rest
            if let lastEnd = lastShiftEnd[emp.id] {
                let hoursSinceLast = shift.date.timeIntervalSince(lastEnd) / 3600.0
                guard hoursSinceLast >= Double(settings.minRestHours) else { return false }
            }

            return true
        }

        // Fair round-robin assignment
        for i in shifts.indices {
            var needed = shifts[i].requiredStaff
            var passCount = 0
            while needed > 0 && passCount < queue.count * 2 {
                guard !queue.isEmpty else { break }
                let emp = queue.removeFirst()

                if employeeIsEligible(emp, shifts[i]) {
                    shifts[i].assignments.append(emp.id)
                    hoursAssigned[emp.id, default: 0] += shiftHours(shifts[i])
                    lastShiftEnd[emp.id] = shifts[i].endDate
                    needed -= 1
                }

                queue.append(emp)
                passCount += 1
            }
        }

        return Schedule(weekOf: normalizedWeekStart, shifts: shifts)
    }

    private func weekStart(base: Date, starting: Weekday) -> Date {
        let cal = Calendar.current
        let comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: base)
        let start = cal.date(from: comp)!
        if starting == .mon { return start }
        if starting == .sun { return cal.date(byAdding: .day, value: -1, to: start)! }
        let offset = starting.rawValue - Weekday.mon.rawValue
        return cal.date(byAdding: .day, value: offset, to: start)!
    }

    private func weekday(from date: Date) -> Weekday {
        let wd = Calendar.current.component(.weekday, from: date) // 1 = Sun
        return Weekday(rawValue: wd) ?? .mon
    }
}//
//  ScheduleGenerator.swift
//  Full Scope Scheduler
//
//  Created by Ryan Champion on 8/21/25.
//

