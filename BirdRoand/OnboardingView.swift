//
//  OnboardingView.swift
//  BirdRoand
//
//  Four interactive onboarding pages. Each writes a real setting into the
//  AppStore and uses a different gesture (tap-burst, drag, scroll-parallax,
//  wheel) so no two screens feel alike. Skip + Next + dot indicators always
//  visible. Looping animations are stopped on disappear.
//

import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var page = 0

    private let pageCount = 4

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: page dots + Skip
                HStack {
                    PageDots(count: pageCount, index: page)
                    Spacer()
                    Button("Skip") { finish() }
                        .font(AppFont.callout)
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.l)

                TabView(selection: $page) {
                    SellFormatPage(onNext: next).tag(0)
                    PricePage(onNext: next).tag(1)
                    DeliveryPage(onNext: next).tag(2)
                    CurrencyPage(onStart: finish).tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Bottom nav
                HStack {
                    if page > 0 {
                        Button(action: back) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(AppFont.callout)
                            .foregroundColor(AppColor.textSecondary)
                        }
                    }
                    Spacer()
                    if page < pageCount - 1 {
                        Button(action: next) {
                            HStack(spacing: 4) {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(AppFont.headline)
                            .foregroundColor(AppColor.primary)
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.l)
            }
        }
    }

    private func next() { withAnimation(Motion.spring) { page = min(pageCount - 1, page + 1) } }
    private func back() { withAnimation(Motion.spring) { page = max(0, page - 1) } }

    private func finish() {
        store.hasCompletedOnboarding = true
        store.syncReminders()
        onFinished()
    }
}

// MARK: - Page dots

private struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? AppColor.primary : AppColor.border)
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
        }
    }
}

// MARK: - Shared scaffold for a page

private struct OnboardScaffold<Scene: View, Controls: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var scene: () -> Scene
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        VStack(spacing: Space.xl) {
            Spacer(minLength: Space.l)
            scene()
                .frame(height: 230)
            VStack(spacing: Space.s) {
                Text(title)
                    .font(AppFont.title)
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(AppFont.subhead)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
            }
            controls()
                .padding(.horizontal, Space.xl)
            Spacer(minLength: Space.l)
        }
    }
}

// MARK: - O1 Sell Format (tap to burst eggs)

private struct SellFormatPage: View {
    let onNext: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var burst = 0
    @State private var iconScale: CGFloat = 1
    @State private var ringPulse = false
    @State private var isVisible = true

    var body: some View {
        OnboardScaffold(
            title: "Sell Format",
            subtitle: "Tap the tray to crack it open, then pick how you sell."
        ) {
            ZStack {
                Circle()
                    .stroke(AppColor.yolk.opacity(0.4), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(ringPulse ? 1.12 : 0.92)
                    .opacity(ringPulse ? 0 : 0.8)

                EggBurst(trigger: burst)

                Button(action: tap) {
                    IconBadge(systemName: store.sellFormat.icon, tint: AppColor.yolk, size: 120)
                        .scaleEffect(iconScale)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } controls: {
            VStack(spacing: Space.m) {
                Picker("", selection: Binding(
                    get: { store.sellFormat },
                    set: { store.sellFormat = $0 })) {
                    ForEach(SellFormat.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                PrimaryButton(title: "Set Format", systemImage: "checkmark") { onNext() }
            }
        }
        .onAppear {
            isVisible = true
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                ringPulse = true
            }
        }
        .onDisappear { isVisible = false; ringPulse = false }
    }

    private func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        burst += 1
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { iconScale = 1.18 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { iconScale = 1 }
        }
    }
}

/// A small egg-particle burst that replays whenever `trigger` changes.
private struct EggBurst: View {
    let trigger: Int
    @State private var fire = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                Ellipse()
                    .fill(i % 2 == 0 ? AppColor.yolk : AppColor.coral)
                    .frame(width: 12, height: 16)
                    .offset(x: fire ? CGFloat(cos(angle)) * 96 : 0,
                            y: fire ? CGFloat(sin(angle)) * 96 : 0)
                    .opacity(fire ? 0 : 1)
                    .scaleEffect(fire ? 0.3 : 1)
            }
        }
        .onChange(of: trigger) { _ in
            fire = false
            withAnimation(.easeOut(duration: 0.6)) { fire = true }
        }
    }
}

// MARK: - O2 Price (drag the knob)

private struct PricePage: View {
    let onNext: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var dragX: CGFloat = 0
    @State private var trackWidth: CGFloat = 1
    @State private var bump: CGFloat = 1

    private let minPrice = 0.5
    private let maxPrice = 20.0

