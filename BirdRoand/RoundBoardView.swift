//
//  RoundBoardView.swift
//  BirdRoand
//
//  Feature 01 — the flagship "today to deliver" board. Shows demand vs the eggs
//  available to sell, the day's customers with live status, and the three core
//  actions: Add Customer, Plan Round, Collect Payment.
//

import SwiftUI

struct RoundBoardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAddCustomer = false
    @State private var showCollectPayment = false

    private var today: Weekday { .today }

    private var todaysOrders: [Order] {
        store.orders
            .filter {
                Calendar.current.isDateInToday($0.date) && $0.status != .cancelled
            }
            .sorted { lhs, rhs in
                let lo = store.customer(lhs.customerId)?.routeOrder ?? 0
                let ro = store.customer(rhs.customerId)?.routeOrder ?? 0
                return lo < ro
            }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        demandCard
                        actionRow
                        deliveriesSection
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Round Board")
            .navigationBarItems(trailing:
                Button(action: { showAddCustomer = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { store.generateTodaysRecurringOrders() }
        .sheet(isPresented: $showAddCustomer) {
            AddCustomerView().environmentObject(store)
        }
        .sheet(isPresented: $showCollectPayment) {
            CollectPaymentSheet(customer: nil).environmentObject(store)
        }
    }

    // MARK: - Demand vs supply hero

    private var demandCard: some View {
        let result = store.supplyDemand(for: today)
        return BRCard {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    Text(Date(), style: .date)
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                    Spacer()
                    StatusPill(
                        text: result.isShort ? "Short \(Int(result.deficitEggs)) eggs" : "Covered",
                        color: result.isShort ? AppColor.warn : AppColor.success,
                        filled: true
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demand today")
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.textSecondary)
                        Text("\(Int(result.demandEggs)) eggs")
                            .font(AppFont.rounded(24, .heavy))
                            .foregroundColor(AppColor.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Available")
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.textSecondary)
                        Text("\(Int(result.availableEggs)) eggs")
                            .font(AppFont.rounded(24, .heavy))
                            .foregroundColor(result.isShort ? AppColor.warn : AppColor.success)
                    }
                }

                BRProgressBar(ratio: result.coverage,
                              tint: result.isShort ? AppColor.warn : AppColor.success)
                Text(result.isShort
                     ? "Not enough eggs — orders will be trimmed. Open Plan Round to see who."
                     : "\(Int(result.surplusEggs)) eggs to spare after today's orders.")
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: Space.m) {
            BoardAction(title: "Add\nCustomer", icon: "person.badge.plus", tint: AppColor.primary) {
                showAddCustomer = true
            }
            NavigationLink(destination: PlanRoundView()) {
                BoardActionLabel(title: "Plan\nRound", icon: "map.fill", tint: AppColor.yolk)
            }
            .buttonStyle(PlainButtonStyle())
            BoardAction(title: "Collect\nPayment", icon: "dollarsign.circle.fill", tint: AppColor.success) {
                showCollectPayment = true
            }
        }
    }

    // MARK: - Deliveries

    private var deliveriesSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "Today's deliveries", systemImage: "shippingbox.fill")
            if todaysOrders.isEmpty {
                BRCard {
                    EmptyState(systemImage: "calendar.badge.checkmark",
                               title: "Nothing due today",
                               message: "No customers are scheduled for delivery today. Add a customer or adjust their delivery days.")
                }
            } else {
                ForEach(todaysOrders) { order in
                    BoardOrderRow(order: order)
                }
            }
        }
    }
}

// MARK: - Board action buttons

private struct BoardActionLabel: View {
    let title: String
    let icon: String
    let tint: Color
    var body: some View {
        VStack(spacing: Space.s) {
            IconBadge(systemName: icon, tint: tint, size: 46)
            Text(title)
                .font(AppFont.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

private struct BoardAction: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            BoardActionLabel(title: title, icon: icon, tint: tint)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Order row

private struct BoardOrderRow: View {
    @EnvironmentObject private var store: AppStore
    let order: Order

    private var customer: Customer? { store.customer(order.customerId) }

    var body: some View {
        BRCard(padding: Space.m) {
            VStack(spacing: Space.m) {
                HStack(spacing: Space.m) {
                    AvatarCircle(initials: customer?.initials ?? "?")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer?.name ?? "Customer")
                            .font(AppFont.headline)
                            .foregroundColor(AppColor.textPrimary)
                        Text("\(store.unitsString(order.units)) · \(store.format(order.amount))")
                            .font(AppFont.subhead)
                            .foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                    StatusPill(text: order.status.title, color: order.status.color)
                }

                HStack(spacing: Space.s) {
                    if order.status == .planned {
                        SmallActionButton(title: "Delivered", icon: "checkmark", tint: AppColor.success) {
                            withAnimation(Motion.spring) { store.setOrderStatus(order, .delivered) }
                        }
                        SmallActionButton(title: "Cancel", icon: "xmark", tint: AppColor.danger) {
                            withAnimation(Motion.spring) { store.setOrderStatus(order, .cancelled) }
                        }
                    } else if order.status == .delivered {
                        SmallActionButton(title: "Collect \(store.format(order.amount))",
                                          icon: "dollarsign.circle.fill", tint: AppColor.success) {
                            withAnimation(Motion.spring) { store.setOrderStatus(order, .paid) }
                        }
                    } else if order.status == .paid {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Delivered & paid")
                        }
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.success)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct SmallActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(AppFont.caption)
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AvatarCircle: View {
    let initials: String
    var size: CGFloat = 44
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(AppGradient.delivery)
            .clipShape(Circle())
    }
}
