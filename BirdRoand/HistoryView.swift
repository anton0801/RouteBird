//
//  HistoryView.swift
//  BirdRoand
//
//  Feature 12 — a unified timeline of everything that happened: ordered,
//  delivered, paid, returned and cancelled.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", delivered = "Delivered", paid = "Paid", returned = "Returned"
        var id: String { rawValue }
    }

    private var events: [HistoryEvent] {
        let all = store.historyEvents()
        switch filter {
        case .all:       return all
        case .delivered: return all.filter { $0.kind == .delivered }
        case .paid:      return all.filter { $0.kind == .paid }
        case .returned:  return all.filter { $0.kind == .returned }
        }
    }

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.l) {
                    BRSegmented(options: Filter.allCases, selection: $filter) { $0.rawValue }

                    if events.isEmpty {
                        BRCard { EmptyState(systemImage: "clock.arrow.circlepath",
                                            title: "Nothing here yet",
                                            message: "Deliveries, payments and tray returns will show up on this timeline.") }
                    } else {
                        VStack(spacing: Space.m) {
                            ForEach(events) { e in
                                BRCard(padding: Space.m) {
                                    HStack(spacing: Space.m) {
                                        IconBadge(systemName: e.icon, tint: e.color, size: 42)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(e.title).font(AppFont.callout).foregroundColor(AppColor.textPrimary)
                                            Text(e.subtitle).font(AppFont.caption).foregroundColor(AppColor.textSecondary)
                                        }
                                        Spacer()
                                        Text(e.date, style: .date)
                                            .font(AppFont.caption).foregroundColor(AppColor.textInactive)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
