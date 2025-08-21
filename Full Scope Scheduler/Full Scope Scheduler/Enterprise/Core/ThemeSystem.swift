import SwiftUI
import Combine

/// Advanced theming system with custom colorways and dynamic styling
@MainActor
class ThemeManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme = .defaultTheme
    @Published var customColorways: [CustomColorway] = []
    @Published var accentColor: Color = .blue
    @Published var useSystemAppearance: Bool = true
    @Published var animationSpeed: AnimationSpeed = .normal
    @Published var cornerRadiusStyle: CornerRadiusStyle = .medium
    @Published var fontScale: FontScale = .normal
    
    // MARK: - Theme Configuration
    private let userDefaults = UserDefaults.standard
    private let themeKey = "selectedTheme"
    private let customColorsKey = "customColorways"
    
    // Predefined professional colorways
    let builtInColorways: [CustomColorway] = [
        // Tech/Modern Themes
        CustomColorway(
            id: "ocean_blue",
            name: "Ocean Blue",
            category: .modern,
            primary: Color(red: 0.0, green: 0.4, blue: 0.8),
            secondary: Color(red: 0.2, green: 0.6, blue: 0.9),
            accent: Color(red: 0.0, green: 0.7, blue: 1.0),
            background: Color(red: 0.95, green: 0.97, blue: 1.0),
            surface: Color.white,
            text: Color(red: 0.1, green: 0.1, blue: 0.1),
            success: Color(red: 0.0, green: 0.7, blue: 0.4),
            warning: Color(red: 1.0, green: 0.6, blue: 0.0),
            error: Color(red: 0.9, green: 0.2, blue: 0.2)
        ),
        
        CustomColorway(
            id: "forest_green",
            name: "Forest Green",
            category: .nature,
            primary: Color(red: 0.2, green: 0.6, blue: 0.3),
            secondary: Color(red: 0.4, green: 0.7, blue: 0.4),
            accent: Color(red: 0.1, green: 0.8, blue: 0.4),
            background: Color(red: 0.97, green: 0.99, blue: 0.97),
            surface: Color.white,
            text: Color(red: 0.1, green: 0.2, blue: 0.1),
            success: Color(red: 0.2, green: 0.8, blue: 0.3),
            warning: Color(red: 0.9, green: 0.7, blue: 0.2),
            error: Color(red: 0.8, green: 0.3, blue: 0.3)
        ),
        
        // Professional Themes
        CustomColorway(
            id: "midnight_purple",
            name: "Midnight Purple",
            category: .professional,
            primary: Color(red: 0.4, green: 0.2, blue: 0.8),
            secondary: Color(red: 0.5, green: 0.4, blue: 0.9),
            accent: Color(red: 0.6, green: 0.3, blue: 1.0),
            background: Color(red: 0.98, green: 0.96, blue: 1.0),
            surface: Color.white,
            text: Color(red: 0.1, green: 0.1, blue: 0.2),
            success: Color(red: 0.3, green: 0.7, blue: 0.4),
            warning: Color(red: 0.9, green: 0.6, blue: 0.1),
            error: Color(red: 0.9, green: 0.2, blue: 0.3)
        ),
        
        CustomColorway(
            id: "slate_gray",
            name: "Slate Gray",
            category: .minimal,
            primary: Color(red: 0.4, green: 0.5, blue: 0.6),
            secondary: Color(red: 0.5, green: 0.6, blue: 0.7),
            accent: Color(red: 0.3, green: 0.5, blue: 0.8),
            background: Color(red: 0.98, green: 0.98, blue: 0.99),
            surface: Color.white,
            text: Color(red: 0.2, green: 0.2, blue: 0.3),
            success: Color(red: 0.4, green: 0.7, blue: 0.5),
            warning: Color(red: 0.8, green: 0.6, blue: 0.2),
            error: Color(red: 0.8, green: 0.3, blue: 0.3)
        ),
        
        // Warm Themes
        CustomColorway(
            id: "sunset_orange",
            name: "Sunset Orange",
            category: .warm,
            primary: Color(red: 0.9, green: 0.4, blue: 0.1),
            secondary: Color(red: 1.0, green: 0.5, blue: 0.2),
            accent: Color(red: 1.0, green: 0.6, blue: 0.0),
            background: Color(red: 1.0, green: 0.98, blue: 0.95),
            surface: Color.white,
            text: Color(red: 0.2, green: 0.1, blue: 0.1),
            success: Color(red: 0.3, green: 0.8, blue: 0.4),
            warning: Color(red: 0.9, green: 0.7, blue: 0.1),
            error: Color(red: 0.9, green: 0.2, blue: 0.2)
        ),
        
        // High Contrast for Accessibility
        CustomColorway(
            id: "high_contrast",
            name: "High Contrast",
            category: .accessibility,
            primary: Color.black,
            secondary: Color(red: 0.2, green: 0.2, blue: 0.2),
            accent: Color.blue,
            background: Color.white,
            surface: Color(red: 0.98, green: 0.98, blue: 0.98),
            text: Color.black,
            success: Color(red: 0.0, green: 0.6, blue: 0.0),
            warning: Color(red: 0.8, green: 0.5, blue: 0.0),
            error: Color(red: 0.8, green: 0.0, blue: 0.0)
        )
    ]
    
    init() {
        loadTheme()
        loadCustomColorways()
    }
    
    // MARK: - Theme Management
    
    func applyTheme(_ theme: AppTheme) {
        withAnimation(.smooth(duration: 0.3)) {
            currentTheme = theme
            saveTheme()
        }
    }
    
    func applyColorway(_ colorway: CustomColorway) {
        let theme = AppTheme(
            id: colorway.id,
            name: colorway.name,
            colorway: colorway,
            appearance: useSystemAppearance ? .auto : .light
        )
        applyTheme(theme)
    }
    
    func createCustomColorway(from template: CustomColorway? = nil) -> CustomColorway {
        let base = template ?? builtInColorways.first!
        var custom = base
        custom.id = UUID().uuidString
        custom.name = "Custom Theme \(customColorways.count + 1)"
        custom.isCustom = true
        return custom
    }
    
    func saveCustomColorway(_ colorway: CustomColorway) {
        if let index = customColorways.firstIndex(where: { $0.id == colorway.id }) {
            customColorways[index] = colorway
        } else {
            customColorways.append(colorway)
        }
        saveCustomColorways()
    }
    
    func deleteCustomColorway(_ colorway: CustomColorway) {
        customColorways.removeAll { $0.id == colorway.id }
        saveCustomColorways()
    }
    
    // MARK: - Advanced Styling
    
    func dynamicRadius(for size: CGSize) -> CGFloat {
        let baseRadius: CGFloat
        switch cornerRadiusStyle {
        case .sharp: baseRadius = 4
        case .medium: baseRadius = 8
        case .rounded: baseRadius = 16
        case .pill: return min(size.width, size.height) / 2
        }
        
        // Scale radius based on size
        let scaleFactor = min(size.width, size.height) / 100
        return baseRadius * max(0.5, min(2.0, scaleFactor))
    }
    
    func animationDuration(_ type: AnimationType) -> Double {
        let baseSpeed = animationSpeed.multiplier
        switch type {
        case .quick: return 0.15 * baseSpeed
        case .normal: return 0.3 * baseSpeed
        case .slow: return 0.5 * baseSpeed
        case .springy: return 0.6 * baseSpeed
        }
    }
    
    func springAnimation(_ type: AnimationType = .normal) -> Animation {
        .spring(
            response: animationDuration(type),
            dampingFraction: 0.8,
            blendDuration: 0.1
        )
    }
    
    // MARK: - Color Utilities
    
    func color(for semantic: SemanticColor) -> Color {
        switch semantic {
        case .primary: return currentTheme.colorway.primary
        case .secondary: return currentTheme.colorway.secondary
        case .accent: return currentTheme.colorway.accent
        case .background: return currentTheme.colorway.background
        case .surface: return currentTheme.colorway.surface
        case .text: return currentTheme.colorway.text
        case .textSecondary: return currentTheme.colorway.text.opacity(0.7)
        case .success: return currentTheme.colorway.success
        case .warning: return currentTheme.colorway.warning
        case .error: return currentTheme.colorway.error
        case .destructive: return currentTheme.colorway.error
        }
    }
    
    func gradientBackground() -> LinearGradient {
        LinearGradient(
            colors: [
                currentTheme.colorway.background,
                currentTheme.colorway.background.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    func cardMaterial() -> Material {
        switch currentTheme.appearance {
        case .light: return .ultraThinMaterial
        case .dark: return .thickMaterial
        case .auto: return .regularMaterial
        }
    }
    
    // MARK: - Persistence
    
    private func saveTheme() {
        if let data = try? JSONEncoder().encode(currentTheme) {
            userDefaults.set(data, forKey: themeKey)
        }
    }
    
    private func loadTheme() {
        if let data = userDefaults.data(forKey: themeKey),
           let theme = try? JSONDecoder().decode(AppTheme.self, from: data) {
            currentTheme = theme
        }
    }
    
    private func saveCustomColorways() {
        if let data = try? JSONEncoder().encode(customColorways) {
            userDefaults.set(data, forKey: customColorsKey)
        }
    }
    
    private func loadCustomColorways() {
        if let data = userDefaults.data(forKey: customColorsKey),
           let colorways = try? JSONDecoder().decode([CustomColorway].self, from: data) {
            customColorways = colorways
        }
    }
}

// MARK: - Data Models

struct AppTheme: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var colorway: CustomColorway
    var appearance: ThemeAppearance
    
    static let defaultTheme = AppTheme(
        id: "default",
        name: "Default",
        colorway: CustomColorway.defaultColorway,
        appearance: .auto
    )
}

struct CustomColorway: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: ColorwayCategory
    var isCustom: Bool = false
    
    // Core Colors
    var primary: Color
    var secondary: Color
    var accent: Color
    var background: Color
    var surface: Color
    var text: Color
    
    // Semantic Colors
    var success: Color
    var warning: Color
    var error: Color
    
    // Advanced Colors
    var highlight: Color { accent.opacity(0.1) }
    var border: Color { text.opacity(0.2) }
    var disabled: Color { text.opacity(0.3) }
    
    static let defaultColorway = CustomColorway(
        id: "default",
        name: "Default",
        category: .system,
        primary: .blue,
        secondary: .gray,
        accent: .blue,
        background: Color(.systemBackground),
        surface: Color(.controlBackgroundColor),
        text: Color(.labelColor),
        success: .green,
        warning: .orange,
        error: .red
    )
}

