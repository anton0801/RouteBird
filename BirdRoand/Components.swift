//
//  Components.swift
//  BirdRoand
//
//  Custom component library — buttons, cards, pills, tiles, fields.
//  Everything is iOS-14 safe and uses the AppColor / AppFont design system.
//

import SwiftUI

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var fill: LinearGradient = AppGradient.delivery
    var enabled: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: Space.s) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(AppFont.headline)
            .foregroundColor(AppColor.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(pressed ? 0.97 : 1)
            .shadow(color: AppColor.deliveryGlow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(Motion.snappy) { pressed = true } }
                .onEnded { _ in withAnimation(Motion.snappy) { pressed = false } }
        )
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: Space.s) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(AppFont.callout)
            .foregroundColor(AppColor.onSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AppColor.secondaryFill)
            .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                    .stroke(AppColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PayButton: View {
    let title: String
    var systemImage: String? = "dollarsign.circle.fill"
    let action: () -> Void

    var body: some View {
        Button(action: {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            action()
        }) {
            HStack(spacing: Space.s) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(AppFont.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppColor.success)
            .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
            .shadow(color: AppColor.success.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Small circular icon button used in nav bars / cards.
struct CircleIconButton: View {
    let systemImage: String
    var tint: Color = AppColor.primary
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Card

struct BRCard<Content: View>: View {
    var padding: CGFloat = Space.l
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().cardStyle(padding: padding)
    }
}

// MARK: - Status pill

struct StatusPill: View {
    let text: String
    let color: Color
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(AppFont.caption)
            .foregroundColor(filled ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? color : color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let title: String
    let value: String
    var systemImage: String
    var tint: Color = AppColor.primary

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(tint)
                Text(title)
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textSecondary)
            }
            Text(value)
                .font(AppFont.rounded(22, .heavy))
                .foregroundColor(AppColor.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.m)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var accent: Color = AppColor.textPrimary

    var body: some View {
        HStack(spacing: Space.s) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accent)
            }
            Text(title)
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
            Spacer()
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Space.m) {
            ZStack {
                Circle()
                    .fill(AppColor.yolkGlow)
                    .frame(width: 96, height: 96)
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .regular))
                    .foregroundColor(AppColor.yolk)
            }
            Text(title)
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
            Text(message)
                .font(AppFont.subhead)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }
}

// MARK: - Quantity stepper

struct QuantityStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var step: Int = 1
    var unit: String = ""

    var body: some View {
        HStack(spacing: Space.m) {
            stepButton("minus") {
                value = max(range.lowerBound, value - step)
            }
            VStack(spacing: 0) {
                Text("\(value)")
                    .font(AppFont.rounded(22, .bold))
                    .foregroundColor(AppColor.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .frame(minWidth: 70)
            stepButton("plus") {
                value = min(range.upperBound, value + step)
            }
        }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(Motion.snappy) { action() }
        }) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColor.primary)
                .frame(width: 42, height: 42)
                .background(AppColor.primary.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Text field

struct BRTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: Space.s) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .foregroundColor(AppColor.textInactive)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .font(AppFont.body)
                .foregroundColor(AppColor.textPrimary)
                .keyboardType(keyboard)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, 13)
        .background(AppColor.depth)
        .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Icon badge (circular SF symbol on tinted disk)

struct IconBadge: View {
    let systemName: String
    var tint: Color = AppColor.primary
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
    }
}

// MARK: - Labeled field row (for forms / detail)

struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(AppFont.caption)
                .foregroundColor(AppColor.textSecondary)
            content()
        }
    }
}

/// Segmented control styled to the theme.
struct BRSegmented<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { opt in
                Button(action: { withAnimation(Motion.snappy) { selection = opt } }) {
                    Text(label(opt))
                        .font(AppFont.callout)
                        .foregroundColor(selection == opt ? .white : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selection == opt ? AppColor.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(AppColor.depth)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Progress bar (demand vs supply, allocations)

struct BRProgressBar: View {
    /// 0...1, clamped.
    let ratio: Double
    var tint: Color = AppColor.primary
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.border)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, ratio)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
