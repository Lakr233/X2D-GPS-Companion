//
//  ViewModel.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import CoreLocation
import Foundation
import Observation
import SwiftUI

private let autoStartRecordingKey = "AutoStartRecording"

@MainActor
@Observable
final class ViewModel: NSObject {
    static let shared = ViewModel()

    var isRecording: Bool = false
    var photoAccess: AuthStatus = .unknown
    var locationAccess: AuthStatus = .unknown
    var fillInProgress: Bool = false
    var showFillSheet: Bool = false
    var fillSheetMessage: String = ""

    var autoStartRecording: Bool = UserDefaults.standard.bool(forKey: autoStartRecordingKey) {
        didSet {
            UserDefaults.standard.set(autoStartRecording, forKey: autoStartRecordingKey)
        }
    }

    let locationService = LocationService.shared
    let liveActivity = LiveActivityManager.shared
    let photoLibraryService = PhotoLibraryService.shared
    let locationDatabase = LocationDatabase.shared

    override private init() {
        super.init()
        locationService.delegate = self
        photoLibraryService.delegate = self
        startPermissionCheck()
    }
}
