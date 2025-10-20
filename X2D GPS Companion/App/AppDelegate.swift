//
//  AppDelegate.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import ActivityKit
import UIKit

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    private var bootCompleted = false

    func boot() {
        guard !bootCompleted else { return }
        defer { bootCompleted = true }

        print("🚀 App booting...")
        LiveActivityManager.shared.terminate()
        ViewModel.shared.performAutoStartIfNeeded()
    }

    func applicationWillTerminate(_: UIApplication) {
        LiveActivityManager.shared.terminate()
        LocationService.shared.stopUpdatingLocation()
    }
}

extension ViewModel {
    func performAutoStartIfNeeded() {
        let viewModel = ViewModel.shared
        let shouldAutoStart = [
            viewModel.photoAccess == .granted,
            viewModel.locationAccess == .granted,
            viewModel.autoStartRecording,
        ].allSatisfy(\.self)

        guard shouldAutoStart else {
            if !viewModel.autoStartRecording {
                print("⚠️ Cannot auto-start recording: permissions not fully granted")
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try viewModel.startRecording()
                print("✅ Auto-started recording")
            } catch {
                print("❌ Failed to auto-start recording: \(error.localizedDescription)")
            }
        }
    }
}
