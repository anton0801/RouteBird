//
//  NotificationManager.swift
//  BirdRoand
//
//  Thin wrapper over UNUserNotificationCenter. Schedules real local
//  notifications for the four reminder types and cancels them by identifier.
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    // Stable identifiers so we can replace / cancel cleanly.
    enum ID {
        static let collectOrder = "br.reminder.collectOrder"
        static let deliverToday = "br.reminder.deliverToday"
        static let collectDebt  = "br.reminder.collectDebt"
        static let returnTrays  = "br.reminder.returnTrays"
    }

    /// Ask for permission; completion runs on the main thread.
    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Sync from settings

    /// Reconcile all four reminders against the current settings in one call.
    func sync(with r: ReminderSettings) {
        // Daily: collect the order
        if r.collectOrderEnabled {
            scheduleDaily(id: ID.collectOrder, hour: r.collectOrderHour, minute: 0,
                          title: "Collect today's eggs",
                          body: "Gather and pack orders before the round.")
        } else { cancel(ID.collectOrder) }

        // Daily: deliver today
        if r.deliverTodayEnabled {
            scheduleDaily(id: ID.deliverToday, hour: r.deliverTodayHour, minute: 0,
                          title: "Delivery round today",
                          body: "Load the trays — customers are waiting.")
        } else { cancel(ID.deliverToday) }

        // Weekly: collect debts
        if r.collectDebtEnabled {
            scheduleWeekly(id: ID.collectDebt, weekday: r.collectDebtWeekday,
                           hour: r.collectDebtHour, minute: 0,
                           title: "Collect outstanding debts",
                           body: "Some customers still owe for past orders.")
        } else { cancel(ID.collectDebt) }

        // Daily: return trays
        if r.returnTraysEnabled {
            scheduleDaily(id: ID.returnTrays, hour: r.returnTraysHour, minute: 0,
                          title: "Pick up empty trays",
                          body: "Recover trays out with customers on today's round.")
        } else { cancel(ID.returnTrays) }
    }

    // MARK: - Scheduling primitives

    func scheduleDaily(id: String, hour: Int, minute: Int, title: String, body: String) {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        schedule(id: id, comps: comps, title: title, body: body)
    }

    func scheduleWeekly(id: String, weekday: Int, hour: Int, minute: Int, title: String, body: String) {
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = hour
        comps.minute = minute
        schedule(id: id, comps: comps, title: title, body: body)
    }

    private func schedule(id: String, comps: DateComponents, title: String, body: String) {
        cancel(id)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancel(_ id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// One-off test notification so the user can confirm permissions work.
    func fireTest() {
        let content = UNMutableNotificationContent()
        content.title = "Bird Roand"
        content.body = "Reminders are on — you're all set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        center.add(UNNotificationRequest(identifier: "br.reminder.test",
                                         content: content, trigger: trigger))
    }
}
