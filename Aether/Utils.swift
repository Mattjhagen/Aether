import SwiftUI

// MARK: - Color Palette
extension Color {
    public static let metroBlack = Color.black
    public static let metroCharcoal = Color(red: 0.08, green: 0.08, blue: 0.08) // Deep tile background
    public static let metroGray = Color(red: 0.18, green: 0.18, blue: 0.18) // Lighter tile/borders
    public static let metroLightGray = Color(red: 0.6, green: 0.6, blue: 0.6) // Subtext
    public static let metroSilver = Color(red: 0.9, green: 0.9, blue: 0.9) // Muted text/icons
    public static let metroWhite = Color.white // Primary text
    
    // Highlight colors (grayscale)
    public static let metroReadHighlight = Color(red: 0.25, green: 0.25, blue: 0.25)
    public static let metroWordHighlight = Color.white
    public static let metroTextMuted = Color(red: 0.45, green: 0.45, blue: 0.45)
}

// MARK: - Typography Settings
public enum ReadingFont: String, CaseIterable, Identifiable {
    case system = "System Sans"
    case georgia = "Georgia"
    case charter = "Charter"
    case palatino = "Palatino"
    case baskerville = "Baskerville"
    case iowan = "Iowan Old Style"
    case avenir = "Avenir Next"
    case courier = "Courier New"
    case mono = "Mono"
    
    public var id: String { self.rawValue }
    
    public var fontName: String? {
        switch self {
        case .system: return nil
        case .georgia: return "Georgia"
        case .charter: return "Charter-Roman"
        case .palatino: return "Palatino-Roman"
        case .baskerville: return "Baskerville"
        case .iowan: return "IowanOldStyle-Roman"
        case .avenir: return "AvenirNext-Regular"
        case .courier: return "CourierNewPSMT"
        case .mono: return "Courier"
        }
    }
    
    public func font(size: CGFloat) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: .regular, design: .default)
        case .mono:
            return .system(size: size, weight: .regular, design: .monospaced)
        default:
            if let name = self.fontName {
                return .custom(name, size: size)
            }
            return .system(size: size)
        }
    }
}

// MARK: - Layout Alignments & Letter Spacing (Tracking)
public enum ReadingAlignment: String, CaseIterable, Identifiable {
    case leading = "Left"
    case center = "Center"
    case trailing = "Right"
    
    public var id: String { self.rawValue }
    
    public var multilineAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

public enum ReadingTracking: String, CaseIterable, Identifiable {
    case tight = "Tight"
    case normal = "Normal"
    case loose = "Loose"
    case wide = "Wide"
    
    public var id: String { self.rawValue }
    
    public var value: CGFloat {
        switch self {
        case .tight: return -0.4
        case .normal: return 0.0
        case .loose: return 0.8
        case .wide: return 1.6
        }
    }
}

// MARK: - Reader Backdrops (Grayscale themes)
public enum ReaderBackdrop: String, CaseIterable, Identifiable {
    case midnight = "Midnight"
    case charcoal = "Charcoal"
    case slate = "Slate"
    
    public var id: String { self.rawValue }
    
    public var backgroundColor: Color {
        switch self {
        case .midnight:
            return .black
        case .charcoal:
            return Color(red: 0.09, green: 0.09, blue: 0.09) // `#171717`
        case .slate:
            return Color(red: 0.88, green: 0.88, blue: 0.88) // `#E0E0E0` (Slate light gray)
        }
    }
    
    public var primaryTextColor: Color {
        switch self {
        case .midnight, .charcoal:
            return .white
        case .slate:
            return Color(red: 0.08, green: 0.08, blue: 0.08) // `#141414`
        }
    }
    
    public var secondaryTextColor: Color {
        switch self {
        case .midnight, .charcoal:
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        case .slate:
            return Color(red: 0.42, green: 0.42, blue: 0.42) // Charcoal subtext
        }
    }
    
    public var panelBackgroundColor: Color {
        switch self {
        case .midnight:
            return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .charcoal:
            return Color(red: 0.14, green: 0.14, blue: 0.14)
        case .slate:
            return Color(red: 0.94, green: 0.94, blue: 0.95) // Lighter grey panel for slate
        }
    }
    
    public var borderColor: Color {
        switch self {
        case .midnight:
            return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .charcoal:
            return Color(red: 0.25, green: 0.25, blue: 0.25)
        case .slate:
            return Color(red: 0.72, green: 0.72, blue: 0.72) // Muted darker border for slate
        }
    }
    
    public var activeWordHighlightColor: Color {
        switch self {
        case .midnight, .charcoal:
            return .white
        case .slate:
            return .black
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
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Motion Settings
extension Animation {
    public static var metroFocus: Animation {
        .easeInOut(duration: 0.4)
    }
    
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
    public var alignment: ReadingAlignment = .leading
    public var tracking: ReadingTracking = .normal
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
