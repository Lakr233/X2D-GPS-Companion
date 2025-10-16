//
//  ViewModel+Delegates.swift
//  X2D GPS Companion
//
//  Created by qaq on 19/10/2025.
//

import CoreLocation
import Foundation

extension ViewModel: PhotoLibraryServiceDelegate {
    func photoLibraryService(_: PhotoLibraryService, didUpdatePhotoProcessedCount _: Int) {
        updateLiveActivity()
    }
}

extension ViewModel: LocationServiceDelegate {
    func locationService(_: LocationService, didUpdateLocation _: CLLocation) {
        updateLiveActivity()
    }

    func locationService(_: LocationService, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways: locationAccess = .granted
        case .authorizedWhenInUse, .denied, .restricted: locationAccess = .denied
        case .notDetermined: locationAccess = .unknown
        @unknown default: locationAccess = .unknown
        }
    }

    func locationService(_: LocationService, didFailWithError error: Error) {
        print("❌ \(error.localizedDescription)")
    }
}
