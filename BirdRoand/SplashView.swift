//
//  SplashView.swift
//  BirdRoand
//
//  Thematic splash: an egg tray turns into a delivery route with drop pins.
//  Three simultaneously animated layers (drifting glow background, the route
//  drawing itself with a travelling egg + pulsing pins, and the logo/title
//  spring entrance), driven by a single coordinator timer. All looping
//  animation state is reset in .onDisappear so nothing leaks into the app.
//

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    // Lifecycle
    @State private var isVisible = true
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    // Layer 1 — background glow drift
    @State private var glowShift = false

    // Layer 2 — route
    @State private var routeProgress: CGFloat = 0
    @State private var pinsIn = false
    @State private var pinPulse = false
    @State private var eggT: CGFloat = 0      // 0...1 position along the route

    // Layer 3 — logo / title
    @State private var logoIn = false
    @State private var titleIn = false

    // Exit
    @State private var exitScale: CGFloat = 1
    @State private var exitOpacity: Double = 1

    // Route waypoints in unit space (0...1). Shared by the shape + the egg.
    private let waypoints: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.78),
        CGPoint(x: 0.34, y: 0.52),
        CGPoint(x: 0.58, y: 0.66),
        CGPoint(x: 0.86, y: 0.30)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ---- Layer 1: drifting cream + glow background ----
                AppGradient.splashBackground.ignoresSafeArea()

                Circle()
                    .fill(AppColor.yolkGlow)
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(x: glowShift ? -90 : -40, y: glowShift ? -160 : -120)

                Circle()
                    .fill(AppColor.deliveryGlow)
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: glowShift ? 110 : 60, y: glowShift ? 180 : 150)

                // ---- Layer 2: the delivery route ----
                ZStack {
                    RouteShape(points: waypoints)
                        .trim(from: 0, to: routeProgress)
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round,
                                                   lineJoin: .round, dash: [2, 10]))
                        .foregroundColor(AppColor.primary.opacity(0.55))

                    // Drop pins at every waypoint
                    ForEach(Array(waypoints.enumerated()), id: \.offset) { idx, p in
                        DeliveryPin(color: idx == waypoints.count - 1 ? AppColor.coral : AppColor.primary)
                            .scaleEffect(pinsIn ? (pinPulse ? 1.08 : 1.0) : 0.01)
                            .opacity(pinsIn ? 1 : 0)
                            .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
                    }

                    // Travelling egg riding the route
                    EggToken()
                        .position(pointOn(route: waypoints, t: eggT,
                                          in: geo.size))
                        .opacity(routeProgress > 0.05 ? 1 : 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // ---- Layer 3: logo + title ----
                VStack(spacing: Space.l) {
                    SplashLogo()
                        .scaleEffect(logoIn ? 1 : 0.4)
                        .opacity(logoIn ? 1 : 0)

                    VStack(spacing: Space.s) {
                        Text("Bird Roand")
                            .font(AppFont.rounded(36, .heavy))
                            .foregroundColor(AppColor.textPrimary)
                        Text("From coop to customer.")
                            .font(AppFont.callout)
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 14)
                }
                .offset(y: -20)
            }
            .scaleEffect(exitScale)
            .opacity(exitOpacity)
        }
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    // MARK: - Coordinator

    private func start() {
        isVisible = true

        // Looping background drift (Layer 1)
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            glowShift = true
        }

        // Single coordinator timer drives the staged sequence.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            guard isVisible else { t.invalidate(); return }
            elapsed += 0.1

            // phase 2 (0.6s): draw the route + travelling egg + pins
            if abs(elapsed - 0.6) < 0.051 {
                withAnimation(.easeInOut(duration: 0.9)) { routeProgress = 1 }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { pinsIn = true }
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    eggT = 1
                }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pinPulse = true
                }
            }

            // phase 3 (1.4s): logo + title spring entrance
            if abs(elapsed - 1.4) < 0.051 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { logoIn = true }
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) { titleIn = true }
            }

            // phase 4 (2.6s): designed exit — logo scales up and the scene fades
            if abs(elapsed - 2.6) < 0.051 {
                withAnimation(.easeIn(duration: 0.45)) {
                    exitScale = 1.18
                    exitOpacity = 0
                }
            }

            // hand off after the exit transition completes
            if elapsed >= 3.05 {
                t.invalidate()
                onFinished()
            }
        }
    }

    private func stop() {
        isVisible = false
        timer?.invalidate()
        timer = nil
        // reset every animated value so nothing keeps ticking in the background
        glowShift = false
        routeProgress = 0
        pinsIn = false
        pinPulse = false
        eggT = 0
        logoIn = false
        titleIn = false
    }

    // MARK: - Geometry: sample a point along the polyline route

    private func pointOn(route: [CGPoint], t: CGFloat, in size: CGSize) -> CGPoint {
        guard route.count > 1 else {
            let p = route.first ?? CGPoint(x: 0.5, y: 0.5)
            return CGPoint(x: p.x * size.width, y: p.y * size.height)
        }
        let clamped = max(0, min(1, t))
        let segments = route.count - 1
        let scaled = clamped * CGFloat(segments)
        let i = min(segments - 1, Int(scaled))
        let local = scaled - CGFloat(i)
        let a = route[i], b = route[i + 1]
        let x = (a.x + (b.x - a.x) * local) * size.width
        let y = (a.y + (b.y - a.y) * local) * size.height
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Route shape

private struct RouteShape: Shape {
    let points: [CGPoint]   // unit space
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * rect.width, y: first.y * rect.height))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * rect.width, y: pt.y * rect.height))
        }
        return p
    }
}

// MARK: - Decorative pieces

private struct DeliveryPin: View {
    let color: Color
    var body: some View {
        ZStack {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(color)
                .background(Circle().fill(AppColor.card).frame(width: 18, height: 18))
        }
        .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}

private struct EggToken: View {
    var body: some View {
        Ellipse()
            .fill(AppGradient.yolk)
            .frame(width: 16, height: 21)
            .rotationEffect(.degrees(18))
            .shadow(color: AppColor.yolkGlow, radius: 6, x: 0, y: 2)
    }
}

private struct SplashLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppGradient.delivery)
                .frame(width: 104, height: 104)
                .shadow(color: AppColor.deliveryGlow, radius: 18, x: 0, y: 10)

            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white.opacity(0.95))

            Image(systemName: "location.north.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(AppColor.yolk)
                .padding(6)
                .background(Circle().fill(Color.white))
                .offset(x: 34, y: -34)
        }
    }
}
