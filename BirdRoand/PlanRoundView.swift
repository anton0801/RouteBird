//
//  PlanRoundView.swift
//  BirdRoand
//
//  Feature 05 — the delivery round for a day: ordered stops, eggs per stop and
//  a running load total. Built from the supply/demand allocation so short days
//  show exactly who gets trimmed.
//

import SwiftUI

struct PlanRoundView: View {
    @EnvironmentObject private var store: AppStore
    @State private var day: Weekday = .today

    private var plan: RoundPlan { store.roundPlan(for: day) }

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.l) {
                    daySelector
                    summaryCard

                    if plan.isEmpty {
                        BRCard {
                            EmptyState(systemImage: "map",
                                       title: "No home deliveries",
                                       message: "No home-delivery customers are scheduled for \(day.short). Pickup and market-stall customers aren't routed.")
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(plan.stops.enumerated()), id: \.element.id) { idx, stop in
                                StopRow(stop: stop, isLast: idx == plan.stops.count - 1,
                                        showDeliver: day == .today)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
            }
        }
        .navigationTitle("Plan Round")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if day == .today { store.generateTodaysRecurringOrders() } }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Weekday.allCases) { d in
                    Button(action: { withAnimation(Motion.snappy) { day = d } }) {
                        Text(d.short)
                            .font(AppFont.caption)
                            .foregroundColor(day == d ? .white : AppColor.textSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(day == d ? AppColor.primary : AppColor.depth)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var summaryCard: some View {
        BRCard {
            HStack(spacing: Space.m) {
                summaryItem("\(plan.stops.count)", "Stops", "mappin.and.ellipse", AppColor.primary)
                Divider().frame(height: 38)
                summaryItem("\(Int(plan.totalEggs))", "Eggs to load", "tray.full.fill", AppColor.yolk)
                Divider().frame(height: 38)
                summaryItem("\(plan.cutCount)", "Cut orders",
                            "scissors", plan.cutCount > 0 ? AppColor.warn : AppColor.success)
            }
        }
    }

    private func summaryItem(_ value: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundColor(tint)
            Text(value).font(AppFont.rounded(20, .heavy)).foregroundColor(AppColor.textPrimary)
            Text(label).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StopRow: View {
    @EnvironmentObject private var store: AppStore
    let stop: RouteStop
    let isLast: Bool
    let showDeliver: Bool

    private var deliveredToday: Bool {
        store.orders.contains {
            $0.customerId == stop.id && Calendar.current.isDateInToday($0.date) &&
            ($0.status == .delivered || $0.status == .paid)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            // Timeline rail
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(AppColor.primary).frame(width: 28, height: 28)
                    Text("\(stop.sequence)").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                }
                if !isLast {
                    Rectangle().fill(AppColor.border).frame(width: 2).frame(minHeight: 44)
                }
            }

            BRCard(padding: Space.m) {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack {
                        Text(stop.customerName).font(AppFont.headline).foregroundColor(AppColor.textPrimary)
                        Spacer()
                        if stop.isCut { StatusPill(text: "Cut", color: AppColor.warn, filled: true) }
                    }
                    HStack(spacing: Space.m) {
                        Label(stop.zone, systemImage: "map.fill")
                            .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                        Label(store.unitsString(stop.units), systemImage: "shippingbox.fill")
                            .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    }
                    if !stop.address.isEmpty {
                        Text(stop.address).font(AppFont.caption).foregroundColor(AppColor.textInactive)
                    }
                    HStack {
                        Text("\(Int(stop.eggs)) eggs").font(AppFont.callout).foregroundColor(AppColor.primary)
                        Spacer()
                        Text("load: \(Int(stop.runningEggs))")
                            .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    }
                    if showDeliver {
                        if deliveredToday {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Delivered")
                            }
                            .font(AppFont.caption).foregroundColor(AppColor.success)
                        } else {
                            SmallActionButton(title: "Mark delivered", icon: "checkmark", tint: AppColor.success) {
                                deliver()
                            }
                        }
                    }
                }
            }
            .padding(.bottom, Space.m)
        }
    }

    private func deliver() {
        let today = Calendar.current.startOfDay(for: Date())
        if let order = store.orders.first(where: {
            $0.customerId == stop.id && Calendar.current.isDateInToday($0.date) && $0.status != .cancelled
        }) {
            withAnimation(Motion.spring) { store.setOrderStatus(order, .delivered) }
        } else {
            let newOrder = Order(customerId: stop.id, date: today, units: stop.units,
                                 status: .planned, isRecurring: true, unitPriceSnapshot: store.unitPrice)
            store.addOrder(newOrder)
            withAnimation(Motion.spring) { store.setOrderStatus(newOrder, .delivered) }
        }
    }
}
