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
private let overwriteExistingLocationKey = "OverwriteExistingLocation"
private let bypassEXIFCheckKey = "BypassEXIFCheck"

@MainActor
@Observable
final class ViewModel: NSObject {
    static let shared = ViewModel()

    var isRecording: Bool = false
    var photoAccess: AuthStatus = .unknown
    var locationAccess: AuthStatus = .unknown
    var fillInProgress: Bool = false
    var fillAlertMessage: String = ""
    var showFillAlert: Bool = false
    var resetInProgress: Bool = false
    var resetAlertMessage: String = ""
    var showResetAlert: Bool = false

    var autoStartRecording: Bool = UserDefaults.standard.bool(forKey: autoStartRecordingKey) {
        didSet {
            UserDefaults.standard.set(autoStartRecording, forKey: autoStartRecordingKey)
        }
    }

    var overwriteExistingLocation: Bool = UserDefaults.standard.bool(forKey: overwriteExistingLocationKey) {
        didSet {
            UserDefaults.standard.set(overwriteExistingLocation, forKey: overwriteExistingLocationKey)
        }
    }

    var bypassEXIFCheck: Bool = UserDefaults.standard.bool(forKey: bypassEXIFCheckKey) {
        didSet {
            UserDefaults.standard.set(bypassEXIFCheck, forKey: bypassEXIFCheckKey)
            photoLibraryService.bypassEXIFCheck = bypassEXIFCheck
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
        photoLibraryService.bypassEXIFCheck = bypassEXIFCheck
        startPermissionCheck()
    }
}
