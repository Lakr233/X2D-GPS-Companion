//
//  ViewModel+Permissions.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import CoreLocation
import Foundation
import Photos

extension ViewModel {
    func startPermissionCheck() {
        updatePermissions()
        _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async { self.updatePermissions() }
        }
    }

    private func updatePermissions() {
        let photosAuth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch photosAuth {
        case .authorized: photoAccess = .granted
        case .limited: photoAccess = .limited
        case .denied, .restricted: photoAccess = .denied
        case .notDetermined: photoAccess = .unknown
        @unknown default: photoAccess = .unknown
        }

        switch locationService.getAuthorizationStatus() {
        case .authorizedAlways: locationAccess = .granted
        case .authorizedWhenInUse:
            locationAccess = .limited
            requestLocationAlways()
        case .denied, .restricted: locationAccess = .denied
        case .notDetermined: locationAccess = .unknown
        @unknown default: locationAccess = .unknown
        }
    }

    func requestPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized: photoAccess = .granted
        case .limited: photoAccess = .limited
        case .denied, .restricted: photoAccess = .denied
        case .notDetermined: photoAccess = .unknown
        @unknown default: photoAccess = .unknown
        }
    }

    func requestLocationAlways() {
        if locationService.getAuthorizationStatus() == .notDetermined {
            locationService.requestWhenInUseAuthorization()
        } else if locationService.getAuthorizationStatus() == .authorizedWhenInUse {
            locationService.requestAlwaysAuthorization()
        }
    }
}
