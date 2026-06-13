//
//  SupplyDemandEngine.swift
//  BirdRoand
//
//  The core value prop: balance eggs available to sell against customer demand,
//  and decide who gets cut when there aren't enough eggs. Pure, UI-free.
//

import Foundation

/// One customer's slice of a demand/allocation calculation.
struct Allocation: Identifiable {
    let id: UUID                 // customer id
    let customerName: String
    let requestedUnits: Double   // what they ordered (in sell-format units)
    let requestedEggs: Double
    let allocatedEggs: Double    // what we can actually give
    var allocatedUnits: Double   // allocatedEggs back in units (for display)

    var isCut: Bool { allocatedEggs + 0.001 < requestedEggs }
    var fulfillmentRatio: Double {
        requestedEggs > 0 ? allocatedEggs / requestedEggs : 1
    }
}

struct SupplyDemandResult {
    let availableEggs: Double
    let demandEggs: Double
    let allocations: [Allocation]

    var deficitEggs: Double { max(0, demandEggs - availableEggs) }
    var surplusEggs: Double { max(0, availableEggs - demandEggs) }
    var isShort: Bool { demandEggs > availableEggs + 0.001 }

    /// 0...1 — how much of total demand can be met.
    var coverage: Double {
        demandEggs > 0 ? min(1, availableEggs / demandEggs) : 1
    }
}

enum SupplyDemandEngine {

    /// Demand for a set of customers, expressed in eggs, for a single day.
    /// Only customers scheduled to receive a delivery on `day` are counted.
    static func dailyDemandEggs(customers: [Customer], day: Weekday, eggsPerUnit: Double) -> Double {
        customers
            .filter { $0.isActive && $0.deliversOn(day) }
            .reduce(0) { $0 + $1.unitsPerDelivery * eggsPerUnit }
    }

    /// Weekly demand in eggs for the whole active book.
    static func weeklyDemandEggs(customers: [Customer], eggsPerUnit: Double) -> Double {
        customers
            .filter { $0.isActive }
            .reduce(0) { $0 + Double($1.unitsPerWeek) * eggsPerUnit }
    }

    /// Allocate `availableEggs` across the customers scheduled for `day`.
    ///
    /// When supply is short, every order is cut **proportionally** to its size so
    /// nobody is zeroed out unfairly. Customers earlier in `routeOrder` (the manual
    /// priority hint) keep the rounding crumbs.
    static func allocate(customers: [Customer],
                         day: Weekday,
                         availableEggs: Double,
                         eggsPerUnit: Double) -> SupplyDemandResult {

        let due = customers
            .filter { $0.isActive && $0.deliversOn(day) }
            .sorted { $0.routeOrder < $1.routeOrder }

        let requests: [(Customer, Double)] = due.map { ($0, $0.unitsPerDelivery * eggsPerUnit) }
        let demandEggs = requests.reduce(0) { $0 + $1.1 }

        let ratio: Double = demandEggs > 0 ? min(1, availableEggs / demandEggs) : 1

        var remaining = availableEggs
        var allocations: [Allocation] = []

        for (customer, requestedEggs) in requests {
            // Proportional share, never more than what's left.
            var give = requestedEggs * ratio
            give = min(give, remaining)
            give = max(0, give)
            remaining -= give

            let perUnit = eggsPerUnit > 0 ? eggsPerUnit : 1
            allocations.append(
                Allocation(
                    id: customer.id,
                    customerName: customer.name,
                    requestedUnits: customer.unitsPerDelivery,
                    requestedEggs: requestedEggs,
                    allocatedEggs: give,
                    allocatedUnits: give / perUnit
                )
            )
        }

        return SupplyDemandResult(
            availableEggs: availableEggs,
            demandEggs: demandEggs,
            allocations: allocations
        )
    }
}
