//
//  AppStore.swift
//  BirdRoand
//
//  Single source of truth. Holds every entity + setting as @Published state,
//  persists the whole thing as one JSON blob in UserDefaults, and exposes the
//  derived numbers the views read (stock balance, debts, demand, income).
//

import Foundation
import SwiftUI
import Combine

final class AppStore: ObservableObject {

    private static let storageKey = "birdroand.state.v1"

    // MARK: - Published entities
    @Published var customers: [Customer] = []
    @Published var orders: [Order] = []
    @Published var payments: [Payment] = []
    @Published var stock: [StockMovement] = []
    @Published var trays: [TrayMovement] = []

    // MARK: - Published settings
    @Published var sellFormat: SellFormat = .dozens
    @Published var unitPrice: Double = 4.0
    @Published var deliveryMethod: DeliveryMethod = .homeDelivery
    @Published var currencyCode: String = "USD"
    @Published var avgEggGrams: Double = 60
    @Published var reservePercent: Double = 0
    @Published var themeMode: ThemeMode = .system
    @Published var hasCompletedOnboarding: Bool = false
    @Published var reminders: ReminderSettings = ReminderSettings()

    private var didSeed = false
    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        load()
        if !didSeed {
            seedSampleData()
            didSeed = true
            persist()
        }
        // Persist on any change (debounced lightly through objectWillChange).
        objectWillChange
            .sink { [weak self] _ in
                guard let self = self, !self.isLoading else { return }
                DispatchQueue.main.async { self.persist() }
            }
            .store(in: &cancellables)
    }

    var colorScheme: ColorScheme? { themeMode.colorScheme }

    var eggsPerUnit: Double { sellFormat.eggsPerUnit(avgEggGrams: avgEggGrams) }

    // MARK: - Persistence

    private func snapshot() -> PersistedState {
        var s = PersistedState()
        s.customers = customers
        s.orders = orders
        s.payments = payments
        s.stock = stock
        s.trays = trays
        s.sellFormat = sellFormat
        s.unitPrice = unitPrice
        s.deliveryMethod = deliveryMethod
        s.currencyCode = currencyCode
        s.avgEggGrams = avgEggGrams
        s.reservePercent = reservePercent
        s.themeMode = themeMode
        s.hasCompletedOnboarding = hasCompletedOnboarding
        s.reminders = reminders
        s.didSeed = didSeed
        return s
    }

    private func apply(_ s: PersistedState) {
        customers = s.customers
        orders = s.orders
        payments = s.payments
        stock = s.stock
        trays = s.trays
        sellFormat = s.sellFormat
        unitPrice = s.unitPrice
        deliveryMethod = s.deliveryMethod
        currencyCode = s.currencyCode
        avgEggGrams = s.avgEggGrams
        reservePercent = s.reservePercent
        themeMode = s.themeMode
        hasCompletedOnboarding = s.hasCompletedOnboarding
        reminders = s.reminders
        didSeed = s.didSeed
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return
        }
        apply(state)
    }

    /// Raw JSON for the Backup feature.
    func exportStateJSON() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(snapshot()),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    // MARK: - Currency formatting

    func format(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    /// Pretty units string respecting the sell format.
    func unitsString(_ units: Double) -> String {
        let rounded = (units * 10).rounded() / 10
        let value: String
        if rounded == rounded.rounded() {
            value = String(Int(rounded))
        } else {
            value = String(format: "%.1f", rounded)
        }
        let label = rounded == 1 ? sellFormat.unitLabel : sellFormat.unitLabelPlural
        return "\(value) \(label)"
    }

    func eggsString(_ eggs: Double) -> String {
        "\(Int(eggs.rounded())) eggs"
    }

    // MARK: - Customers CRUD

    func addCustomer(_ c: Customer) {
        var c = c
        if c.routeOrder == 0 { c.routeOrder = (customers.map { $0.routeOrder }.max() ?? 0) + 1 }
        customers.append(c)
    }

    func updateCustomer(_ c: Customer) {
        if let i = customers.firstIndex(where: { $0.id == c.id }) { customers[i] = c }
    }

    func deleteCustomer(_ c: Customer) {
        customers.removeAll { $0.id == c.id }
        orders.removeAll { $0.customerId == c.id }
        payments.removeAll { $0.customerId == c.id }
        trays.removeAll { $0.customerId == c.id }
    }

    func customer(_ id: UUID) -> Customer? { customers.first { $0.id == id } }

    var activeCustomers: [Customer] { customers.filter { $0.isActive } }

    func customersDelivering(on day: Weekday) -> [Customer] {
        activeCustomers
            .filter { $0.deliversOn(day) }
            .sorted { $0.routeOrder < $1.routeOrder }
    }

    var customersDeliveringToday: [Customer] { customersDelivering(on: .today) }

    // MARK: - Orders CRUD

    func addOrder(_ o: Order) { orders.append(o) }

    func updateOrder(_ o: Order) {
        if let i = orders.firstIndex(where: { $0.id == o.id }) { orders[i] = o }
    }

    func deleteOrder(_ o: Order) { orders.removeAll { $0.id == o.id } }

    func setOrderStatus(_ o: Order, _ status: OrderStatus) {
        guard let i = orders.firstIndex(where: { $0.id == o.id }) else { return }
        let was = orders[i].status
        orders[i].status = status

        // Delivering an order debits the egg stock (sold).
        if status == .delivered && was != .delivered && was != .paid {
            let eggs = orders[i].units * eggsPerUnit
            stock.append(StockMovement(kind: .sold, eggs: eggs,
                                       note: customer(o.customerId)?.name ?? "Order"))
        }
        // Paying an order records a payment if not already recorded.
        if status == .paid && was != .paid {
            if was != .delivered {
                let eggs = orders[i].units * eggsPerUnit
                stock.append(StockMovement(kind: .sold, eggs: eggs,
                                           note: customer(o.customerId)?.name ?? "Order"))
            }
            recordPayment(customerId: o.customerId, orderId: o.id,
                          amount: orders[i].amount, kind: .paid)
        }
    }

    func orders(for customerId: UUID) -> [Order] {
        orders.filter { $0.customerId == customerId }.sorted { $0.date > $1.date }
    }

    /// Today's orders, creating ephemeral ones for scheduled-but-not-yet-saved
    /// recurring customers so the board is never empty.
    func todaysOrders() -> [Order] {
        let today = Calendar.current.startOfDay(for: Date())
        var result = orders.filter {
            Calendar.current.isDate($0.date, inSameDayAs: today) && $0.status != .cancelled
        }
        let existingIds = Set(result.map { $0.customerId })
        for c in customersDeliveringToday where !existingIds.contains(c.id) {
            result.append(
                Order(customerId: c.id, date: today, units: c.unitsPerDelivery,
                      status: .planned, isRecurring: true, unitPriceSnapshot: unitPrice)
            )
        }
        return result
    }

    /// Generate concrete recurring orders for today from the schedule (persisted).
    func generateTodaysRecurringOrders() {
        let today = Calendar.current.startOfDay(for: Date())
        for c in customersDeliveringToday {
            let exists = orders.contains {
                $0.customerId == c.id && Calendar.current.isDate($0.date, inSameDayAs: today)
            }
            if !exists {
                addOrder(Order(customerId: c.id, date: today, units: c.unitsPerDelivery,
                               status: .planned, isRecurring: true, unitPriceSnapshot: unitPrice))
            }
        }
    }

    // MARK: - Payments

    func recordPayment(customerId: UUID, orderId: UUID? = nil,
                       amount: Double, kind: PaymentKind = .paid, note: String = "") {
        payments.append(Payment(customerId: customerId, orderId: orderId,
                                amount: amount, kind: kind, note: note))
    }

    func deletePayment(_ p: Payment) { payments.removeAll { $0.id == p.id } }

    func payments(for customerId: UUID) -> [Payment] {
        payments.filter { $0.customerId == customerId }.sorted { $0.date > $1.date }
    }

    // MARK: - Debt

    /// Money owed by a customer = billed (delivered or paid orders) − money received.
    func debt(for customerId: UUID) -> Double {
        let billed = orders
            .filter { $0.customerId == customerId && ($0.status == .delivered) }
            .reduce(0) { $0 + $1.amount }
        let received = payments
            .filter { $0.customerId == customerId && $0.kind != .debtWriteOff }
            .reduce(0) { $0 + $1.amount }
        let writeoff = payments
            .filter { $0.customerId == customerId && $0.kind == .debtWriteOff }
            .reduce(0) { $0 + $1.amount }
        return billed - received - writeoff
    }

    var totalDebt: Double {
        customers.reduce(0) { $0 + max(0, debt(for: $1.id)) }
    }

    var debtors: [Customer] {
        customers.filter { debt(for: $0.id) > 0.01 }
            .sorted { debt(for: $0.id) > debt(for: $1.id) }
    }

    // MARK: - Trays (tara)

    func recordTray(customerId: UUID, direction: TrayDirection, count: Int) {
        guard count > 0 else { return }
        trays.append(TrayMovement(customerId: customerId, direction: direction, count: count))
    }

    func traysOnHand(for customerId: UUID) -> Int {
        trays.filter { $0.customerId == customerId }.reduce(0) {
            $0 + ($1.direction == .out ? $1.count : -$1.count)
        }
    }

    var totalTraysOut: Int {
        customers.reduce(0) { $0 + max(0, traysOnHand(for: $1.id)) }
    }

    var customersWithTrays: [Customer] {
        customers.filter { traysOnHand(for: $0.id) > 0 }
            .sorted { traysOnHand(for: $0.id) > traysOnHand(for: $1.id) }
    }

    // MARK: - Stock

    func addStock(kind: StockKind, eggs: Double, note: String = "") {
        guard eggs > 0 else { return }
        stock.append(StockMovement(kind: kind, eggs: eggs, note: note))
    }

    func deleteStock(_ m: StockMovement) { stock.removeAll { $0.id == m.id } }

    /// Net eggs currently on hand (collected − sold − broken − reserved + adjust).
    var currentStockEggs: Double {
        stock.reduce(0) { $0 + $1.signedEggs }
    }

    var availableForSaleEggs: Double { max(0, currentStockEggs) }

    var collectedTodayEggs: Double {
        stock.filter { $0.kind == .collected && Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.eggs }
    }

    var brokenTotalEggs: Double {
        stock.filter { $0.kind == .broken }.reduce(0) { $0 + $1.eggs }
    }

    var reservedEggs: Double {
        stock.filter { $0.kind == .reserved }.reduce(0) { $0 + $1.eggs }
    }

    // MARK: - Supply vs Demand

    func supplyDemand(for day: Weekday) -> SupplyDemandResult {
        SupplyDemandEngine.allocate(customers: customers, day: day,
                                    availableEggs: availableForSaleEggs,
                                    eggsPerUnit: eggsPerUnit)
    }

    func dailyDemandEggs(for day: Weekday) -> Double {
        SupplyDemandEngine.dailyDemandEggs(customers: customers, day: day, eggsPerUnit: eggsPerUnit)
    }

    var weeklyDemandEggs: Double {
        SupplyDemandEngine.weeklyDemandEggs(customers: customers, eggsPerUnit: eggsPerUnit)
    }

    // MARK: - Round plan

    func roundPlan(for day: Weekday) -> RoundPlan {
        let result = supplyDemand(for: day)
        var map: [UUID: Allocation] = [:]
        for a in result.allocations { map[a.id] = a }
        return RoundPlanner.plan(customers: customers, day: day,
                                 allocations: map, eggsPerUnit: eggsPerUnit)
    }

    // MARK: - Income

    enum Period: String, CaseIterable, Identifiable {
        case day = "Day", week = "Week", month = "Month"
        var id: String { rawValue }
    }

    private func startDate(for period: Period) -> Date {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .day:   return cal.startOfDay(for: now)
        case .week:  return cal.date(byAdding: .day, value: -7, to: now) ?? now
        case .month: return cal.date(byAdding: .day, value: -30, to: now) ?? now
        }
    }

    func incomeIn(_ period: Period) -> Double {
        let start = startDate(for: period)
        return payments
            .filter { $0.kind != .debtWriteOff && $0.date >= start }
            .reduce(0) { $0 + $1.amount }
    }

    func paymentsCount(in period: Period) -> Int {
        let start = startDate(for: period)
        return payments.filter { $0.kind == .paid && $0.date >= start }.count
    }

    func avgTicket(in period: Period) -> Double {
        let start = startDate(for: period)
        let relevant = payments.filter { $0.kind == .paid && $0.date >= start }
        guard !relevant.isEmpty else { return 0 }
        return relevant.reduce(0) { $0 + $1.amount } / Double(relevant.count)
    }

    var bestCustomer: (Customer, Double)? {
        var totals: [UUID: Double] = [:]
        for p in payments where p.kind != .debtWriteOff {
            totals[p.customerId, default: 0] += p.amount
        }
        guard let best = totals.max(by: { $0.value < $1.value }),
              let c = customer(best.key) else { return nil }
        return (c, best.value)
    }

    var totalRevenue: Double {
        payments.filter { $0.kind != .debtWriteOff }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - History feed

    func historyEvents() -> [HistoryEvent] {
        var events: [HistoryEvent] = []

        for o in orders {
            let name = customer(o.customerId)?.name ?? "Customer"
            switch o.status {
            case .planned:
                events.append(HistoryEvent(id: o.id, date: o.date, kind: .ordered,
                                           title: "Order — \(name)",
                                           subtitle: unitsString(o.units)))
            case .delivered:
                events.append(HistoryEvent(id: o.id, date: o.date, kind: .delivered,
                                           title: "Delivered — \(name)",
                                           subtitle: "\(unitsString(o.units)) · \(format(o.amount))"))
            case .paid:
                events.append(HistoryEvent(id: o.id, date: o.date, kind: .delivered,
                                           title: "Delivered — \(name)",
                                           subtitle: "\(unitsString(o.units)) · \(format(o.amount))"))
            case .cancelled:
                events.append(HistoryEvent(id: o.id, date: o.date, kind: .cancelled,
                                           title: "Cancelled — \(name)",
                                           subtitle: unitsString(o.units)))
            }
        }
        for p in payments {
            let name = customer(p.customerId)?.name ?? "Customer"
            events.append(HistoryEvent(id: p.id, date: p.date, kind: .paid,
                                       title: "\(p.kind.title) — \(name)",
                                       subtitle: format(p.amount)))
        }
        for t in trays where t.direction == .in {
            let name = customer(t.customerId)?.name ?? "Customer"
            events.append(HistoryEvent(id: t.id, date: t.date, kind: .returned,
                                       title: "Trays returned — \(name)",
                                       subtitle: "\(t.count) trays"))
        }
        return events.sorted { $0.date > $1.date }
    }

    // MARK: - Reminders

    func syncReminders() {
        NotificationManager.shared.sync(with: reminders)
    }

    // MARK: - Reset

    func resetAllData() {
        customers = []
        orders = []
        payments = []
        stock = []
        trays = []
        NotificationManager.shared.cancelAll()
        reminders = ReminderSettings()
        persist()
    }

    // MARK: - Seed sample data

    private func seedSampleData() {
        let cal = Calendar.current
        let now = Date()

        var anna = Customer(name: "Anna Bauer", phone: "555-0142",
                            address: "12 Maple St", zone: "North",
                            unitsPerWeek: 3, deliveryDays: [Weekday.mon.rawValue, Weekday.thu.rawValue],
                            deliveryMethod: .homeDelivery, prefs: "Brown eggs", routeOrder: 1)
        let mike = Customer(name: "Mike Toll", phone: "555-0199",
                            address: "8 River Rd", zone: "North",
                            unitsPerWeek: 2, deliveryDays: [Weekday.mon.rawValue, Weekday.fri.rawValue],
                            deliveryMethod: .homeDelivery, prefs: "", routeOrder: 2)
        var cafe = Customer(name: "Corner Café", phone: "555-0110",
                            address: "1 Market Sq", zone: "Center",
                            unitsPerWeek: 8, deliveryDays: [Weekday.mon.rawValue, Weekday.wed.rawValue, Weekday.fri.rawValue],
                            deliveryMethod: .homeDelivery, prefs: "Large only", routeOrder: 3)
        let rosa = Customer(name: "Rosa Klein", phone: "555-0177",
                            address: "Stall 4", zone: "Center",
                            unitsPerWeek: 2, deliveryDays: [Weekday.sat.rawValue],
                            deliveryMethod: .marketStall, prefs: "", routeOrder: 4)
        // make sure at least one customer is due today for a lively board
        let today = Weekday.today.rawValue
        if !anna.deliveryDays.contains(today) { anna.deliveryDays.append(today) }
        if !cafe.deliveryDays.contains(today) { cafe.deliveryDays.append(today) }

        customers = [anna, mike, cafe, rosa]

        // Stock: collected this morning, a little breakage, a small reserve.
        stock = [
            StockMovement(date: cal.date(byAdding: .hour, value: -3, to: now) ?? now,
                          kind: .collected, eggs: 96, note: "Morning collection"),
            StockMovement(date: cal.date(byAdding: .hour, value: -2, to: now) ?? now,
                          kind: .collected, eggs: 84, note: "Second coop"),
            StockMovement(date: cal.date(byAdding: .hour, value: -2, to: now) ?? now,
                          kind: .broken, eggs: 4, note: "Cracked in transit"),
            StockMovement(date: cal.date(byAdding: .hour, value: -1, to: now) ?? now,
                          kind: .reserved, eggs: 12, note: "Family")
        ]

        // A delivered+paid order last week and an outstanding one.
        let lastWeek = cal.date(byAdding: .day, value: -5, to: now) ?? now
        let twoDays = cal.date(byAdding: .day, value: -2, to: now) ?? now
        let o1 = Order(customerId: anna.id, date: lastWeek, units: 1.5,
                       status: .paid, isRecurring: true, unitPriceSnapshot: 4.0)
        let o2 = Order(customerId: cafe.id, date: twoDays, units: 2.7,
                       status: .delivered, isRecurring: true, unitPriceSnapshot: 4.0)
        orders = [o1, o2]

        payments = [
            Payment(customerId: anna.id, orderId: o1.id, amount: o1.amount,
                    date: lastWeek, kind: .paid)
        ]

        // Trays out with the café.
        trays = [
            TrayMovement(customerId: cafe.id,
                         date: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                         direction: .out, count: 3),
            TrayMovement(customerId: anna.id,
                         date: cal.date(byAdding: .day, value: -5, to: now) ?? now,
                         direction: .out, count: 2)
        ]
    }
}
