//
//  RemindersView.swift
//  BirdRoand
//
//  Feature 13 — real local reminders via UNUserNotificationCenter: collect the
//  order, deliver today, collect debts, return trays. Each toggle schedules or
//  cancels an actual notification.
//

import SwiftUI
import UserNotifications

struct RemindersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var authorized = false
    @State private var askedThisSession = false

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.l) {
                    if !authorized {
                        permissionCard
                    }

                    reminderCard(
                        icon: "tray.and.arrow.down.fill", tint: AppColor.yolk,
                        title: "Collect today's eggs",
                        isOn: bind(\.collectOrderEnabled),
                        hour: bind(\.collectOrderHour), weekday: nil)

                    reminderCard(
                        icon: "box.truck.fill", tint: AppColor.primary,
                        title: "Delivery round today",
                        isOn: bind(\.deliverTodayEnabled),
                        hour: bind(\.deliverTodayHour), weekday: nil)

                    reminderCard(
                        icon: "dollarsign.circle.fill", tint: AppColor.success,
                        title: "Collect outstanding debts",
                        isOn: bind(\.collectDebtEnabled),
                        hour: bind(\.collectDebtHour), weekday: bind(\.collectDebtWeekday))

                    reminderCard(
                        icon: "arrow.uturn.backward.circle.fill", tint: AppColor.coral,
                        title: "Pick up empty trays",
                        isOn: bind(\.returnTraysEnabled),
                        hour: bind(\.returnTraysHour), weekday: nil)

                    SecondaryButton(title: "Send a test notification", systemImage: "bell.badge") {
                        NotificationManager.shared.requestAuthorization { granted in
                            authorized = granted
                            if granted { NotificationManager.shared.fireTest() }
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshStatus)
    }

    // MARK: - Permission

    private var permissionCard: some View {
        BRCard {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.m) {
                    IconBadge(systemName: "bell.slash.fill", tint: AppColor.warn, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications are off").font(AppFont.headline).foregroundColor(AppColor.textPrimary)
                        Text("Enable them so reminders can reach you.")
                            .font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                    }
                }
                PrimaryButton(title: "Enable Notifications", systemImage: "bell.fill") {
                    NotificationManager.shared.requestAuthorization { granted in
                        authorized = granted
                        if granted { store.syncReminders() }
                    }
                }
            }
        }
    }

    // MARK: - Reminder card

    private func reminderCard(icon: String, tint: Color, title: String,
                              isOn: Binding<Bool>, hour: Binding<Int>,
                              weekday: Binding<Int>?) -> some View {
        BRCard {
            VStack(spacing: Space.m) {
                HStack(spacing: Space.m) {
                    IconBadge(systemName: icon, tint: tint, size: 44)
                    Text(title).font(AppFont.headline).foregroundColor(AppColor.textPrimary)
                    Spacer()
                    Toggle("", isOn: isOn).labelsHidden()
                }
                if isOn.wrappedValue {
                    if let weekday = weekday {
                        HStack {
                            Text("Day").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                            Spacer()
                            Picker("", selection: weekday) {
                                ForEach(Weekday.allCases) { d in Text(d.short).tag(d.rawValue) }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 240)
                        }
                    }
                    HStack {
                        Text("Time").font(AppFont.subhead).foregroundColor(AppColor.textSecondary)
                        Spacer()
                        Stepper(value: hour, in: 0...23) {
                            Text(String(format: "%02d:00", hour.wrappedValue))
                                .font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                        }
                        .frame(width: 160)
                    }
                }
            }
        }
    }

    // MARK: - Binding helper

    /// Two-way binding to a ReminderSettings field that re-syncs notifications
    /// (and requests permission when first turning something on).
    private func bind<T>(_ keyPath: WritableKeyPath<ReminderSettings, T>) -> Binding<T> {
        Binding(
            get: { store.reminders[keyPath: keyPath] },
            set: { newValue in
                store.reminders[keyPath: keyPath] = newValue
                // If a toggle was just switched on, make sure we have permission.
                if let boolVal = newValue as? Bool, boolVal, !authorized {
                    NotificationManager.shared.requestAuthorization { granted in
                        authorized = granted
                        store.syncReminders()
                    }
                } else {
                    store.syncReminders()
                }
            }
        )
    }

    private func refreshStatus() {
        NotificationManager.shared.authorizationStatus { status in
            authorized = (status == .authorized || status == .provisional || status == .ephemeral)
        }
    }
}
