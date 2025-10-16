//
//  main.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import SwiftUI

MainActor.assumeIsolated { _ = ViewModel.shared }
CompanionApp.main()

struct CompanionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var logManager = LogManager.shared

    init() {}

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomePageView()
                    .onAppear { appDelegate.boot() }
            }
            .tint(.accent)
            .background(Color.black.opacity(0.9))
            .preferredColorScheme(.dark)
        }
    }
}
