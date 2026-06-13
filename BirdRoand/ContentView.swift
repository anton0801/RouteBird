//
//  ContentView.swift
//  BirdRoand
//
//  Root coordinator. Drives the only navigation gate in the whole app:
//  Splash → (first launch) Onboarding → Main. No auth, no welcome wall.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var phase: Phase = .splash

    enum Phase { case splash, onboarding, main }

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()

            switch phase {
            case .splash:
                SplashView(onFinished: advanceFromSplash)
                    .transition(.opacity)
            case .onboarding:
                OnboardingView(onFinished: {
                    withAnimation(Motion.spring) { phase = .main }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity)
                )
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
    }

    private func advanceFromSplash() {
        withAnimation(Motion.spring) {
            phase = store.hasCompletedOnboarding ? .main : .onboarding
        }
    }
}

#Preview {
    ContentView().environmentObject(AppStore())
}