    var body: some View {
        OnboardScaffold(
            title: "Price",
            subtitle: "Drag the coin to set your price per \(store.sellFormat.unitLabel)."
        ) {
            VStack(spacing: Space.xl) {
                Text(store.format(store.unitPrice))
                    .font(AppFont.rounded(46, .heavy))
                    .foregroundColor(AppColor.primary)
                    .scaleEffect(bump)

                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColor.border).frame(height: 10)
                        Capsule().fill(AppGradient.delivery)
                            .frame(width: knobX(in: w) + 16, height: 10)

                        Circle()
                            .fill(AppColor.yolk)
                            .frame(width: 38, height: 38)
                            .overlay(Image(systemName: "dollarsign")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white))
                            .shadow(color: AppColor.yolkGlow, radius: 8, x: 0, y: 4)
                            .offset(x: knobX(in: w))
                            .gesture(
                                DragGesture()
                                    .onChanged { v in
                                        let clamped = min(max(0, v.location.x - 19), w - 38)
                                        let ratio = Double(clamped / max(1, w - 38))
                                        store.unitPrice = (minPrice + ratio * (maxPrice - minPrice))
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                            bump = 1.12
                                        }
                                    }
                                    .onEnded { _ in
                                        store.unitPrice = (store.unitPrice * 20).rounded() / 20
                                        withAnimation(Motion.spring) { bump = 1 }
                                    }
                            )
                    }
                    .onAppear { trackWidth = w }
                }
                .frame(height: 44)
                .padding(.horizontal, Space.xl)
            }
        } controls: {
            PrimaryButton(title: "Set Price", systemImage: "checkmark") { onNext() }
        }
    }

    private func knobX(in width: CGFloat) -> CGFloat {
        let ratio = (store.unitPrice - minPrice) / (maxPrice - minPrice)
        return CGFloat(min(1, max(0, ratio))) * (width - 38)
    }
}

// MARK: - O3 Delivery (scroll-driven parallax)

private struct DeliveryPage: View {
    let onNext: () -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        OnboardScaffold(
            title: "Delivery",
            subtitle: "Scroll the route, then choose how eggs reach your customers."
        ) {
            GeometryReader { outer in
                ScrollView(.vertical, showsIndicators: false) {
                    ParallaxHeader(height: 230)
                        .frame(height: 230)
                    // a little extra content so there is room to scroll the parallax
                    VStack(spacing: Space.s) {
                        ForEach(DeliveryMethod.allCases) { m in
                            DeliveryOptionRow(method: m,
                                              selected: store.deliveryMethod == m) {
                                withAnimation(Motion.spring) { store.deliveryMethod = m }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                    .padding(.top, Space.m)
                }
            }
        } controls: {
            PrimaryButton(title: "Set Delivery", systemImage: "checkmark") { onNext() }
        }
    }
}

private struct ParallaxHeader: View {
    let height: CGFloat
    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let parallax = minY * 0.4
            ZStack {
                RoundedRectangle(cornerRadius: Space.radius, style: .continuous)
                    .fill(AppGradient.delivery)
                Image(systemName: "box.truck.fill")
                    .font(.system(size: 70, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .offset(x: parallax * 0.8, y: -parallax * 0.2)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColor.yolk)
                    .offset(x: -90 + parallax, y: -50)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 96 - parallax * 0.6, y: 56)
            }
            .frame(height: height + max(0, minY))
            .offset(y: minY > 0 ? -minY : 0)
            .shadow(color: AppColor.deliveryGlow, radius: 14, x: 0, y: 8)
        }
    }
}

private struct DeliveryOptionRow: View {
    let method: DeliveryMethod
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                IconBadge(systemName: method.icon,
                          tint: selected ? AppColor.primary : AppColor.textInactive, size: 42)
                Text(method.title)
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? AppColor.success : AppColor.border)
            }
            .padding(Space.m)
            .background(selected ? AppColor.primary.opacity(0.08) : AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                    .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - O4 Currency (wheel gesture)

private struct CurrencyPage: View {
    let onStart: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var coinSpin = false
    @State private var isVisible = true

    private let currencies: [(String, String)] = [
        ("USD", "$"), ("EUR", "€"), ("GBP", "£"), ("UAH", "₴"),
        ("PLN", "zł"), ("CAD", "$"), ("AUD", "$"), ("INR", "₹"),
        ("JPY", "¥"), ("CHF", "Fr")
    ]

    var body: some View {
        OnboardScaffold(
            title: "Currency",
            subtitle: "Spin the wheel to pick the currency for every amount."
        ) {
            ZStack {
                Circle()
                    .fill(AppColor.deliveryGlow)
                    .frame(width: 170, height: 170)
                    .blur(radius: 20)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 92, weight: .bold))
                    .foregroundColor(AppColor.primary)
                    .rotationEffect(.degrees(coinSpin ? 360 : 0))
            }
        } controls: {
            VStack(spacing: Space.m) {
                Picker("", selection: Binding(
                    get: { store.currencyCode },
                    set: { store.currencyCode = $0 })) {
                    ForEach(currencies, id: \.0) { code, symbol in
                        Text("\(code)  \(symbol)").tag(code)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 110)
                .clipped()

                PrimaryButton(title: "Start Selling", systemImage: "arrow.right") { onStart() }
            }
        }
        .onAppear {
            isVisible = true
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                coinSpin = true
            }
        }
        .onDisappear { isVisible = false; coinSpin = false }
    }
}
