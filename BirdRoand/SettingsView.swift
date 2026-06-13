//
//  SettingsView.swift
//  BirdRoand
//
//  Feature 14 — every selling and app setting, fully wired. Theme changes apply
//  instantly app-wide; backup/export share real files; reset clears all data.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showCurrency = false
    @State private var showResetAlert = false
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.l) {
                    sellingCard
                    appearanceCard
                    remindersCard
                    dataCard
                    aboutFooter
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCurrency) {
            CurrencySheet(selected: $store.currencyCode)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("Reset all data?"),
                message: Text("This permanently deletes every customer, order, payment, stock and tray record. This can't be undone."),
                primaryButton: .destructive(Text("Reset")) { store.resetAllData() },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Selling

    private var sellingCard: some View {
        BRCard {
            VStack(alignment: .leading, spacing: Space.l) {
                SectionHeader(title: "Selling", systemImage: "cart.fill")

                FieldRow(label: "Sell format") {
                    Picker("", selection: $store.sellFormat) {
                        ForEach(SellFormat.allCases) { f in Text(f.title).tag(f) }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                FieldRow(label: "Price per \(store.sellFormat.unitLabel)") {
                    HStack(spacing: Space.m) {
                        BRTextField(placeholder: "0.00", text: priceBinding,
                                    systemImage: "tag.fill", keyboard: .decimalPad)
                        Text(store.format(store.unitPrice))
                            .font(AppFont.headline).foregroundColor(AppColor.primary)
                    }
                }

                rowButton(label: "Currency", value: store.currencyCode, icon: "dollarsign.circle.fill") {
                    showCurrency = true
                }

                if store.sellFormat == .byWeight {
                    FieldRow(label: "Average egg weight: \(Int(store.avgEggGrams)) g") {
                        Slider(value: $store.avgEggGrams, in: 40...80, step: 1)
                    }
                }

                FieldRow(label: "Default delivery method") {
                    Picker("", selection: $store.deliveryMethod) {
                        ForEach(DeliveryMethod.allCases) { m in Text(m.title).tag(m) }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        BRCard {
            VStack(alignment: .leading, spacing: Space.l) {
                SectionHeader(title: "Appearance", systemImage: "paintbrush.fill")
                HStack(spacing: Space.m) {
                    ForEach(ThemeMode.allCases) { mode in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(Motion.gentle) { store.themeMode = mode }
                        }) {
                            VStack(spacing: Space.s) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                Text(mode.title).font(AppFont.caption)
                            }
                            .foregroundColor(store.themeMode == mode ? .white : AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.m)
                            .background(store.themeMode == mode ? AppColor.primary : AppColor.depth)
                            .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Reminders link

    private var remindersCard: some View {
        NavigationLink(destination: RemindersView()) {
            BRCard(padding: Space.m) {
                HStack(spacing: Space.m) {
                    IconBadge(systemName: "bell.badge.fill", tint: AppColor.yolk, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reminders").font(AppFont.headline).foregroundColor(AppColor.textPrimary)
                        Text("Collect, deliver, debts, trays").font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColor.textInactive)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Data

    private var dataCard: some View {
        BRCard {
            VStack(alignment: .leading, spacing: Space.l) {
                SectionHeader(title: "Data", systemImage: "externaldrive.fill")
                SecondaryButton(title: "Backup (JSON)", systemImage: "arrow.down.doc") { backup() }
                SecondaryButton(title: "Export CSV", systemImage: "tablecells") {
                    if let url = ReportExporter.writeCSV(store: store) { share(url) }
                }
                SecondaryButton(title: "Export PDF", systemImage: "doc.richtext") {
                    if let url = ReportExporter.writePDF(store: store) { share(url) }
                }
                Button(action: { showResetAlert = true }) {
                    HStack(spacing: Space.s) {
                        Image(systemName: "trash")
                        Text("Reset all data")
                    }
                    .font(AppFont.callout).foregroundColor(AppColor.danger)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(AppColor.danger.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Image(systemName: "square.grid.3x3.fill").foregroundColor(AppColor.primary)
            Text("Bird Roand").font(AppFont.callout).foregroundColor(AppColor.textSecondary)
            Text("From coop to customer · v1.0").font(AppFont.caption).foregroundColor(AppColor.textInactive)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.m)
    }

    // MARK: - Helpers

    private func rowButton(label: String, value: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Image(systemName: icon).foregroundColor(AppColor.primary).frame(width: 22)
                Text(label).font(AppFont.body).foregroundColor(AppColor.textPrimary)
                Spacer()
                Text(value).font(AppFont.callout).foregroundColor(AppColor.textSecondary)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColor.textInactive)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var priceBinding: Binding<String> {
        Binding(
            get: {
                let p = store.unitPrice
                return p == p.rounded() ? String(Int(p)) : String(format: "%.2f", p)
            },
            set: { newValue in
                let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                if let v = Double(cleaned) { store.unitPrice = max(0, v) }
                else if cleaned.isEmpty { store.unitPrice = 0 }
            }
        )
    }

    private func backup() {
        let json = store.exportStateJSON()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BirdRoand-Backup.json")
        try? json.data(using: .utf8)?.write(to: url)
        share(url)
    }

    private func share(_ url: URL) {
        shareItems = [url]
        showShare = true
    }
}

// MARK: - Currency picker sheet

struct CurrencySheet: View {
    @Binding var selected: String
    @Environment(\.presentationMode) private var presentationMode

    private let currencies: [(String, String, String)] = [
        ("USD", "$", "US Dollar"), ("EUR", "€", "Euro"), ("GBP", "£", "British Pound"),
        ("UAH", "₴", "Ukrainian Hryvnia"), ("PLN", "zł", "Polish Zloty"),
        ("CAD", "$", "Canadian Dollar"), ("AUD", "$", "Australian Dollar"),
        ("INR", "₹", "Indian Rupee"), ("JPY", "¥", "Japanese Yen"),
        ("CHF", "Fr", "Swiss Franc"), ("BRL", "R$", "Brazilian Real"),
        ("MXN", "$", "Mexican Peso"), ("ZAR", "R", "South African Rand")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                AppColor.base.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.s) {
                        ForEach(currencies, id: \.0) { code, symbol, name in
                            Button(action: {
                                selected = code
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack(spacing: Space.m) {
                                    Text(symbol)
                                        .font(AppFont.headline).foregroundColor(AppColor.primary)
                                        .frame(width: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(code).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                                        Text(name).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                                    }
                                    Spacer()
                                    if selected == code {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(AppColor.success)
                                    }
                                }
                                .padding(Space.m)
                                .background(AppColor.card)
                                .clipShape(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Space.radiusSmall, style: .continuous)
                                    .stroke(selected == code ? AppColor.primary : AppColor.border, lineWidth: 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, Space.l).padding(.top, Space.s).padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Currency")
            .navigationBarItems(trailing:
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(AppColor.primary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
