import SwiftUI

// MARK: - Color Palette
extension Color {
    public static let metroBlack = Color.black
    public static let metroCharcoal = Color(red: 0.08, green: 0.08, blue: 0.08) // Deep tile background
    public static let metroGray = Color(red: 0.18, green: 0.18, blue: 0.18) // Lighter tile/borders
    public static let metroLightGray = Color(red: 0.6, green: 0.6, blue: 0.6) // Subtext
    public static let metroSilver = Color(red: 0.9, green: 0.9, blue: 0.9) // Muted text/icons
    public static let metroWhite = Color.white // Primary text
    
    // Highlight colors (strictly grayscale)
    public static let metroReadHighlight = Color(red: 0.25, green: 0.25, blue: 0.25) // Subtle gray for active sentence background
    public static let metroWordHighlight = Color.white // Active word foreground
    public static let metroTextMuted = Color(red: 0.45, green: 0.45, blue: 0.45) // Unread sentence foreground
}

// MARK: - Typography Settings
public enum ReadingFont: String, CaseIterable, Identifiable {
    case system = "System Sans"
    case georgia = "Georgia"
    case courier = "Courier New"
    
    public var id: String { self.rawValue }
    
    public func font(size: CGFloat) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: .regular, design: .default)
        case .georgia:
            return .custom("Georgia", size: size)
        case .courier:
            return .custom("Courier New", size: size)
        }
    }
}

// MARK: - Modern Metro Tile Button Style
public struct MetroTileButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            // Organic, soft, deliberate animation mimicking Windows Phone tilt but softer for iOS 26
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Motion Settings
extension Animation {
    /// Soft, organic, deliberate animation for focus transitions. No bounce, no flash.
    public static var metroFocus: Animation {
        .easeInOut(duration: 0.4)
    }
    
    /// Soft transition for buttons and items appearing/disappearing
    public static var metroTransition: Animation {
        .easeOut(duration: 0.25)
    }
}

// MARK: - Environment Keys for Reading Style
public struct ReadingSettings {
    public var fontSize: CGFloat = 22.0
    public var lineSpacing: CGFloat = 8.0
    public var marginSize: CGFloat = 24.0
    public var fontStyle: ReadingFont = .georgia
}

// MARK: - String Extension for character index finding
extension String {
    public func rangeFromNSRange(_ nsRange: NSRange) -> Range<String.Index>? {
        guard nsRange.location != NSNotFound else { return nil }
        guard let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
              let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex) else { return nil }
        
        guard let from = String.Index(from16, within: self),
              let to = String.Index(to16, within: self) else { return nil }
        
        return from..<to
    }
}
