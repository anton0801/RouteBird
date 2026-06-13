//
//  Models.swift
//  BirdRoand
//
//  Domain model for the egg-sales manager. All value types are Codable so the
//  whole app state can be persisted as a single JSON blob.
//

import Foundation
import SwiftUI

// MARK: - Sell format

enum SellFormat: String, Codable, CaseIterable, Identifiable {
    case dozens
    case trays30
    case byWeight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dozens:   return "Dozens"
        case .trays30:  return "Trays-30"
        case .byWeight: return "By weight"
        }
    }

    /// Short noun for a single sold unit.
    var unitLabel: String {
        switch self {
        case .dozens:   return "dozen"
        case .trays30:  return "tray"
        case .byWeight: return "kg"
        }
    }

    var unitLabelPlural: String {
        switch self {
        case .dozens:   return "dozens"
        case .trays30:  return "trays"
        case .byWeight: return "kg"
        }
    }

    var icon: String {
        switch self {
        case .dozens:   return "circle.grid.3x3.fill"
        case .trays30:  return "square.grid.4x3.fill"
        case .byWeight: return "scalemass.fill"
        }
    }

    /// Eggs contained in one sold unit. For `byWeight` we convert through the
    /// average egg weight supplied by Settings.
    func eggsPerUnit(avgEggGrams: Double) -> Double {
        switch self {
        case .dozens:   return 12
        case .trays30:  return 30
        case .byWeight: return avgEggGrams > 0 ? (1000.0 / avgEggGrams) : 16
        }
    }
}

// MARK: - Delivery method

enum DeliveryMethod: String, Codable, CaseIterable, Identifiable {
    case pickup
    case homeDelivery
    case marketStall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pickup:       return "Pickup"
        case .homeDelivery: return "Home delivery"
        case .marketStall:  return "Market stall"
        }
    }

    var icon: String {
        switch self {
        case .pickup:       return "bag.fill"
        case .homeDelivery: return "box.truck.fill"
        case .marketStall:  return "storefront.fill"
        }
    }

    /// Only home deliveries become routed stops.
    var isRouted: Bool { self == .homeDelivery }
}

// MARK: - Weekday

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sun = 1, mon, tue, wed, thu, fri, sat
    var id: Int { rawValue }

    var short: String {
        switch self {
        case .sun: return "Sun"; case .mon: return "Mon"; case .tue: return "Tue"
        case .wed: return "Wed"; case .thu: return "Thu"; case .fri: return "Fri"
        case .sat: return "Sat"
        }
    }

    var letter: String { String(short.prefix(1)) }

    static var today: Weekday {
        let comp = Calendar.current.component(.weekday, from: Date())
        return Weekday(rawValue: comp) ?? .mon
    }
}

// MARK: - Order status

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case planned
    case delivered
    case paid
    case cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned:   return "Planned"
        case .delivered: return "Delivered"
        case .paid:      return "Paid"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .planned:   return AppColor.planned
        case .delivered: return AppColor.success
        case .paid:      return AppColor.success
        case .cancelled: return AppColor.danger
        }
    }

    var icon: String {
        switch self {
        case .planned:   return "calendar"
        case .delivered: return "checkmark.circle.fill"
        case .paid:      return "dollarsign.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Customer

struct Customer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var phone: String = ""
    var address: String = ""
    var zone: String = ""
    var unitsPerWeek: Int = 2
    var deliveryDays: [Int] = [Weekday.mon.rawValue, Weekday.thu.rawValue]
    var deliveryMethod: DeliveryMethod = .homeDelivery
    var prefs: String = ""
    var routeOrder: Int = 0
    var isActive: Bool = true
    var createdAt: Date = Date()

    var deliveryWeekdays: [Weekday] {
        deliveryDays.compactMap { Weekday(rawValue: $0) }.sorted { $0.rawValue < $1.rawValue }
    }

    var deliveriesPerWeek: Int { max(1, deliveryDays.count) }

    func deliversOn(_ day: Weekday) -> Bool {
        deliveryDays.contains(day.rawValue)
    }

    /// Units this customer expects on a single delivery day.
    var unitsPerDelivery: Double {
        Double(unitsPerWeek) / Double(deliveriesPerWeek)
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "?" : s
    }
}

// MARK: - Order

struct Order: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var customerId: UUID
    var date: Date
    var units: Double
    var status: OrderStatus = .planned
    var isRecurring: Bool = true
    var unitPriceSnapshot: Double
    var note: String = ""

    var amount: Double { units * unitPriceSnapshot }
}

// MARK: - Payment

enum PaymentKind: String, Codable, CaseIterable, Identifiable {
    case paid       // settled cash against delivered orders
    case prepaid    // money in advance
    case debtWriteOff // forgive a debt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paid:         return "Payment"
        case .prepaid:      return "Prepaid"
        case .debtWriteOff: return "Write-off"
        }
    }
}