enum ColorwayCategory: String, Codable, CaseIterable {
    case system = "system"
    case modern = "modern"
    case professional = "professional"
    case nature = "nature"
    case warm = "warm"
    case cool = "cool"
    case minimal = "minimal"
    case accessibility = "accessibility"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .modern: return "Modern"
        case .professional: return "Professional"
        case .nature: return "Nature"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .minimal: return "Minimal"
        case .accessibility: return "Accessibility"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gearshape"
        case .modern: return "sparkles"
        case .professional: return "briefcase"
        case .nature: return "leaf"
        case .warm: return "sun.max"
        case .cool: return "snowflake"
        case .minimal: return "minus.circle"
        case .accessibility: return "accessibility"
        }
    }
}

enum ThemeAppearance: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

enum SemanticColor {
    case primary, secondary, accent
    case background, surface
    case text, textSecondary
    case success, warning, error, destructive
}

enum AnimationSpeed: String, Codable, CaseIterable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"
    
    var displayName: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .slow: return 1.5
        case .normal: return 1.0
        case .fast: return 0.7
        }
    }
}

enum CornerRadiusStyle: String, Codable, CaseIterable {
    case sharp = "sharp"
    case medium = "medium"
    case rounded = "rounded"
    case pill = "pill"
    
    var displayName: String {
        switch self {
        case .sharp: return "Sharp"
        case .medium: return "Medium"
        case .rounded: return "Rounded"
        case .pill: return "Pill"
        }
    }
}

