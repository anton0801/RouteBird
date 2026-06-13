//
//  CustomersView.swift
//  BirdRoand
//
//  Feature 02/03 entry — searchable customer list. Each row links to the
//  customer detail; the toolbar add button opens the new-customer form.
//

import SwiftUI

struct CustomersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var showAdd = false

    private var filtered: [Customer] {
        let base = store.customers.sorted { $0.name < $1.name }
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.zone.localizedCaseInsensitiveContains(search) ||
            $0.phone.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.m) {
                        BRTextField(placeholder: "Search customers", text: $search,
                                    systemImage: "magnifyingglass")

                        summaryRow

                        if filtered.isEmpty {
                            BRCard {
                                EmptyState(systemImage: "person.2",
                                           title: store.customers.isEmpty ? "No customers yet" : "No matches",
                                           message: store.customers.isEmpty
                                            ? "Add your first customer to start planning rounds."
                                            : "Try a different search term.")
                            }
                        } else {
                            ForEach(filtered) { customer in
                                NavigationLink(destination: CustomerDetailView(customerId: customer.id)) {
                                    CustomerRow(customer: customer)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Customers")
            .navigationBarItems(trailing:
                Button(action: { showAdd = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showAdd) {
            AddCustomerView().environmentObject(store)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: Space.m) {
            StatTile(title: "Customers", value: "\(store.customers.count)",
                     systemImage: "person.2.fill", tint: AppColor.primary)
            StatTile(title: "Weekly demand", value: "\(Int(store.weeklyDemandEggs)) eggs",
                     systemImage: "calendar", tint: AppColor.yolk)
        }
    }
}

// MARK: - Row

struct CustomerRow: View {
    @EnvironmentObject private var store: AppStore
    let customer: Customer

    var body: some View {
        let debt = store.debt(for: customer.id)
        let trays = store.traysOnHand(for: customer.id)
        return BRCard(padding: Space.m) {
            HStack(spacing: Space.m) {
                AvatarCircle(initials: customer.initials)
                VStack(alignment: .leading, spacing: 3) {
                    Text(customer.name)
                        .font(AppFont.headline)
                        .foregroundColor(AppColor.textPrimary)
                    HStack(spacing: Space.s) {
                        Label(store.unitsString(Double(customer.unitsPerWeek)) + "/wk",
                              systemImage: customer.deliveryMethod.icon)
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }
                    HStack(spacing: 6) {
                        if debt > 0.01 {
                            StatusPill(text: "Owes \(store.format(debt))", color: AppColor.warn)
                        }
                        if trays > 0 {
                            StatusPill(text: "\(trays) trays", color: AppColor.primary)
                        }
                        if debt <= 0.01 && trays <= 0 {
                            StatusPill(text: "All clear", color: AppColor.success)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColor.textInactive)
            }
        }
    }
}
