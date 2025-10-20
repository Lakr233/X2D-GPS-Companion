//
//  StubTest.swift
//  X2D GPS CompanionTests
//
//  Created by qaq on 16/10/2025.
//

import XCTest
import CoreLocation
import CoreData
@testable import X2D_GPS_Companion

final class LocationDatabaseTests: XCTestCase {
    @MainActor
    func testRecordsFilteringByInterval() async throws {
        let database = LocationDatabase.shared

        // Insert two records at known timestamps
        let baseDate = Date()
        let locationA = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: baseDate.addingTimeInterval(-300)
        )

        let locationB = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 2),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: baseDate.addingTimeInterval(-60)
        )

        try! await database.reset()
        await database.record(locationA)
        await database.record(locationB)

        let interval = DateInterval(start: baseDate.addingTimeInterval(-120), end: baseDate)
        let results = try await database.records(in: interval)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.latitude, 2)
        XCTAssertEqual(results.first?.longitude, 2)
    }
}