enum FontScale: String, Codable, CaseIterable {
    case small = "small"
    case normal = "normal"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .normal: return "Normal"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .small: return 0.9
        case .normal: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        }
    }
}

enum AnimationType {
    case quick, normal, slow, springy
}

// MARK: - View Extensions

extension View {
    func themedBackground(_ themeManager: ThemeManager) -> some View {
        background(themeManager.gradientBackground())
    }
    
    func themedCard(_ themeManager: ThemeManager, size: CGSize = CGSize(width: 200, height: 100)) -> some View {
        background(
            RoundedRectangle(cornerRadius: themeManager.dynamicRadius(for: size))
                .fill(themeManager.cardMaterial())
                .overlay(
                    RoundedRectangle(cornerRadius: themeManager.dynamicRadius(for: size))
                        .stroke(themeManager.color(for: .border), lineWidth: 0.5)
                )
        )
    }
    
    func themedButton(
        _ themeManager: ThemeManager,
        style: ThemedButtonStyle = .primary
    ) -> some View {
        ThemedButtonModifier(themeManager: themeManager, style: style)
    }
    
    func themedText(
        _ themeManager: ThemeManager,
        semantic: SemanticColor = .text
    ) -> some View {
        foregroundStyle(themeManager.color(for: semantic))
    }
    
