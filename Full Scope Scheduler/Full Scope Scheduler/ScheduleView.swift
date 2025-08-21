//import SwiftUI
import UniformTypeIdentifiers
import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: DataStore
    @State private var weekStart: Date = Calendar.current.startOfDay(for: Date())
    private let dragUTI = UTType.plainText.identifier

    var body: some View {
        HStack(spacing: 12) {
            // --- Roster ---
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Roster").font(.headline)
                    Spacer()
                }
                List(store.employees, id: \.id) { emp in
                    HStack {
                        Text(emp.name)
                        Spacer()
                        Text("\(emp.maxHoursPerWeek)h")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .onDrag { NSItemProvider(object: emp.id.uuidString as NSString) }
                    .help("Drag onto a shift to assign")
                }
            }
            .frame(width: 260)

            Divider()

            // --- Schedule Table ---
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    DatePicker("Week of", selection: $weekStart, displayedComponents: .date)
                    Button("Generate") { store.generateSchedule(forWeekOf: weekStart) }
                    Spacer()
                    Button("Export CSV") { store.exportCSV() }
                }

                if let sched = store.currentSchedule {
                    ScheduleTable(
                        schedule: Binding(
                            get: { sched },
                            set: { store.currentSchedule = $0; store.save() }
                        ),
                        employees: store.employees,
                        onRemoveAssignment: removeAssignment(_:from:),
                        onDropEmployee: dropEmployee(_:onto:)
                    )
                } else {
                    ContentUnavailableView(
                        "No schedule yet",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Pick a week and hit Generate.")
                    )
                }

                Spacer()
            }
        }
        .padding()
        .onAppear {
            weekStart = startOfWeek(for: Date(), starting: store.settings.weekStart)
        }
    }

    // MARK: - Helpers

    private func startOfWeek(for date: Date, starting: Weekday) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = (starting == .sun) ? 1 : 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }

    private func dropEmployee(_ empID: UUID, onto shiftID: UUID) {
        guard var sched = store.currentSchedule else { return }
        guard let sIdx = sched.shifts.firstIndex(where: { $0.id == shiftID }) else { return }

        if !sched.shifts[sIdx].assignments.contains(empID) &&
            sched.shifts[sIdx].assignments.count < sched.shifts[sIdx].requiredStaff {
            sched.shifts[sIdx].assignments.append(empID)
            store.currentSchedule = sched
            store.save()
        }
    }

    private func removeAssignment(_ empID: UUID, from shiftID: UUID) {
        guard var sched = store.currentSchedule else { return }
        guard let sIdx = sched.shifts.firstIndex(where: { $0.id == shiftID }) else { return }
        sched.shifts[sIdx].assignments.removeAll { $0 == empID }
        store.currentSchedule = sched
        store.save()
    }
}

struct ScheduleTable: View {
    @Binding var schedule: Schedule
    let employees: [Employee]
    let onRemoveAssignment: (UUID, UUID) -> Void
    let onDropEmployee: (UUID, UUID) -> Void

    private var nameLookup: [UUID: String] {
        Dictionary(uniqueKeysWithValues: employees.map { ($0.id, $0.name) })
    }


    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(dayGroups, id: \.day) { dayGroup in
                    dayView(for: dayGroup.day, shifts: dayGroup.shifts)
                }
            }
        }
    }
    
    private var dayGroups: [(day: Date, shifts: [Shift])] {
        let grouped = Dictionary(grouping: schedule.shifts) { shift in
            Calendar.current.startOfDay(for: shift.date)
        }
        let days = grouped.keys.sorted()
        return days.map { day in
            let shifts = (grouped[day] ?? []).sorted { $0.date < $1.date }
            return (day: day, shifts: shifts)
        }
    }
    
    private func dayView(for day: Date, shifts: [Shift]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDay(day)).font(.title3).bold()
            shiftTable(for: shifts)
        }
    }
    
    private func shiftTable(for shifts: [Shift]) -> some View {
        Table(shifts) {
            TableColumn("Start") { shift in 
                Text(time(shift.date))
            }
            TableColumn("End") { shift in 
                Text(time(shift.endDate))
            }
            TableColumn("Role") { shift in 
                Text(shift.role ?? "-")
            }
            TableColumn("Req") { shift in 
                Text("\(shift.requiredStaff)")
            }
            TableColumn("Status") { shift in 
                statusCell(for: shift)
            }
            TableColumn("Assigned") { shift in 
                assignedPills(for: shift)
            }
        }
        .frame(minHeight: 140)
    }

    // MARK: - Subcells

    private func assignedPills(for s: Shift) -> some View {
        let ids = s.assignments
        return HStack(spacing: 6) {
            if ids.isEmpty {
                Text("—").foregroundStyle(.secondary)
            } else {
                ForEach(ids, id: \.self) { eid in
                    HStack(spacing: 6) {
                        Text(nameLookup[eid] ?? "Unknown")
                        Button {
                            onRemoveAssignment(eid, s.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                }
            }
        }
    }

    private func statusCell(for s: Shift) -> some View {
        HStack {
            Image(systemName: s.coverageStatus.symbol)
                .foregroundStyle(s.coverageStatus.color)
            Text(s.coverageStatus.label)
                .foregroundStyle(s.coverageStatus.color)
        }
    }

    private func formatDay(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "EEEE, MMM d"; return df.string(from: d)
    }
    private func time(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "h:mm a"; return df.string(from: d)
    }
}//  ScheduleView.swift
//  Full Scope Scheduler
//
//  Created by Ryan Champion on 8/21/25.
//

