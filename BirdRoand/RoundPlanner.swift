//
//  RoundPlanner.swift
//  BirdRoand
//
//  Builds the ordered delivery round for a day from the customers scheduled and
//  their allocated egg counts. Pure, UI-free. No GPS — stops are ordered by the
//  manual `routeOrder`, then zone, then name (a stable, editable sequence).
//

import Foundation

struct RouteStop: Identifiable {
    let id: UUID                 // customer id
    let sequence: Int            // 1-based order along the round
    let customerName: String
    let zone: String
    let address: String
    let phone: String
    let units: Double            // allocated units to drop here
    let eggs: Double             // allocated eggs to drop here
    let runningEggs: Double      // cumulative eggs loaded up to and including this stop
    let isCut: Bool              // order was trimmed by supply shortage
}

struct RoundPlan {
    let day: Weekday
    let stops: [RouteStop]

    var totalEggs: Double { stops.reduce(0) { $0 + $1.eggs } }
    var totalUnits: Double { stops.reduce(0) { $0 + $1.units } }
    var cutCount: Int { stops.filter { $0.isCut }.count }
    var isEmpty: Bool { stops.isEmpty }
}

enum RoundPlanner {

    /// Build the round for `day`. `allocations` is keyed by customer id (from the
    /// SupplyDemandEngine) so each stop carries exactly what we can deliver.
    /// Only home-delivery customers become routed stops; pickup / market-stall
    /// customers are handled at their own point and excluded here.
    static func plan(customers: [Customer],
                     day: Weekday,
                     allocations: [UUID: Allocation],
                     eggsPerUnit: Double) -> RoundPlan {

        let routed = customers
            .filter { $0.isActive && $0.deliversOn(day) && $0.deliveryMethod.isRouted }
            .sorted { a, b in
                if a.routeOrder != b.routeOrder { return a.routeOrder < b.routeOrder }
                if a.zone != b.zone { return a.zone.localizedCaseInsensitiveCompare(b.zone) == .orderedAscending }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

        var running: Double = 0
        var stops: [RouteStop] = []
        for (index, customer) in routed.enumerated() {
            let alloc = allocations[customer.id]
            let perUnit = eggsPerUnit > 0 ? eggsPerUnit : 1
            let eggs = alloc?.allocatedEggs ?? (customer.unitsPerDelivery * eggsPerUnit)
            let units = alloc?.allocatedUnits ?? (eggs / perUnit)
            running += eggs
            stops.append(
                RouteStop(
                    id: customer.id,
                    sequence: index + 1,
                    customerName: customer.name,
                    zone: customer.zone.isEmpty ? "—" : customer.zone,
                    address: customer.address,
                    phone: customer.phone,
                    units: units,
                    eggs: eggs,
                    runningEggs: running,
                    isCut: alloc?.isCut ?? false
                )
            )
        }
        return RoundPlan(day: day, stops: stops)
    }
}