    func themedAnimation(
        _ themeManager: ThemeManager,
        type: AnimationType = .normal
    ) -> some View {
        animation(themeManager.springAnimation(type), value: UUID())
    }
    
    func dynamicTypeSize(_ themeManager: ThemeManager) -> some View {
        scaleEffect(themeManager.fontScale.scale)
    }
}

// MARK: - Custom View Modifiers

struct ThemedButtonModifier: ViewModifier {
    let themeManager: ThemeManager
    let style: ThemedButtonStyle
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: themeManager.dynamicRadius(for: CGSize(width: 120, height: 36)))
                    .fill(backgroundColorForStyle())
                    .overlay(
                        RoundedRectangle(cornerRadius: themeManager.dynamicRadius(for: CGSize(width: 120, height: 36)))
                            .stroke(borderColorForStyle(), lineWidth: style == .outline ? 1 : 0)
                    )
            )
            .foregroundStyle(textColorForStyle())
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? -0.1 : 0)
            .animation(themeManager.springAnimation(.quick), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { isPressing in
                isPressed = isPressing
            } perform: {}
    }
    
    private func backgroundColorForStyle() -> Color {
        switch style {
        case .primary:
            return themeManager.color(for: .primary)
        case .secondary:
            return themeManager.color(for: .secondary)
        case .outline:
            return Color.clear
        case .destructive:
            return themeManager.color(for: .error)
        case .ghost:
            return themeManager.color(for: .accent).opacity(0.1)
        }
    }
    
    private func textColorForStyle() -> Color {
        switch style {
        case .primary, .destructive:
            return Color.white
        case .secondary:
            return themeManager.color(for: .text)
        case .outline:
            return themeManager.color(for: .primary)
        case .ghost:
            return themeManager.color(for: .accent)
        }
    }
    
    private func borderColorForStyle() -> Color {
        switch style {
        case .outline:
            return themeManager.color(for: .primary)
        default:
            return Color.clear
        }
    }
}

enum ThemedButtonStyle {
    case primary, secondary, outline, destructive, ghost
}

// MARK: - Environment Values

struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - Color Extensions for Codable

extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let alpha = try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1.0
        
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Extract RGB values (simplified - in production you'd use proper color space conversion)
        let uiColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        try container.encode(Double(red), forKey: .red)
        try container.encode(Double(green), forKey: .green)
        try container.encode(Double(blue), forKey: .blue)
        try container.encode(Double(alpha), forKey: .alpha)
    }
}