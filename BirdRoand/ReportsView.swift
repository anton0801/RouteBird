//
//  ReportsView.swift
//  BirdRoand
//
//  Feature 11 — reports across sales, demand/supply, debts, trays and revenue,
//  with real CSV and PDF export through the system share sheet.
//

import SwiftUI
import UIKit

struct ReportsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.l) {
                    summaryGrid

                    BRCard {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionHeader(title: "Demand vs supply (this week)", systemImage: "chart.bar.fill")
                            let demand = store.weeklyDemandEggs
                            let available = store.availableForSaleEggs
                            line("Weekly demand", "\(Int(demand)) eggs")
                            line("Available now", "\(Int(available)) eggs")
                            line("Balance", "\(Int(available - demand)) eggs")
                        }
                    }

                    BRCard {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionHeader(title: "Debts", systemImage: "exclamationmark.circle.fill")
                            if store.debtors.isEmpty {
                                Text("No outstanding debts.").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                            } else {
                                ForEach(store.debtors) { c in
                                    line(c.name, store.format(store.debt(for: c.id)))
                                }
                            }
                        }
                    }

                    BRCard {
                        VStack(alignment: .leading, spacing: Space.m) {
                            SectionHeader(title: "Trays out", systemImage: "tray.full.fill")
                            if store.customersWithTrays.isEmpty {
                                Text("All trays returned.").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                            } else {
                                ForEach(store.customersWithTrays) { c in
                                    line(c.name, "\(store.traysOnHand(for: c.id)) trays")
                                }
                            }
                        }
                    }

                    VStack(spacing: Space.m) {
                        PrimaryButton(title: "Export CSV", systemImage: "tablecells") { exportCSV() }
                        SecondaryButton(title: "Export PDF", systemImage: "doc.richtext") { exportPDF() }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    private var summaryGrid: some View {
        VStack(spacing: Space.m) {
            HStack(spacing: Space.m) {
                StatTile(title: "Revenue", value: store.format(store.totalRevenue),
                         systemImage: "dollarsign.circle.fill", tint: AppColor.success)
                StatTile(title: "Debt", value: store.format(store.totalDebt),
                         systemImage: "exclamationmark.circle.fill", tint: AppColor.warn)
            }
            HStack(spacing: Space.m) {
                StatTile(title: "Customers", value: "\(store.customers.count)",
                         systemImage: "person.2.fill", tint: AppColor.primary)
                StatTile(title: "Trays out", value: "\(store.totalTraysOut)",
                         systemImage: "tray.full.fill", tint: AppColor.yolk)
            }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
            Spacer()
            Text(value).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
        }
    }

    // MARK: - Export

    private func exportCSV() {
        guard let url = ReportExporter.writeCSV(store: store) else { return }
        shareItems = [url]
        showShare = true
    }

    private func exportPDF() {
        guard let url = ReportExporter.writePDF(store: store) else { return }
        shareItems = [url]
        showShare = true
    }
}

// MARK: - Share sheet bridge

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Exporter

enum ReportExporter {

    static func writeCSV(store: AppStore) -> URL? {
        var rows: [String] = []
        rows.append("Bird Roand — Customer Report")
        rows.append("Name,Phone,Zone,Units/Week,Debt,Trays Out")
        for c in store.customers.sorted(by: { $0.name < $1.name }) {
            let debt = String(format: "%.2f", max(0, store.debt(for: c.id)))
            rows.append("\(esc(c.name)),\(esc(c.phone)),\(esc(c.zone)),\(c.unitsPerWeek),\(debt),\(store.traysOnHand(for: c.id))")
        }
        rows.append("")
        rows.append("Payments")
        rows.append("Customer,Date,Type,Amount")
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for p in store.payments.sorted(by: { $0.date > $1.date }) {
            let name = store.customer(p.customerId)?.name ?? "Customer"
            rows.append("\(esc(name)),\(df.string(from: p.date)),\(p.kind.title),\(String(format: "%.2f", p.amount))")
        }
        rows.append("")
        rows.append("Summary")
        rows.append("Total revenue,\(String(format: "%.2f", store.totalRevenue))")
        rows.append("Outstanding debt,\(String(format: "%.2f", store.totalDebt))")
        rows.append("Eggs on hand,\(Int(store.currentStockEggs))")
        rows.append("Weekly demand (eggs),\(Int(store.weeklyDemandEggs))")

        let csv = rows.joined(separator: "\n")
        return write(csv, filename: "BirdRoand-Report.csv")
    }

    static func writePDF(store: AppStore) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BirdRoand-Report.pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = 48
                let left: CGFloat = 40

                func draw(_ text: String, font: UIFont, color: UIColor = .black, indent: CGFloat = 0) {
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    (text as NSString).draw(at: CGPoint(x: left + indent, y: y), withAttributes: attrs)
                    y += font.lineHeight + 4
                    if y > pageRect.height - 60 { ctx.beginPage(); y = 48 }
                }

                draw("Bird Roand", font: .systemFont(ofSize: 26, weight: .heavy),
                     color: UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1))
                draw("Sales report", font: .systemFont(ofSize: 14, weight: .regular), color: .darkGray)
                let df = DateFormatter(); df.dateStyle = .long
                draw(df.string(from: Date()), font: .systemFont(ofSize: 11), color: .gray)
                y += 10

                draw("Summary", font: .systemFont(ofSize: 16, weight: .bold))
                draw("Total revenue: \(store.format(store.totalRevenue))", font: .systemFont(ofSize: 12), indent: 8)
                draw("Outstanding debt: \(store.format(store.totalDebt))", font: .systemFont(ofSize: 12), indent: 8)
                draw("Eggs on hand: \(Int(store.currentStockEggs))", font: .systemFont(ofSize: 12), indent: 8)
                draw("Weekly demand: \(Int(store.weeklyDemandEggs)) eggs", font: .systemFont(ofSize: 12), indent: 8)
                draw("Trays out: \(store.totalTraysOut)", font: .systemFont(ofSize: 12), indent: 8)
                y += 10

                draw("Customers", font: .systemFont(ofSize: 16, weight: .bold))
                for c in store.customers.sorted(by: { $0.name < $1.name }) {
                    let debt = store.debt(for: c.id)
                    let detail = "\(c.name) — \(c.unitsPerWeek) \(store.sellFormat.unitLabelPlural)/wk · debt \(store.format(max(0, debt))) · \(store.traysOnHand(for: c.id)) trays"
                    draw(detail, font: .systemFont(ofSize: 11), indent: 8)
                }
                y += 10

                if !store.debtors.isEmpty {
                    draw("Outstanding debts", font: .systemFont(ofSize: 16, weight: .bold))
                    for c in store.debtors {
                        draw("\(c.name): \(store.format(store.debt(for: c.id)))",
                             font: .systemFont(ofSize: 11),
                             color: UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1), indent: 8)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: helpers

    private static func esc(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func write(_ text: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try text.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
