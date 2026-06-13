//
//  CustomerDetailView.swift
//  BirdRoand
//
//  Feature 03 — customer detail: order history, debt, trays on hand and notes,
//  with quick actions to collect payment, return trays, edit, or delete.
//

import SwiftUI

struct CustomerDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let customerId: UUID

    @State private var showEdit = false
    @State private var showCollect = false
    @State private var showReturnTrays = false
    @State private var showDeleteAlert = false

    private var customer: Customer? { store.customer(customerId) }

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()
            if let customer = customer {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        header(customer)
                        statRow(customer)
                        quickActions(customer)
                        ordersSection
                        paymentsSection
                        deleteButton
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxl)
                }
            } else {
                EmptyState(systemImage: "person.crop.circle.badge.xmark",
                           title: "Customer removed",
                           message: "This customer no longer exists.")
            }
        }
        .navigationTitle(customer?.name ?? "Customer")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            Button(action: { showEdit = true }) {
                Image(systemName: "square.and.pencil").font(.system(size: 16, weight: .semibold))
            }
        )
        .sheet(isPresented: $showEdit) {
            if let c = customer { AddCustomerView(editing: c).environmentObject(store) }
        }
        .sheet(isPresented: $showCollect) {
            CollectPaymentSheet(customer: customer).environmentObject(store)
        }
        .sheet(isPresented: $showReturnTrays) {
            if let c = customer { ReturnTraysSheet(customer: c).environmentObject(store) }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete customer?"),
                message: Text("This removes the customer and all their orders, payments and tray records."),
                primaryButton: .destructive(Text("Delete")) {
                    if let c = customer { store.deleteCustomer(c) }
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Sections

    private func header(_ c: Customer) -> some View {
        BRCard {
            VStack(spacing: Space.m) {
                HStack(spacing: Space.m) {
                    AvatarCircle(initials: c.initials, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.name).font(AppFont.title).foregroundColor(AppColor.textPrimary)
                        Label(c.deliveryMethod.title, systemImage: c.deliveryMethod.icon)
                            .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                }
                if !c.phone.isEmpty { infoRow("phone.fill", c.phone) }
                if !c.address.isEmpty { infoRow("house.fill", c.address) }
                if !c.zone.isEmpty { infoRow("map.fill", "Zone: \(c.zone)") }
                infoRow("calendar", c.deliveryWeekdays.map { $0.short }.joined(separator: ", "))
                if !c.prefs.isEmpty { infoRow("note.text", c.prefs) }
            }
        }
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(AppColor.textInactive)
                .frame(width: 18)
            Text(text).font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
            Spacer()
        }
    }

    private func statRow(_ c: Customer) -> some View {
        let debt = store.debt(for: c.id)
        return HStack(spacing: Space.m) {
            StatTile(title: "Debt", value: store.format(max(0, debt)),
                     systemImage: "exclamationmark.circle.fill",
                     tint: debt > 0.01 ? AppColor.warn : AppColor.success)
            StatTile(title: "Trays out", value: "\(store.traysOnHand(for: c.id))",
                     systemImage: "tray.full.fill", tint: AppColor.primary)
            StatTile(title: "Per week", value: store.unitsString(Double(c.unitsPerWeek)),
                     systemImage: "repeat", tint: AppColor.yolk)
        }
    }

    private func quickActions(_ c: Customer) -> some View {
        HStack(spacing: Space.m) {
            SecondaryButton(title: "Collect Pay", systemImage: "dollarsign.circle.fill") {
                showCollect = true
            }
            SecondaryButton(title: "Return Trays", systemImage: "arrow.uturn.backward") {
                showReturnTrays = true
            }
        }
    }

    private var ordersSection: some View {
        let orders = store.orders(for: customerId)
        return VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "Order history", systemImage: "shippingbox.fill")
            if orders.isEmpty {
                Text("No orders yet.")
                    .font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
            } else {
                ForEach(orders) { o in
                    BRCard(padding: Space.m) {
                        HStack {
                            Image(systemName: o.status.icon).foregroundColor(o.status.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.unitsString(o.units))
                                    .font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                                Text(o.date, style: .date)
                                    .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                            }
                            Spacer()
                            Text(store.format(o.amount))
                                .font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                            StatusPill(text: o.status.title, color: o.status.color)
                        }
                    }
                }
            }
        }
    }

    private var paymentsSection: some View {
        let payments = store.payments(for: customerId)
        return VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "Payments", systemImage: "creditcard.fill")
            if payments.isEmpty {
                Text("No payments recorded.")
                    .font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
            } else {
                ForEach(payments) { p in
                    BRCard(padding: Space.m) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill").foregroundColor(AppColor.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.kind.title)
                                    .font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                                Text(p.date, style: .date)
                                    .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                            }
                            Spacer()
                            Text(store.format(p.amount))
                                .font(AppFont.headline).foregroundColor(AppColor.success)
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(action: { showDeleteAlert = true }) {
            HStack(spacing: Space.s) {
                Image(systemName: "trash")
                Text("Delete customer")
            }
            .font(AppFont.callout)
            .foregroundColor(AppColor.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AppColor.danger.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
