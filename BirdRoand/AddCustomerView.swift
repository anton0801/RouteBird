//
//  AddCustomerView.swift
//  BirdRoand
//
//  Feature 02 — create or edit a customer. Validates the name, lets you set the
//  recurring order, delivery days, method and preferences, then persists.
//

import SwiftUI

struct AddCustomerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.presentationMode) private var presentationMode

    /// When non-nil we edit in place; otherwise we create.
    var editing: Customer? = nil

    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var zone = ""
    @State private var unitsPerWeek = 2
    @State private var deliveryDays: Set<Int> = [Weekday.mon.rawValue, Weekday.thu.rawValue]
    @State private var method: DeliveryMethod = .homeDelivery
    @State private var prefs = ""
    @State private var loaded = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !deliveryDays.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.l) {
                        FieldRow(label: "Name") {
                            BRTextField(placeholder: "Customer name", text: $name,
                                        systemImage: "person.fill")
                        }
                        FieldRow(label: "Phone") {
                            BRTextField(placeholder: "Phone (optional)", text: $phone,
                                        systemImage: "phone.fill", keyboard: .phonePad)
                        }
                        FieldRow(label: "Address") {
                            BRTextField(placeholder: "Street address", text: $address,
                                        systemImage: "house.fill")
                        }
                        FieldRow(label: "Zone / area") {
                            BRTextField(placeholder: "e.g. North", text: $zone,
                                        systemImage: "map.fill")
                        }

                        FieldRow(label: "Regular order (\(store.sellFormat.unitLabelPlural) / week)") {
                            HStack {
                                QuantityStepper(value: $unitsPerWeek, range: 0...200,
                                                unit: store.sellFormat.unitLabelPlural)
                                Spacer()
                            }
                        }

                        FieldRow(label: "Delivery days") {
                            WeekdayPicker(selected: $deliveryDays)
                        }

                        FieldRow(label: "Delivery method") {
                            VStack(spacing: Space.s) {
                                ForEach(DeliveryMethod.allCases) { m in
                                    methodRow(m)
                                }
                            }
                        }

                        FieldRow(label: "Preferences / notes") {
                            BRTextField(placeholder: "e.g. brown eggs, large only", text: $prefs,
                                        systemImage: "note.text")
                        }

                        PrimaryButton(title: editing == nil ? "Save Customer" : "Update Customer",
                                      systemImage: "checkmark", enabled: isValid) {
                            save()
                        }
                        if !isValid {
                            Text("Enter a name and pick at least one delivery day.")
                                .font(AppFont.caption)
                                .foregroundColor(AppColor.danger)
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle(editing == nil ? "New Customer" : "Edit Customer")
            .navigationBarItems(leading:
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppColor.textSecondary)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear(perform: loadIfNeeded)
    }

    private func methodRow(_ m: DeliveryMethod) -> some View {
        Button(action: {
            withAnimation(Motion.snappy) { method = m }
        }) {
            HStack(spacing: Space.m) {
                Image(systemName: m.icon)
                    .foregroundColor(method == m ? AppColor.primary : AppColor.textInactive)
                    .frame(width: 22)
                Text(m.title)
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
                Image(systemName: method == m ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(method == m ? AppColor.primary : AppColor.border)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, Space.m)
            .background(method == m ? AppColor.primary.opacity(0.07) : AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                    .stroke(method == m ? AppColor.primary : AppColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadIfNeeded() {
        guard let c = editing, !loaded else { return }
        name = c.name; phone = c.phone; address = c.address; zone = c.zone
        unitsPerWeek = c.unitsPerWeek
        deliveryDays = Set(c.deliveryDays)
        method = c.deliveryMethod
        prefs = c.prefs
        loaded = true
    }

    private func save() {
        hideKeyboard()
        if var c = editing {
            c.name = name.trimmingCharacters(in: .whitespaces)
            c.phone = phone; c.address = address; c.zone = zone
            c.unitsPerWeek = unitsPerWeek
            c.deliveryDays = Array(deliveryDays)
            c.deliveryMethod = method
            c.prefs = prefs
            store.updateCustomer(c)
        } else {
            let c = Customer(name: name.trimmingCharacters(in: .whitespaces),
                             phone: phone, address: address, zone: zone,
                             unitsPerWeek: unitsPerWeek,
                             deliveryDays: Array(deliveryDays),
                             deliveryMethod: method, prefs: prefs)
            store.addCustomer(c)
        }
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Weekday picker chips

struct WeekdayPicker: View {
    @Binding var selected: Set<Int>
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let on = selected.contains(day.rawValue)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(Motion.snappy) {
                        if on { selected.remove(day.rawValue) } else { selected.insert(day.rawValue) }
                    }
                }) {
                    Text(day.letter)
                        .font(AppFont.callout)
                        .foregroundColor(on ? .white : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(on ? AppColor.primary : AppColor.depth)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
