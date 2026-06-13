//
//  SupplyHubView.swift
//  BirdRoand
//
//  Feature 04 + 09 — Supply vs Demand and Stock On Hand, behind one segmented
//  hub so the "eggs available vs customers' demand" story lives in one place.
//

import SwiftUI

struct SupplyHubView: View {
    enum Mode: String, CaseIterable, Identifiable { case demand = "Supply vs Demand", stock = "Stock"; var id: String { rawValue } }
    @State private var mode: Mode = .demand

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        BRSegmented(options: Mode.allCases, selection: $mode) { $0.rawValue }
                        if mode == .demand {
                            SupplyDemandView()
                        } else {
                            StockView()
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Supply")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Supply vs Demand (Feature 04)

struct SupplyDemandView: View {
    @EnvironmentObject private var store: AppStore
    @State private var day: Weekday = .today
    @State private var weekly = false

    var body: some View {
        VStack(spacing: Space.l) {
            BRSegmented(options: [DayMode.today, DayMode.week], selection: Binding(
                get: { weekly ? .week : .today },
                set: { weekly = ($0 == .week) })) { $0.label }

            if weekly {
                weeklyView
            } else {
                dailyView
            }
        }
    }

    // Daily allocation
    private var dailyView: some View {
        let result = store.supplyDemand(for: day)
        return VStack(spacing: Space.l) {
            daySelector
            coverageCard(demand: result.demandEggs, available: result.availableEggs,
                         coverage: result.coverage, isShort: result.isShort,
                         deficit: result.deficitEggs, surplus: result.surplusEggs)

            if result.allocations.isEmpty {
                BRCard {
                    EmptyState(systemImage: "tray",
                               title: "No deliveries \(day == .today ? "today" : "this day")",
                               message: "No customers are scheduled for \(day.short). Pick another day or add customers.")
                }
            } else {
                VStack(alignment: .leading, spacing: Space.m) {
                    SectionHeader(title: "Allocation", systemImage: "arrow.triangle.branch")
                    if result.isShort {
                        Text("Eggs are short — every order is trimmed proportionally. Cut orders are flagged.")
                            .font(AppFont.caption).foregroundColor(AppColor.warn)
                    }
                    ForEach(result.allocations) { a in
                        AllocationRow(alloc: a)
                    }
                }
            }
        }
    }

    private var weeklyView: some View {
        let demand = store.weeklyDemandEggs
        let available = store.availableForSaleEggs
        let coverage = demand > 0 ? min(1, available / demand) : 1
        return VStack(spacing: Space.l) {
            coverageCard(demand: demand, available: available, coverage: coverage,
                         isShort: demand > available, deficit: max(0, demand - available),
                         surplus: max(0, available - demand))
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "Weekly orders", systemImage: "calendar")
                ForEach(store.activeCustomers.sorted { $0.unitsPerWeek > $1.unitsPerWeek }) { c in
                    BRCard(padding: Space.m) {
                        HStack {
                            AvatarCircle(initials: c.initials, size: 38)
                            Text(c.name).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                            Spacer()
                            Text("\(store.unitsString(Double(c.unitsPerWeek)))/wk")
                                .font(AppFont.callout).foregroundColor(AppColor.textSecondary)
                            Text("\(Int(Double(c.unitsPerWeek) * store.eggsPerUnit)) eggs")
                                .font(AppFont.caption).foregroundColor(AppColor.textInactive)
                        }
                    }
                }
            }
        }
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

    private func coverageCard(demand: Double, available: Double, coverage: Double,
                              isShort: Bool, deficit: Double, surplus: Double) -> some View {
        BRCard {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Available eggs").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                        Text("\(Int(available))").font(AppFont.number)
                            .foregroundColor(isShort ? AppColor.warn : AppColor.success)
                    }
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(AppColor.textInactive)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Demand").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                        Text("\(Int(demand))").font(AppFont.number).foregroundColor(AppColor.textPrimary)
                    }
                }
                BRProgressBar(ratio: coverage, tint: isShort ? AppColor.warn : AppColor.success, height: 12)
                HStack {
                    Text("\(Int(coverage * 100))% of demand covered")
                        .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    Spacer()
                    if isShort {
                        StatusPill(text: "Short \(Int(deficit))", color: AppColor.warn, filled: true)
                    } else {
                        StatusPill(text: "+\(Int(surplus)) spare", color: AppColor.success, filled: true)
                    }
                }
            }
        }
    }

    enum DayMode: String, Identifiable { case today, week; var id: String { rawValue }
        var label: String { self == .today ? "By day" : "This week" } }
}

