import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @AppStorage("appearance") private var appearance: String = "system" // system | light | dark
    @AppStorage("csvDelimiter") private var csvDelimiter: String = ","
    @AppStorage("openCSVInFinder") private var openCSVInFinder: Bool = true

    @State private var selectedDay: Weekday = .mon
    @State private var startHour: Int = 9
    @State private var endHour: Int = 17
    @State private var requiredStaff: Int = 2
    @State private var role: String = ""

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            shifts
                .tabItem { Label("Shifts", systemImage: "calendar.badge.clock") }
            export
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            advanced
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .padding()
    }

    // MARK: - Tabs

    private var general: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General").font(.title2).bold()

            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)

            Picker("Week starts on", selection: $store.settings.weekStart) {
                ForEach(Weekday.allCases, id: \.self) { d in Text(d.label).tag(d) }
            }
            .pickerStyle(.segmented)

            Spacer()
        }
    }

    private var shifts: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shift Templates").font(.title2).bold()

            HStack(spacing: 16) {
                Picker("Day", selection: $selectedDay) {
                    ForEach(Weekday.allCases, id: \.self) { d in Text(d.label).tag(d) }
                }
                Stepper("Start \(startHour):00", value: $startHour, in: 0...23)
                Stepper("End \(endHour):00", value: $endHour, in: 1...24)
                Stepper("Required: \(requiredStaff)", value: $requiredStaff, in: 1...50)
                TextField("Role (optional)", text: $role)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard endHour > startHour else { return }
                    let def = ShiftDefinition(
                        startHour: startHour,
                        endHour: endHour,
                        requiredStaff: requiredStaff,
                        role: role.isEmpty ? nil : role
                    )
                    store.settings.templates[selectedDay, default: []].append(def)
                    store.save()
                    role = ""
                }
            }

            if let defs = store.settings.templates[selectedDay], !defs.isEmpty {
                List {
                    ForEach(Array(defs.enumerated()), id: \.offset) { idx, d in
                        HStack {
                            Text("\(d.startHour):00–\(d.endHour):00")
                            Spacer()
                            Text("Req \(d.requiredStaff)")
                            if let r = d.role { Text("| \(r)") }
                        }
                    }
                    .onDelete { offsets in
                        store.settings.templates[selectedDay]?.remove(atOffsets: offsets)
                        store.save()
                    }
                }
                .frame(height: 220)
            } else {
                Text("No templates for \(selectedDay.label).")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var export: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export").font(.title2).bold()

            Picker("CSV delimiter", selection: $csvDelimiter) {
                Text("Comma (,)").tag(",")
                Text("Semicolon (;)").tag(";")
                Text("Tab (\\t)").tag("\t")
            }
            .pickerStyle(.segmented)

            Toggle("Reveal exported CSV in Finder", isOn: $openCSVInFinder)

            Spacer()
        }
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced").font(.title2).bold()
            Stepper("Minimum rest hours between shifts: \(store.settings.minRestHours)",
                    value: $store.settings.minRestHours,
                    in: 4...24)
                .onChange(of: store.settings.minRestHours) {
                    store.save()
                }
            Spacer()
        }
    }
}//
//  SettingsView.swift
//  Full Scope Scheduler
//
//  Created by Ryan Champion on 8/21/25.
//

