import SwiftUI

/// Advanced theme customization interface with live preview
struct ThemeCustomizationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedColorway: CustomColorway?
    @State private var isEditing = false
    @State private var previewColorway: CustomColorway?
    @State private var selectedCategory: ColorwayCategory = .system
    @State private var showingColorPicker = false
    @State private var editingColorProperty: String?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with theme categories and colorways
            ThemeSelectionSidebar(
                selectedCategory: $selectedCategory,
                selectedColorway: $selectedColorway,
                isEditing: $isEditing
            )
        } detail: {
            // Main customization area
            if let colorway = selectedColorway {
                ThemeCustomizationDetail(
                    colorway: colorway,
                    isEditing: $isEditing,
                    previewColorway: $previewColorway,
                    showingColorPicker: $showingColorPicker,
                    editingColorProperty: $editingColorProperty
                )
            } else {
                ThemeSelectionPlaceholder()
            }
        }
        .navigationTitle("Theme Customization")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .keyboardShortcut(.escape)
                } else {
                    Button("New Theme") {
                        createNewTheme()
                    }
                    
                    Button("Edit") {
                        startEditing()
                    }
                    .disabled(selectedColorway == nil)
                }
            }
        }
        .onAppear {
            if selectedColorway == nil {
                selectedColorway = themeManager.builtInColorways.first
            }
        }
    }
    
    private func saveChanges() {
        if let preview = previewColorway {
            themeManager.saveCustomColorway(preview)
            selectedColorway = preview
        }
        isEditing = false
        previewColorway = nil
    }
    
    private func cancelEditing() {
        isEditing = false
        previewColorway = nil
    }
    
    private func startEditing() {
        guard let colorway = selectedColorway else { return }
        previewColorway = colorway
        isEditing = true
    }
    
    private func createNewTheme() {
        let newColorway = themeManager.createCustomColorway(from: selectedColorway)
        selectedColorway = newColorway
        previewColorway = newColorway
        isEditing = true
    }
}

// MARK: - Sidebar

