import Foundation
import SwiftUI

@MainActor
final class DataStore: ObservableObject {
    @Published var employees: [Employee] = []
    @Published var settings = ScheduleSettings()
    @Published var currentSchedule: Schedule?

    private let saveURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("FullScopeScheduler", conformingTo: .folder)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("store.json")
    }()

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        do {
            let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
            employees = decoded.employees
            settings = decoded.settings
            currentSchedule = decoded.currentSchedule
        } catch { print("Load error: \(error)") }
    }

    func save() {
        do {
            let snap = Snapshot(employees: employees, settings: settings, currentSchedule: currentSchedule)
            let data = try JSONEncoder().encode(snap)
            try data.write(to: saveURL, options: .atomic)
        } catch { print("Save error: \(error)") }
    }

    func generateSchedule(forWeekOf weekStart: Date) {
        let gen = ScheduleGenerator(employees: employees, settings: settings)
        let schedule = gen.generate(weekOf: weekStart)
        currentSchedule = schedule
        save()
    }

    func exportCSV() {
        guard let sched = currentSchedule else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        let delimiter = UserDefaults.standard.string(forKey: "csvDelimiter") ?? ","
        let openInFinder = UserDefaults.standard.object(forKey: "openCSVInFinder") as? Bool ?? true

        let headers = ["Date","End","Role","Required","Assigned Names","Status"]
        let headerLine = headers.joined(separator: delimiter)

        let map = Dictionary(uniqueKeysWithValues: employees.map { ($0.id, $0.name) })
        var lines = [headerLine]

        for s in sched.shifts.sorted(by: { $0.date < $1.date }) {
            let names = s.assignments.compactMap { map[$0] }.joined(separator: " | ")
            let row = [
                df.string(from: s.date),
                df.string(from: s.endDate),
                s.role ?? "",
                "\(s.requiredStaff)",
                names,
                s.coverageStatus.label
            ].joined(separator: delimiter)
            lines.append(row)
        }

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Schedule.csv")
        do {
            try csv.data(using: .utf8)!.write(to: url, options: .atomic)
            if openInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch { print("CSV export failed: \(error)") }
    }

    private struct Snapshot: Codable {
        var employees: [Employee]
        var settings: ScheduleSettings
        var currentSchedule: Schedule?
    }
}//
//  DataStore.swift
//  Full Scope Scheduler
//
//  Created by Ryan Champion on 8/21/25.
//

