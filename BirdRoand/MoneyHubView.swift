//
//  MoneyHubView.swift
//  BirdRoand
//
//  Features 08 + 10 + 07 — Payments/debts, Income, and Tray Returns behind one
//  segmented money hub.
//

import SwiftUI

struct MoneyHubView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case payments = "Payments", income = "Income", trays = "Trays"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .payments

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        BRSegmented(options: Mode.allCases, selection: $mode) { $0.rawValue }
                        switch mode {
                        case .payments: PaymentsView()
                        case .income:   IncomeView()
                        case .trays:    TrayReturnsView()
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Money")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Payments (Feature 08)

struct PaymentsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showCollect = false

    var body: some View {
        VStack(spacing: Space.l) {
            BRCard {
                VStack(spacing: Space.s) {
                    Text("Outstanding debt").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    Text(store.format(store.totalDebt))
                        .font(AppFont.rounded(40, .heavy))
                        .foregroundColor(store.totalDebt > 0.01 ? AppColor.warn : AppColor.success)
                    Text("\(store.debtors.count) customer\(store.debtors.count == 1 ? "" : "s") owe you")
                        .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            PrimaryButton(title: "Collect Payment", systemImage: "dollarsign.circle.fill") {
                showCollect = true
            }

            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "Who owes", systemImage: "exclamationmark.circle.fill")
                if store.debtors.isEmpty {
                    BRCard { EmptyState(systemImage: "checkmark.seal.fill",
                                        title: "All settled",
                                        message: "No customer currently owes for delivered orders.") }
                } else {
                    ForEach(store.debtors) { c in
                        DebtorRow(customer: c)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "Recent payments", systemImage: "clock.arrow.circlepath")
                let recent = store.payments.sorted { $0.date > $1.date }.prefix(8)
                if recent.isEmpty {
                    Text("No payments yet.").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                } else {
                    ForEach(Array(recent)) { p in
                        BRCard(padding: Space.m) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill").foregroundColor(AppColor.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.customer(p.customerId)?.name ?? "Customer")
                                        .font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                                    Text("\(p.kind.title) · \(dateString(p.date))")
                                        .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                                }
                                Spacer()
                                Text(store.format(p.amount)).font(AppFont.headline).foregroundColor(AppColor.success)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCollect) {
            CollectPaymentSheet(customer: nil).environmentObject(store)
        }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
}

private struct DebtorRow: View {
    @EnvironmentObject private var store: AppStore
    let customer: Customer
    @State private var showCollect = false
    var body: some View {
        BRCard(padding: Space.m) {
            HStack(spacing: Space.m) {
                AvatarCircle(initials: customer.initials, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                    Text("owes \(store.format(store.debt(for: customer.id)))")
                        .font(AppFont.caption).foregroundColor(AppColor.warn)
                }
                Spacer()
                SmallActionButton(title: "Collect", icon: "dollarsign", tint: AppColor.success) {
                    showCollect = true
                }
                .frame(width: 110)
            }
        }
        .sheet(isPresented: $showCollect) {
            CollectPaymentSheet(customer: customer).environmentObject(store)
        }
    }
}

// MARK: - Collect payment sheet (shared)

struct CollectPaymentSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let customer: Customer?

    @State private var selectedId: UUID?
    @State private var amountText = ""
    @State private var kind: PaymentKind = .paid
    @State private var didInit = false

    private var resolvedCustomer: Customer? {
        if let c = customer { return c }
        if let id = selectedId { return store.customer(id) }
        return nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        if customer == nil {
                            FieldRow(label: "Customer") {
                                Picker("Customer", selection: Binding(
                                    get: { selectedId ?? store.customers.first?.id },
                                    set: { selectedId = $0 })) {
                                    ForEach(store.customers) { c in
                                        Text(c.name).tag(Optional(c.id))
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(height: 110).clipped()
                            }
                        } else {
                            BRCard(padding: Space.m) {
                                HStack {
                                    AvatarCircle(initials: customer!.initials, size: 40)
                                    Text(customer!.name).font(AppFont.headline).foregroundColor(AppColor.textPrimary)
                                    Spacer()
                                }
                            }
                        }

                        if let c = resolvedCustomer {
                            let debt = store.debt(for: c.id)
                            HStack {
                                Text("Current debt").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                                Spacer()
                                Text(store.format(max(0, debt)))
                                    .font(AppFont.headline)
                                    .foregroundColor(debt > 0.01 ? AppColor.warn : AppColor.success)
                            }
                            .padding(.horizontal, Space.s)
                        }

                        FieldRow(label: "Amount") {
                            BRTextField(placeholder: "0.00", text: $amountText,
                                        systemImage: "dollarsign", keyboard: .decimalPad)
                        }

                        FieldRow(label: "Type") {
                            Picker("Type", selection: $kind) {
                                Text("Payment").tag(PaymentKind.paid)
                                Text("Prepaid").tag(PaymentKind.prepaid)
                                Text("Write-off").tag(PaymentKind.debtWriteOff)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        if let c = resolvedCustomer, store.debt(for: c.id) > 0.01 {
                            SecondaryButton(title: "Fill full debt \(store.format(store.debt(for: c.id)))",
                                            systemImage: "equal.circle") {
                                amountText = String(format: "%.2f", store.debt(for: c.id))
                            }
                        }

                        PayButton(title: "Record Payment") { record() }
                            .disabled(!canRecord)
                            .opacity(canRecord ? 1 : 0.5)
                    }
                    .padding(.horizontal, Space.l).padding(.top, Space.s).padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Collect Payment")
            .navigationBarItems(leading:
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppColor.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !didInit else { return }
            didInit = true
            if customer == nil { selectedId = store.customers.first?.id }
            if let c = resolvedCustomer {
                let debt = store.debt(for: c.id)
                if debt > 0.01 { amountText = String(format: "%.2f", debt) }
            }
        }
    }

    private var amount: Double { Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var canRecord: Bool { resolvedCustomer != nil && amount > 0 }

    private func record() {
        guard let c = resolvedCustomer, amount > 0 else { return }
        store.recordPayment(customerId: c.id, amount: amount, kind: kind)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Income (Feature 10)

struct IncomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var period: AppStore.Period = .week

    var body: some View {
        VStack(spacing: Space.l) {
            BRSegmented(options: AppStore.Period.allCases, selection: $period) { $0.rawValue }

            BRCard {
                VStack(spacing: Space.s) {
                    Text("Revenue · \(period.rawValue)").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    Text(store.format(store.incomeIn(period)))
                        .font(AppFont.rounded(44, .heavy)).foregroundColor(AppColor.success)
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: Space.m) {
                StatTile(title: "Payments", value: "\(store.paymentsCount(in: period))",
                         systemImage: "number", tint: AppColor.primary)
                StatTile(title: "Avg ticket", value: store.format(store.avgTicket(in: period)),
                         systemImage: "chart.bar.fill", tint: AppColor.yolk)
            }

            if let (best, total) = store.bestCustomer {
                BRCard {
                    HStack(spacing: Space.m) {
                        IconBadge(systemName: "crown.fill", tint: AppColor.yolk, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best customer").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                            Text(best.name).font(AppFont.headline).foregroundColor(AppColor.textPrimary)
                        }
                        Spacer()
                        Text(store.format(total)).font(AppFont.headline).foregroundColor(AppColor.success)
                    }
                }
            }

            BRCard {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionHeader(title: "All-time", systemImage: "infinity")
                    rowLine("Total revenue", store.format(store.totalRevenue))
                    rowLine("Outstanding debt", store.format(store.totalDebt))
                    rowLine("Eggs on hand", "\(Int(store.currentStockEggs))")
                }
            }
        }
    }

    private func rowLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
            Spacer()
            Text(value).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
        }
    }
}
