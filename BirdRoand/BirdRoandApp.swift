//
//  BirdRoandApp.swift
//  BirdRoand
//
//  App entry point. Owns the AppStore, injects it as an environment object,
//  and applies the persisted theme to the whole window.
//

import SwiftUI

@main
struct BirdRoandApp: App {
    @StateObject private var store = AppStore()

    init() {
        AppChrome.configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.colorScheme)
        }
    }
}
