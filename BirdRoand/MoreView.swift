//
//  MoreView.swift
//  BirdRoand
//
//  The "More" tab — a hub linking to Orders, Plan Round, Reports, History,
//  Reminders and Settings.
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.m) {
                        snapshot

                        MoreLink(icon: "list.bullet.rectangle.fill", tint: AppColor.primary,
                                 title: "Orders", subtitle: "Recurring, one-off & cancellations",
                                 destination: AnyView(OrdersView()))
                        MoreLink(icon: "map.fill", tint: AppColor.yolk,
                                 title: "Plan Round", subtitle: "Ordered delivery route for the day",
                                 destination: AnyView(PlanRoundView()))
                        MoreLink(icon: "doc.text.fill", tint: AppColor.coral,
                                 title: "Reports", subtitle: "Sales, debts, trays · export PDF/CSV",
                                 destination: AnyView(ReportsView()))
                        MoreLink(icon: "clock.arrow.circlepath", tint: AppColor.primary,
                                 title: "History", subtitle: "Ordered, delivered, paid, returned",
                                 destination: AnyView(HistoryView()))
                        MoreLink(icon: "bell.badge.fill", tint: AppColor.yolk,
                                 title: "Reminders", subtitle: "Collect, deliver, debts, trays",
                                 destination: AnyView(RemindersView()))
                        MoreLink(icon: "gearshape.fill", tint: AppColor.textSecondary,
                                 title: "Settings", subtitle: "Format, price, currency, theme",
                                 destination: AnyView(SettingsView()))
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("More")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var snapshot: some View {
        HStack(spacing: Space.m) {
            StatTile(title: "Revenue", value: store.format(store.totalRevenue),
                     systemImage: "dollarsign.circle.fill", tint: AppColor.success)
            StatTile(title: "Debt", value: store.format(store.totalDebt),
                     systemImage: "exclamationmark.circle.fill", tint: AppColor.warn)
            StatTile(title: "Eggs", value: "\(Int(store.currentStockEggs))",
                     systemImage: "tray.full.fill", tint: AppColor.primary)
        }
    }
}

private struct MoreLink: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            BRCard(padding: Space.m) {
                HStack(spacing: Space.m) {
                    IconBadge(systemName: icon, tint: tint, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(AppFont.headline).foregroundColor(AppColor.textPrimary)
                        Text(subtitle).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(AppColor.textInactive)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