private struct AllocationRow: View {
    @EnvironmentObject private var store: AppStore
    let alloc: Allocation
    var body: some View {
        BRCard(padding: Space.m) {
            VStack(spacing: Space.s) {
                HStack {
                    Text(alloc.customerName).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                    Spacer()
                    if alloc.isCut {
                        StatusPill(text: "Cut", color: AppColor.warn, filled: true)
                    } else {
                        StatusPill(text: "Full", color: AppColor.success)
                    }
                }
                BRProgressBar(ratio: alloc.fulfillmentRatio,
                              tint: alloc.isCut ? AppColor.warn : AppColor.success, height: 8)
                HStack {
                    Text("Wants \(Int(alloc.requestedEggs)) eggs")
                        .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    Spacer()
                    Text("Gets \(Int(alloc.allocatedEggs)) eggs")
                        .font(AppFont.caption).foregroundColor(AppColor.textPrimary)
                }
            }
        }
    }
}

// MARK: - Stock On Hand (Feature 09)

struct StockView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false

    var body: some View {
        VStack(spacing: Space.l) {
            BRCard {
                VStack(spacing: Space.m) {
                    Text("Eggs on hand").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    Text("\(Int(store.currentStockEggs))")
                        .font(AppFont.rounded(48, .heavy))
                        .foregroundColor(store.currentStockEggs >= 0 ? AppColor.textPrimary : AppColor.danger)
                    Text("available to sell")
                        .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: Space.m) {
                StatTile(title: "Collected today", value: "\(Int(store.collectedTodayEggs))",
                         systemImage: "tray.and.arrow.down.fill", tint: AppColor.success)
                StatTile(title: "Reserved", value: "\(Int(store.reservedEggs))",
                         systemImage: "lock.fill", tint: AppColor.yolk)
                StatTile(title: "Breakage", value: "\(Int(store.brokenTotalEggs))",
                         systemImage: "exclamationmark.triangle.fill", tint: AppColor.danger)
            }

            PrimaryButton(title: "Add Stock Movement", systemImage: "plus") { showAdd = true }

            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "Ledger", systemImage: "list.bullet.rectangle")
                if store.stock.isEmpty {
                    Text("No movements yet.").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                } else {
                    ForEach(store.stock.sorted { $0.date > $1.date }) { m in
                        StockRow(movement: m)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddStockSheet().environmentObject(store)
        }
    }
}

private struct StockRow: View {
    @EnvironmentObject private var store: AppStore
    let movement: StockMovement
    var body: some View {
        BRCard(padding: Space.m) {
            HStack(spacing: Space.m) {
                Image(systemName: movement.kind.icon)
                    .foregroundColor(movement.kind.color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(movement.kind.title).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                    Text(movement.date, style: .date).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    if !movement.note.isEmpty {
                        Text(movement.note).font(AppFont.caption).foregroundColor(AppColor.textInactive)
                    }
                }
                Spacer()
                Text("\(movement.signedEggs > 0 ? "+" : "")\(Int(movement.signedEggs))")
                    .font(AppFont.headline)
                    .foregroundColor(movement.signedEggs >= 0 ? AppColor.success : AppColor.danger)
                Button(action: { withAnimation { store.deleteStock(movement) } }) {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundColor(AppColor.textInactive)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

private struct AddStockSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var kind: StockKind = .collected
    @State private var eggs = 12
    @State private var note = ""

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        FieldRow(label: "Type") {
                            VStack(spacing: Space.s) {
                                ForEach(StockKind.allCases) { k in
                                    Button(action: { withAnimation(Motion.snappy) { kind = k } }) {
                                        HStack {
                                            Image(systemName: k.icon).foregroundColor(k.color).frame(width: 22)
                                            Text(k.title).font(AppFont.body).foregroundColor(AppColor.textPrimary)
                                            Spacer()
                                            Image(systemName: kind == k ? "largecircle.fill.circle" : "circle")
                                                .foregroundColor(kind == k ? AppColor.primary : AppColor.border)
                                        }
                                        .padding(.vertical, 10).padding(.horizontal, Space.m)
                                        .background(kind == k ? AppColor.primary.opacity(0.07) : AppColor.card)
                                        .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                                            .stroke(kind == k ? AppColor.primary : AppColor.border, lineWidth: 1))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        FieldRow(label: "Eggs") {
                            HStack {
                                QuantityStepper(value: $eggs, range: 1...100000, step: 6, unit: "eggs")
                                Spacer()
                            }
                        }
                        FieldRow(label: "Note") {
                            BRTextField(placeholder: "Optional note", text: $note, systemImage: "note.text")
                        }
                        PrimaryButton(title: "Add Movement", systemImage: "checkmark") {
                            store.addStock(kind: kind, eggs: Double(eggs), note: note)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .padding(.horizontal, Space.l).padding(.top, Space.s).padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Stock Movement")
            .navigationBarItems(leading:
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppColor.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
