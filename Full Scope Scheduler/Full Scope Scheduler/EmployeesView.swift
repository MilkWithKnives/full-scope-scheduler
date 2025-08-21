import SwiftUI

struct EmployeesView: View {
    @EnvironmentObject var store: DataStore
    @State private var newName: String = ""

    var body: some View {
        HStack(spacing: 16) {
            // Employees list
            List {
                ForEach(store.employees) { emp in
                    NavigationLink(destination: EmployeeEditorView(employeeID: emp.id)) {
                        VStack(alignment: .leading) {
                            Text(emp.name).font(.headline)
                            Text("Max \(emp.maxHoursPerWeek) hrs/week")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .frame(minWidth: 300)
            .listStyle(.inset)

            // Add panel
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Employee").font(.headline)
                TextField("Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let n = newName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    store.employees.append(Employee(name: n))
                    newName = ""
                    store.save()
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
            }
            .padding()
        }
        .padding()
    }

    private func delete(at offsets: IndexSet) {
        store.employees.remove(atOffsets: offsets)
        store.save()
    }
}

struct EmployeeEditorView: View {
    @EnvironmentObject var store: DataStore
    let employeeID: UUID

    var body: some View {
        if let idx = store.employees.firstIndex(where: { $0.id == employeeID }) {
            EmployeeForm(employee: $store.employees[idx])
                .padding()
                .onDisappear { store.save() }
        } else {
            Text("Employee not found")
        }
    }
}

struct EmployeeForm: View {
    @Binding var employee: Employee
    @State private var roleInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Employee name", text: $employee.name)
                .textFieldStyle(.roundedBorder)

            Stepper("Max hours/week: \(employee.maxHoursPerWeek)",
                    value: $employee.maxHoursPerWeek, in: 1...80)

            HStack {
                TextField("Add role (optional)", text: $roleInput)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let r = roleInput.trimmingCharacters(in: .whitespaces)
                    guard !r.isEmpty else { return }
                    if !employee.roles.contains(r) { employee.roles.append(r) }
                    roleInput = ""
                }
            }

            if !employee.roles.isEmpty {
                WrapChips(items: employee.roles) { role in
                    if let i = employee.roles.firstIndex(of: role) {
                        employee.roles.remove(at: i)
                    }
                }
            }

            Divider()
            AvailabilityEditor(availability: $employee.availability)
            Spacer()
        }
    }
}

struct WrapChips: View {
    let items: [String]
    var onRemove: (String) -> Void

    var body: some View {
        FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Text(item)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                    Button {
                        onRemove(item)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            }
        }
    }
}

struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> Content

    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo.size)
        }
        .frame(height: 100)
    }

    private func generateContent(in size: CGSize) -> some View {
        var x: CGFloat = 0
        var y: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content().background(
                GeometryReader { child in
                    Color.clear.onAppear {
                        let w = child.size.width + spacing
                        if x + w > size.width {
                            x = 0
                            y += child.size.height + spacing
                        }
                        x += w
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, y)
    }
}

struct AvailabilityEditor: View {
    @Binding var availability: [Weekday: [TimeRange]]
    @State private var editingDay: Weekday = .mon
    @State private var startHour: Int = 9
    @State private var endHour: Int = 17

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Availability").font(.headline)

            Picker("Day", selection: $editingDay) {
                ForEach(Weekday.allCases, id: \.self) { d in Text(d.label).tag(d) }
            }
            .pickerStyle(.segmented)

            HStack {
                Stepper("Start: \(startHour):00", value: $startHour, in: 0...23)
                Stepper("End: \(endHour):00", value: $endHour, in: 1...24)
                Spacer()
                Button("Add Range") {
                    guard endHour > startHour else { return }
                    let r = TimeRange(start: DateComponents(hour: startHour),
                                      end: DateComponents(hour: endHour))
                    availability[editingDay, default: []].append(r)
                }
            }

            if let ranges = availability[editingDay], !ranges.isEmpty {
                List {
                    ForEach(Array(ranges.enumerated()), id: \.offset) { idx, r in
                        Text("\(fmt(r.start)) – \(fmt(r.end))")
                    }
                    .onDelete { offsets in
                        availability[editingDay]?.remove(atOffsets: offsets)
                    }
                }
                .frame(height: 140)
            } else {
                Text("No ranges for \(editingDay.label).")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fmt(_ dc: DateComponents) -> String {
        let hr = dc.hour ?? 0
        let mn = dc.minute ?? 0
        return String(format: "%02d:%02d", hr, mn)
    }
}//
//  EmployeesView.swift
//  Full Scope Scheduler
//
//  Created by Ryan Champion on 8/21/25.
//

