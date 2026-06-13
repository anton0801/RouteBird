//
//  OrdersView.swift
//  BirdRoand
//
//  Feature 06 — all orders by date: recurring, one-off and cancellations, with
//  a filter and an add-order sheet.
//

import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter: Filter = .all
    @State private var showAdd = false

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", planned = "Planned", done = "Done", cancelled = "Cancelled"
        var id: String { rawValue }
    }

    private var orders: [Order] {
        let sorted = store.orders.sorted { $0.date > $1.date }
        switch filter {
        case .all:       return sorted
        case .planned:   return sorted.filter { $0.status == .planned }
        case .done:      return sorted.filter { $0.status == .delivered || $0.status == .paid }
        case .cancelled: return sorted.filter { $0.status == .cancelled }
        }
    }

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.l) {
                    BRSegmented(options: Filter.allCases, selection: $filter) { $0.rawValue }
                    PrimaryButton(title: "New One-off Order", systemImage: "plus") { showAdd = true }

                    if orders.isEmpty {
                        BRCard { EmptyState(systemImage: "list.bullet.rectangle",
                                            title: "No orders",
                                            message: "Recurring orders appear here once their delivery day comes around, or add a one-off order.") }
                    } else {
                        ForEach(orders) { o in
                            OrderManageRow(order: o)
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
            }
        }
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddOrderSheet().environmentObject(store)
        }
    }
}

private struct OrderManageRow: View {
    @EnvironmentObject private var store: AppStore
    let order: Order

    var body: some View {
        BRCard(padding: Space.m) {
            VStack(spacing: Space.s) {
                HStack(spacing: Space.m) {
                    Image(systemName: order.status.icon).foregroundColor(order.status.color).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.customer(order.customerId)?.name ?? "Customer")
                            .font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                        HStack(spacing: 6) {
                            Text(order.date, style: .date).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                            if order.isRecurring {
                                Image(systemName: "repeat").font(.system(size: 10)).foregroundColor(AppColor.primary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.unitsString(order.units)).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                        Text(store.format(order.amount)).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                    }
                }
                HStack(spacing: Space.s) {
                    if order.status == .planned {
                        SmallActionButton(title: "Delivered", icon: "checkmark", tint: AppColor.success) {
                            withAnimation { store.setOrderStatus(order, .delivered) }
                        }
                        SmallActionButton(title: "Cancel", icon: "xmark", tint: AppColor.danger) {
                            withAnimation { store.setOrderStatus(order, .cancelled) }
                        }
                    } else if order.status == .delivered {
                        SmallActionButton(title: "Mark paid", icon: "dollarsign", tint: AppColor.success) {
                            withAnimation { store.setOrderStatus(order, .paid) }
                        }
                        StatusPill(text: order.status.title, color: order.status.color)
                    } else {
                        StatusPill(text: order.status.title, color: order.status.color)
                        Spacer()
                        Button(action: { withAnimation { store.deleteOrder(order) } }) {
                            Image(systemName: "trash").font(.system(size: 13)).foregroundColor(AppColor.textInactive)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

private struct AddOrderSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var customerId: UUID?
    @State private var date = Date()
    @State private var units = 1
    @State private var didInit = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        if store.customers.isEmpty {
                            BRCard { EmptyState(systemImage: "person.crop.circle.badge.plus",
                                                title: "No customers",
                                                message: "Add a customer first to create an order.") }
                        } else {
                            FieldRow(label: "Customer") {
                                Picker("Customer", selection: Binding(
                                    get: { customerId ?? store.customers.first?.id },
                                    set: { customerId = $0 })) {
                                    ForEach(store.customers) { c in Text(c.name).tag(Optional(c.id)) }
                                }
                                .pickerStyle(WheelPickerStyle()).frame(height: 110).clipped()
                            }
                            FieldRow(label: "Date") {
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            FieldRow(label: "Quantity (\(store.sellFormat.unitLabelPlural))") {
                                HStack {
                                    QuantityStepper(value: $units, range: 1...500,
                                                    unit: store.sellFormat.unitLabelPlural)
                                    Spacer()
                                    Text(store.format(Double(units) * store.unitPrice))
                                        .font(AppFont.headline).foregroundColor(AppColor.primary)
                                }
                            }
                            PrimaryButton(title: "Add Order", systemImage: "checkmark",
                                          enabled: (customerId ?? store.customers.first?.id) != nil) {
                                add()
                            }
                        }
                    }
                    .padding(.horizontal, Space.l).padding(.top, Space.s).padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("New Order")
            .navigationBarItems(leading:
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppColor.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !didInit else { return }
            didInit = true
            customerId = store.customers.first?.id
        }
    }

    private func add() {
        guard let id = customerId ?? store.customers.first?.id else { return }
        store.addOrder(Order(customerId: id, date: date, units: Double(units),
                             status: .planned, isRecurring: false, unitPriceSnapshot: store.unitPrice))
        presentationMode.wrappedValue.dismiss()
    }
}
