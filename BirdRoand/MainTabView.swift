//
//  MainTabView.swift
//  BirdRoand
//
//  The main app shell: a custom themed tab bar over five sections. No auth,
//  no profile — the app lands here straight after onboarding.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab: Tab = .board

    enum Tab: Int, CaseIterable {
        case board, customers, supply, money, more
        var title: String {
            switch self {
            case .board: return "Board"
            case .customers: return "Customers"
            case .supply: return "Supply"
            case .money: return "Money"
            case .more: return "More"
            }
        }
        var icon: String {
            switch self {
            case .board: return "flame.fill"
            case .customers: return "person.2.fill"
            case .supply: return "chart.bar.fill"
            case .money: return "creditcard.fill"
            case .more: return "ellipsis.circle.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.base.ignoresSafeArea()

            Group {
                switch tab {
                case .board:     RoundBoardView()
                case .customers: CustomersView()
                case .supply:    SupplyHubView()
                case .money:     MoneyHubView()
                case .more:      MoreView()
                }
            }
            .padding(.bottom, 64)   // clear the floating tab bar

            tabBar
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { t in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(Motion.snappy) { tab = t }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .scaleEffect(tab == t ? 1.12 : 1)
                        Text(t.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(tab == t ? AppColor.primary : AppColor.textInactive)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 22)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            AppColor.card
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: AppColor.shadowColor, radius: 14, x: 0, y: -2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppColor.border, lineWidth: 1)
        )
        .padding(.horizontal, Space.m)
    }
}
