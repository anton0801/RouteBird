//
//  TrayReturnsView.swift
//  BirdRoand
//
//  Feature 07 — tara/tray accounting. Tracks how many trays are out with each
//  customer and records returns (or new trays given out).
//

import SwiftUI

struct TrayReturnsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: Space.l) {
            BRCard {
                VStack(spacing: Space.s) {
                    Text("Trays out with customers").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    Text("\(store.totalTraysOut)")
                        .font(AppFont.rounded(44, .heavy)).foregroundColor(AppColor.primary)
                    Text("waiting to come back").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "By customer", systemImage: "tray.full.fill")
                if store.customersWithTrays.isEmpty {
                    BRCard { EmptyState(systemImage: "tray",
                                        title: "No trays out",
                                        message: "Every tray is accounted for. Trays go out automatically when you log a delivery.") }
                } else {
                    ForEach(store.customersWithTrays) { c in
                        TrayCustomerRow(customer: c)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "Recent movements", systemImage: "clock.arrow.circlepath")
                let recent = store.trays.sorted { $0.date > $1.date }.prefix(8)
                if recent.isEmpty {
                    Text("No tray movements yet.").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                } else {
                    ForEach(Array(recent)) { t in
                        BRCard(padding: Space.m) {
                            HStack {
                                Image(systemName: t.direction == .out ? "arrow.up.right.circle.fill" : "arrow.uturn.backward.circle.fill")
                                    .foregroundColor(t.direction == .out ? AppColor.yolk : AppColor.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.customer(t.customerId)?.name ?? "Customer")
                                        .font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                                    Text(t.date, style: .date).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                                }
                                Spacer()
                                Text("\(t.direction == .out ? "+" : "-")\(t.count)")
                                    .font(AppFont.headline)
                                    .foregroundColor(t.direction == .out ? AppColor.yolk : AppColor.success)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TrayCustomerRow: View {
    @EnvironmentObject private var store: AppStore
    let customer: Customer
    @State private var showSheet = false
    var body: some View {
        BRCard(padding: Space.m) {
            HStack(spacing: Space.m) {
                AvatarCircle(initials: customer.initials, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.name).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                    Text("\(store.traysOnHand(for: customer.id)) trays out")
                        .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
                SmallActionButton(title: "Update", icon: "tray.and.arrow.up", tint: AppColor.primary) {
                    showSheet = true
                }
                .frame(width: 110)
            }
        }
        .sheet(isPresented: $showSheet) {
            ReturnTraysSheet(customer: customer).environmentObject(store)
        }
    }
}

// MARK: - Return trays sheet (shared with customer detail)

struct ReturnTraysSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let customer: Customer

    @State private var direction: TrayDirection = .in
    @State private var count = 1

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        BRCard {
                            VStack(spacing: Space.s) {
                                Text("\(customer.name) holds")
                                    .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                                Text("\(store.traysOnHand(for: customer.id)) trays")
                                    .font(AppFont.rounded(34, .heavy)).foregroundColor(AppColor.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        FieldRow(label: "Action") {
                            Picker("Action", selection: $direction) {
                                Text("Returned to me").tag(TrayDirection.in)
                                Text("Gave out more").tag(TrayDirection.out)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        FieldRow(label: "How many trays") {
                            HStack {
                                QuantityStepper(value: $count, range: 1...500, unit: "trays")
                                Spacer()
                            }
                        }

                        PrimaryButton(title: direction == .in ? "Record Return" : "Record Hand-out",
                                      systemImage: "checkmark") {
                            store.recordTray(customerId: customer.id, direction: direction, count: count)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .padding(.horizontal, Space.l).padding(.top, Space.s).padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Trays")
            .navigationBarItems(leading:
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppColor.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
