//
//  LocationService.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import CoreLocation
import Foundation
import Observation

protocol LocationServiceDelegate: AnyObject {
    func locationService(_ service: LocationService, didUpdateLocation location: CLLocation)
    func locationService(_ service: LocationService, didChangeAuthorization status: CLAuthorizationStatus)
    func locationService(_ service: LocationService, didFailWithError error: Error)
}

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    var location: CLLocation?
    var status: String = ""
    weak var delegate: LocationServiceDelegate?

    private let locationManager = CLLocationManager()
    private var backgroundActivitySession: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?

    override private init() {
        super.init()
        locationManager.delegate = self
    }

    func startUpdatingLocation() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true

        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    func startBackgroundSessions() throws {
        serviceSession = CLServiceSession(authorization: .always)
        backgroundActivitySession = CLBackgroundActivitySession()
    }

    func stopBackgroundSessions() {
        backgroundActivitySession?.invalidate()
        backgroundActivitySession = nil

        serviceSession?.invalidate()
        serviceSession = nil
    }

    func getAuthorizationStatus() -> CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.delegate?.locationService(
                self,
                didChangeAuthorization: manager.authorizationStatus
            )
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.handle(latest) }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.status = error.localizedDescription
            self.delegate?.locationService(self, didFailWithError: error)
        }
    }

    private func handle(_ newLocation: CLLocation) {
        let lat = String(format: "%.5f", newLocation.coordinate.latitude)
        let lon = String(format: "%.5f", newLocation.coordinate.longitude)
        let acc = String(format: "%.0f", newLocation.horizontalAccuracy)
        status = "(\(lon), \(lat)) ±\(acc)m"
        location = newLocation
        delegate?.locationService(self, didUpdateLocation: newLocation)
        Task { await LocationDatabase.shared.record(newLocation) }
    }
}
