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
    case locationAccessDenied
    case backgroundSessionFailed

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            String(localized: "PHOTO_ACCESS_IS_REQUIRED_TO_START_RECORDING")
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
        guard photoAccess == .granted else { throw RecordingError.photoAccessDenied }
        guard locationAccess == .granted else { throw RecordingError.locationAccessDenied }
        try locationService.startBackgroundSessions()
        try photoLibraryService.beginMonitoring()
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
