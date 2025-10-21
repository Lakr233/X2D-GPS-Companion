//
//  ViewModel+Recording.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import ActivityKit
import CoreLocation
import Foundation
import SwiftUI

enum RecordingError: LocalizedError {
    case photoAccessDenied
    case photoAccessLimited
    case locationAccessDenied
    case backgroundSessionFailed

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            String(localized: "PHOTO_ACCESS_IS_REQUIRED_TO_START_RECORDING")
        case .photoAccessLimited:
            String(localized: "FULL_PHOTO_ACCESS_REQUIRED_FOR_AUTO_RECORDING")
        case .locationAccessDenied:
            String(localized: "LOCATION_ACCESS_IS_REQUIRED_TO_START_RECORDING")
        case .backgroundSessionFailed:
            String(localized: "FAILED_TO_START_BACKGROUND_LOCATION_SESSIONS")
        }
    }
}

extension ViewModel {
    func startRecording() throws {
        defer { if !isRecording { stopRecording() } }

        // Log photo access status but allow recording regardless
        switch photoAccess {
        case .unknown, .denied:
            print("ℹ️ Photo access not granted. GPS will be recorded. Grant photo access to enable automatic background photo updates or use 'Manual Tag Photos'.")
        case .limited:
            print("ℹ️ Photo access is limited. GPS will be recorded. Use 'Manual Tag Photos' to tag photos later.")
        case .granted:
            print("✅ Photo access granted. Automatic background photo updates enabled.")
        }

        guard locationAccess == .granted else {
            throw RecordingError.locationAccessDenied
        }

        try locationService.startBackgroundSessions()

        // Only monitor photo library if we have some level of access
        if photoAccess == .granted || photoAccess == .limited {
            try photoLibraryService.beginMonitoring()
        }

        defer { isRecording = true }
        locationService.startUpdatingLocation()
        liveActivity.start()
    }

    func stopRecording() {
        isRecording = false
        locationService.stopBackgroundSessions()
        locationService.stopUpdatingLocation()
        photoLibraryService.stopMonitoring()
        liveActivity.terminate()
    }
}