struct ThemeSelectionSidebar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedCategory: ColorwayCategory
    @Binding var selectedColorway: CustomColorway?
    @Binding var isEditing: Bool
    
    var body: some View {
        List {
            // Category picker
            Section("Categories") {
                ForEach(ColorwayCategory.allCases, id: \.self) { category in
                    CategoryRow(
                        category: category,
                        isSelected: selectedCategory == category
                    )
                    .onTapGesture {
                        selectedCategory = category
                        // Select first colorway in category
                        if let firstColorway = colorwaysForCategory(category).first {
                            selectedColorway = firstColorway
                        }
                    }
                }
            }
            
            // Built-in themes
            if !builtInThemes.isEmpty {
                Section("Built-in Themes") {
                    ForEach(builtInThemes, id: \.id) { colorway in
                        ColorwayRow(
                            colorway: colorway,
                            isSelected: selectedColorway?.id == colorway.id,
                            isPreview: false
                        )
                        .onTapGesture {
                            if !isEditing {
                                selectedColorway = colorway
                                themeManager.applyColorway(colorway)
                            }
                        }
                    }
                }
            }
            
            // Custom themes
            if !themeManager.customColorways.isEmpty {
                Section("Custom Themes") {
                    ForEach(customThemes, id: \.id) { colorway in
                        ColorwayRow(
                            colorway: colorway,
                            isSelected: selectedColorway?.id == colorway.id,
                            isPreview: false
                        )
                        .onTapGesture {
                            if !isEditing {
                                selectedColorway = colorway
                                themeManager.applyColorway(colorway)
                            }
                        }
                        .contextMenu {
                            Button("Duplicate") {
                                let duplicate = themeManager.createCustomColorway(from: colorway)
                                themeManager.saveCustomColorway(duplicate)
                            }
                            
                            Button("Delete", role: .destructive) {
                                themeManager.deleteCustomColorway(colorway)
                                if selectedColorway?.id == colorway.id {
                                    selectedColorway = themeManager.builtInColorways.first
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private var builtInThemes: [CustomColorway] {
        colorwaysForCategory(selectedCategory).filter { !$0.isCustom }
    }
    
    private var customThemes: [CustomColorway] {
        themeManager.customColorways.filter { 
            $0.category == selectedCategory || selectedCategory == .system 
        }
    }
    
    private func colorwaysForCategory(_ category: ColorwayCategory) -> [CustomColorway] {
        if category == .system {
            return themeManager.builtInColorways
        }
        return themeManager.builtInColorways.filter { $0.category == category }
    }
}

struct CategoryRow: View {
    let category: ColorwayCategory
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundStyle(isSelected ? .blue : .secondary)
                .frame(width: 20)
            
            Text(category.displayName)
                .fontWeight(isSelected ? .medium : .regular)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct ColorwayRow: View {
    let colorway: CustomColorway
    let isSelected: Bool
    let isPreview: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Color preview circles
            HStack(spacing: 4) {
                Circle()
                    .fill(colorway.primary)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(colorway.secondary)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(colorway.accent)
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(colorway.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .medium : .regular)
                
                if colorway.isCustom {
                    Text("Custom")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .opacity(isPreview ? 0.7 : 1.0)
    }
}

// MARK: - Detail View

struct ThemeCustomizationDetail: View {
    let colorway: CustomColorway
    @Binding var isEditing: Bool
    @Binding var previewColorway: CustomColorway?
    @Binding var showingColorPicker: Bool
    @Binding var editingColorProperty: String?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var currentColorway: CustomColorway {
        previewColorway ?? colorway
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with theme info
                ThemeHeaderCard(colorway: currentColorway)
                
                // Live preview
                ThemePreviewCard(colorway: currentColorway)
                
                if isEditing {
                    // Color editing interface
                    ColorEditingInterface(
                        colorway: Binding(
                            get: { previewColorway ?? colorway },
                            set: { previewColorway = $0 }
                        ),
                        showingColorPicker: $showingColorPicker,
                        editingColorProperty: $editingColorProperty
                    )
                }
                
                // Advanced options
                if isEditing {
                    AdvancedThemeOptions()
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .navigationTitle(currentColorway.name)
    }
}

struct ThemeHeaderCard: View {
    let colorway: CustomColorway
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(colorway.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(colorway.category.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Apply Theme") {
                        themeManager.applyColorway(colorway)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if !colorway.isCustom {
                        Button("Duplicate") {
                            // Create duplicate for editing
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // Color palette preview
            ColorPalettePreview(colorway: colorway)
        }
        .padding(20)
        .themedCard(themeManager, size: CGSize(width: 600, height: 200))
    }
}

struct ColorPalettePreview: View {
    let colorway: CustomColorway
    
    var body: some View {
        HStack(spacing: 12) {
            ColorSwatch(color: colorway.primary, label: "Primary")
            ColorSwatch(color: colorway.secondary, label: "Secondary")
            ColorSwatch(color: colorway.accent, label: "Accent")
            ColorSwatch(color: colorway.success, label: "Success")
            ColorSwatch(color: colorway.warning, label: "Warning")
            ColorSwatch(color: colorway.error, label: "Error")
        }
    }
}

struct ColorSwatch: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                )
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ThemePreviewCard: View {
    let colorway: CustomColorway
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Preview")
                .font(.headline)
                .foregroundStyle(colorway.text)
            
            // Mock UI elements using the theme
            VStack(spacing: 12) {
                // Mock toolbar
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorway.primary)
                        .frame(width: 60, height: 24)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorway.secondary)
                        .frame(width: 60, height: 24)
                    
                    Spacer()
                    
                    Circle()
                        .fill(colorway.accent)
                        .frame(width: 24, height: 24)
                }
                
                // Mock content cards
                HStack(spacing: 12) {
                    ForEach(0..<3) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorway.text)
                                .frame(height: 16)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorway.text.opacity(0.5))
                                .frame(height: 12)
                            
                            HStack {
                                Circle()
                                    .fill(colorway.success)
                                    .frame(width: 8, height: 8)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorway.text.opacity(0.3))
                                    .frame(width: 40, height: 8)
                            }
                        }
                        .padding(12)
                        .background(colorway.surface, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // Mock buttons
                HStack(spacing: 8) {
                    Text("Primary")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(colorway.primary, in: Capsule())
                    
                    Text("Secondary")
                        .font(.caption)
                        .foregroundStyle(colorway.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(colorway.secondary.opacity(0.2), in: Capsule())
                    
                    Text("Accent")
                        .font(.caption)
                        .foregroundStyle(colorway.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule()
                                .stroke(colorway.accent, lineWidth: 1)
                        )
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(colorway.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorway.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ColorEditingInterface: View {
    @Binding var colorway: CustomColorway
    @Binding var showingColorPicker: Bool
    @Binding var editingColorProperty: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Color Customization")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                ColorEditingRow(
                    title: "Primary",
                    color: Binding(
                        get: { colorway.primary },
                        set: { colorway.primary = $0 }
                    ),
                    isEditing: Binding(
                        get: { editingColorProperty == "primary" },
                        set: { if $0 { editingColorProperty = "primary" } else { editingColorProperty = nil } }
                    )
                )
                
                ColorEditingRow(
                    title: "Secondary",
                    color: Binding(
                        get: { colorway.secondary },
                        set: { colorway.secondary = $0 }
                    ),
                    isEditing: Binding(
                        get: { editingColorProperty == "secondary" },
                        set: { if $0 { editingColorProperty = "secondary" } else { editingColorProperty = nil } }
                    )
                )
                
                ColorEditingRow(
                    title: "Accent",
                    color: Binding(
                        get: { colorway.accent },
                        set: { colorway.accent = $0 }
                    ),
                    isEditing: Binding(
                        get: { editingColorProperty == "accent" },
                        set: { if $0 { editingColorProperty = "accent" } else { editingColorProperty = nil } }
                    )
                )
                
                ColorEditingRow(
                    title: "Background",
                    color: Binding(
                        get: { colorway.background },
                        set: { colorway.background = $0 }
                    ),
                    isEditing: Binding(
                        get: { editingColorProperty == "background" },
                        set: { if $0 { editingColorProperty = "background" } else { editingColorProperty = nil } }
                    )
                )
                
                ColorEditingRow(
                    title: "Success",
                    color: Binding(
                        get: { colorway.success },
                        set: { colorway.success = $0 }
                    ),
                    isEditing: Binding(
                        get: { editingColorProperty == "success" },
                        set: { if $0 { editingColorProperty = "success" } else { editingColorProperty = nil } }
                    )
                )
                
                ColorEditingRow(
                    title: "Error",
                    color: Binding(
                        get: { colorway.error },
                        set: { colorway.error = $0 }
                    ),
                    isEditing: Binding(
                        get: { editingColorProperty == "error" },
                        set: { if $0 { editingColorProperty = "error" } else { editingColorProperty = nil } }
                    )
                )
            }
        }
    }
}

struct ColorEditingRow: View {
    let title: String
    @Binding var color: Color
    @Binding var isEditing: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            ColorPicker(
                "",
                selection: $color,
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 40, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? .blue : .clear, lineWidth: 2)
        )
    }
}

struct AdvancedThemeOptions: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Options")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Animation Speed")
                    Spacer()
                    Picker("Animation Speed", selection: $themeManager.animationSpeed) {
                        ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Picker("Corner Radius", selection: $themeManager.cornerRadiusStyle) {
                        ForEach(CornerRadiusStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
                
                HStack {
                    Text("Font Scale")
                    Spacer()
                    Picker("Font Scale", selection: $themeManager.fontScale) {
                        ForEach(FontScale.allCases, id: \.self) { scale in
                            Text(scale.displayName).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
            }
        }
        .padding(20)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ThemeSelectionPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Select a Theme",
            systemImage: "paintbrush",
            description: Text("Choose a theme from the sidebar to customize or preview it")
        )
    }
}