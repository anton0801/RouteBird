//
//  Theme.swift
//  BirdRoand
//
//  Design system: colors, fonts, spacing, gradients, shadows.
//  All colors are dynamic (light/dark) via UIColor trait providers so the
//  whole app recolors when the user flips the theme in Settings.
//

import SwiftUI

// MARK: - Hex helpers

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    /// Builds a dynamic color that resolves differently in light vs dark mode.
    static func dynamic(light: UInt, dark: UInt) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }
}

// MARK: - Palette

enum AppColor {
    // Backgrounds
    static let base       = Color(UIColor.dynamic(light: 0xFFFBF2, dark: 0x161310))
    static let depth      = Color(UIColor.dynamic(light: 0xFBF1DC, dark: 0x211C16))
    static let card       = Color(UIColor.dynamic(light: 0xFFFFFF, dark: 0x2A241D))
    static let cardHover  = Color(UIColor.dynamic(light: 0xFFFBF2, dark: 0x322B22))
    static let border     = Color(UIColor.dynamic(light: 0xEEDFC2, dark: 0x3D3528))

    // Brand — delivery blue (stays vivid in both modes)
    static let primary    = Color(hex: 0x2563EB)
    static let primaryActive = Color(hex: 0x1D4ED8)
    static let primarySoft = Color(hex: 0x60A5FA)

    // Accents
    static let yolk       = Color(hex: 0xF59E0B)
    static let coral      = Color(hex: 0xFB7185)

    // Status
    static let success    = Color(hex: 0x22C55E)   // delivered / paid
    static let planned    = Color(hex: 0x2563EB)   // in plan
    static let warn       = Color(hex: 0xF59E0B)   // debt / low
    static let danger     = Color(hex: 0xEF4444)   // cancel / defect

    // Text
    static let textPrimary   = Color(UIColor.dynamic(light: 0x3A2E12, dark: 0xF4ECDD))
    static let textSecondary = Color(UIColor.dynamic(light: 0x6E5A30, dark: 0xC2B49A))
    static let textInactive  = Color(UIColor.dynamic(light: 0xA89468, dark: 0x8A7C63))
    static let onPrimary     = Color.white
    static let onSecondary   = Color(UIColor.dynamic(light: 0x4A3A12, dark: 0xF4ECDD))

    // Secondary button fill
    static let secondaryFill = Color(UIColor.dynamic(light: 0xFBF1DC, dark: 0x332B20))

    // Effects
    static let yolkGlow     = Color(hex: 0xF59E0B, alpha: 0.20)
    static let deliveryGlow = Color(hex: 0x2563EB, alpha: 0.16)
    static let shadowColor  = Color(UIColor.dynamic(light: 0x5A4614, dark: 0x000000)).opacity(0.10)
}

// MARK: - Gradients

enum AppGradient {
    static var splashBackground: LinearGradient {
        LinearGradient(
            colors: [AppColor.base, AppColor.depth],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var delivery: LinearGradient {
        LinearGradient(
            colors: [AppColor.primary, AppColor.primaryActive],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var yolk: LinearGradient {
        LinearGradient(
            colors: [AppColor.yolk, AppColor.coral],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Typography

enum AppFont {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let largeTitle = rounded(30, .bold)
    static let title      = rounded(24, .bold)
    static let headline   = rounded(18, .semibold)
    static let body       = rounded(16, .regular)
    static let callout    = rounded(15, .medium)
    static let subhead    = rounded(14, .regular)
    static let caption    = rounded(12, .medium)
    static let number     = rounded(26, .heavy)
}

// MARK: - Spacing & radius

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12
    static let radiusPill: CGFloat = 999
}

// MARK: - Animation tokens

enum Motion {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let gentle = Animation.easeInOut(duration: 0.35)
}

// MARK: - Card modifier

struct CardStyle: ViewModifier {
    var padding: CGFloat = Space.l
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Space.radius, style: .continuous)
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .shadow(color: AppColor.shadowColor, radius: 10, x: 0, y: 6)
    }
}

// MARK: - Global chrome (UIKit appearance)

enum AppChrome {
    /// Make UIKit-backed nav bars adopt the cream theme in both light & dark.
    static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.dynamic(light: 0xFFFBF2, dark: 0x161310)
        appearance.shadowColor = .clear
        let titleColor = UIColor.dynamic(light: 0x3A2E12, dark: 0xF4ECDD)
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.tintColor = UIColor(hex: 0x2563EB)
    }
}

extension View {
    func cardStyle(padding: CGFloat = Space.l) -> some View {
        modifier(CardStyle(padding: padding))
    }

    /// Hide the keyboard from anywhere.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}