struct Payment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var customerId: UUID
    var orderId: UUID? = nil
    var amount: Double
    var date: Date = Date()
    var kind: PaymentKind = .paid
    var note: String = ""
}

// MARK: - Stock movement

enum StockKind: String, Codable, CaseIterable, Identifiable {
    case collected   // eggs gathered, available to sell
    case sold        // delivered to a customer
    case broken      // breakage / defect
    case reserved    // held back for family / reserve
    case adjust      // manual correction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .collected: return "Collected"
        case .sold:      return "Sold"
        case .broken:    return "Breakage"
        case .reserved:  return "Reserved"
        case .adjust:    return "Adjustment"
        }
    }

    var icon: String {
        switch self {
        case .collected: return "tray.and.arrow.down.fill"
        case .sold:      return "arrow.up.right.circle.fill"
        case .broken:    return "exclamationmark.triangle.fill"
        case .reserved:  return "lock.fill"
        case .adjust:    return "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .collected: return AppColor.success
        case .sold:      return AppColor.primary
        case .broken:    return AppColor.danger
        case .reserved:  return AppColor.yolk
        case .adjust:    return AppColor.textSecondary
        }
    }

    /// Sign applied to the egg balance.
    var sign: Double {
        switch self {
        case .collected, .adjust: return 1
        case .sold, .broken, .reserved: return -1
        }
    }
}

struct StockMovement: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var kind: StockKind
    var eggs: Double
    var note: String = ""

    var signedEggs: Double { eggs * kind.sign }
}

// MARK: - Tray (tara) movement

enum TrayDirection: String, Codable, Identifiable {
    case out  // given to a customer
    case `in` // returned by a customer
    var id: String { rawValue }
}

struct TrayMovement: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var customerId: UUID
    var date: Date = Date()
    var direction: TrayDirection
    var count: Int
}

// MARK: - Theme mode

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - History event (derived feed)

struct HistoryEvent: Identifiable {
    enum Kind { case ordered, delivered, paid, returned, cancelled }
    let id: UUID
    let date: Date
    let kind: Kind
    let title: String
    let subtitle: String

    var icon: String {
        switch kind {
        case .ordered:   return "calendar.badge.plus"
        case .delivered: return "checkmark.circle.fill"
        case .paid:      return "dollarsign.circle.fill"
        case .returned:  return "arrow.uturn.backward.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch kind {
        case .ordered:   return AppColor.planned
        case .delivered: return AppColor.success
        case .paid:      return AppColor.success
        case .returned:  return AppColor.yolk
        case .cancelled: return AppColor.danger
        }
    }
}

// MARK: - Reminder settings

struct ReminderSettings: Codable, Equatable {
    var collectOrderEnabled: Bool = false
    var collectOrderHour: Int = 7
    var deliverTodayEnabled: Bool = false
    var deliverTodayHour: Int = 9
    var collectDebtEnabled: Bool = false
    var collectDebtWeekday: Int = Weekday.fri.rawValue
    var collectDebtHour: Int = 18
    var returnTraysEnabled: Bool = false
    var returnTraysHour: Int = 10
}

// MARK: - Persisted state

struct PersistedState: Codable {
    var customers: [Customer] = []
    var orders: [Order] = []
    var payments: [Payment] = []
    var stock: [StockMovement] = []
    var trays: [TrayMovement] = []

    var sellFormat: SellFormat = .dozens
    var unitPrice: Double = 4.0
    var deliveryMethod: DeliveryMethod = .homeDelivery
    var currencyCode: String = "USD"
    var avgEggGrams: Double = 60
    var reservePercent: Double = 0           // % of collected held as reserve hint
    var themeMode: ThemeMode = .system
    var hasCompletedOnboarding: Bool = false
    var reminders: ReminderSettings = ReminderSettings()
    var didSeed: Bool = false

    init() {}

    // Resilient decode — any missing key falls back to its default so older /
    // partial payloads still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func d<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        customers   = d(.customers, [])
        orders      = d(.orders, [])
        payments    = d(.payments, [])
        stock       = d(.stock, [])
        trays       = d(.trays, [])
        sellFormat  = d(.sellFormat, .dozens)
        unitPrice   = d(.unitPrice, 4.0)
        deliveryMethod = d(.deliveryMethod, .homeDelivery)
        currencyCode = d(.currencyCode, "USD")
        avgEggGrams = d(.avgEggGrams, 60)
        reservePercent = d(.reservePercent, 0)
        themeMode   = d(.themeMode, .system)
        hasCompletedOnboarding = d(.hasCompletedOnboarding, false)
        reminders   = d(.reminders, ReminderSettings())
        didSeed     = d(.didSeed, false)
    }
}
