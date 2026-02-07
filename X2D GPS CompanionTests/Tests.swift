//
//  Tests.swift
//  X2D GPS CompanionTests
//
//  Created by qaq on 20/10/2025.
//

import CoreData
import CoreLocation
import Photos
import UIKit
@testable import X2D_GPS_Companion
import XCTest

final class DatabaseTests: XCTestCase {
    var database: LocationDatabase!

    @MainActor
    override func setUp() {
        super.setUp()
        ViewModel.shared.stopRecording()
        database = LocationDatabase.shared
        try! database.reset()
    }

    @MainActor
    override func tearDown() {
        try! database.reset()
        super.tearDown()
    }

    // MARK: - Basic Database Operations

    @MainActor
    func testDatabaseRecordAndRetrieve() throws {
        try database.reset()
        let baseDate = Date()
        let locations = generateTestLocations(count: 10, startDate: baseDate, interval: 60)
        for location in locations {
            database.record(location)
        }
        let records = try database.records(in: nil)
        XCTAssertEqual(records.count, 10, "Should have 10 records, but got \(records.count)")
        if records.count >= 10 {
            XCTAssertEqual(records.first?.latitude ?? 0, 37.7749, accuracy: 0.0001)
            XCTAssertEqual(records.last?.latitude ?? 0, 37.7758, accuracy: 0.0001)
        }
    }

    @MainActor
    func testDatabaseFilterByInterval() throws {
        try database.reset()
        let baseDate = Date()
        let locations = generateTestLocations(count: 20, startDate: baseDate, interval: 30)
        for location in locations {
            database.record(location)
        }
        let interval = DateInterval(
            start: baseDate.addingTimeInterval(5 * 60),
            end: baseDate.addingTimeInterval(10 * 60),
        )
        let records = try database.records(in: interval)
        XCTAssertEqual(records.count, 10, "Should have 10 records in the interval")
    }

    @MainActor
    func testDatabaseReset() throws {
        try database.reset()
        let baseDate = Date()
        let locations = generateTestLocations(count: 5, startDate: baseDate, interval: 60)
        for location in locations {
            database.record(location)
        }
        var records = try database.records(in: nil)
        XCTAssertEqual(records.count, 5)
        let deletedCount = try database.reset()
        XCTAssertEqual(deletedCount, 5, "Should delete 5 records")
        records = try database.records(in: nil)
        XCTAssertEqual(records.count, 0, "Should have no records after reset")
    }

    // MARK: - Location Query Tests

    @MainActor
    func testLocationAtWithInterpolation() throws {
        try database.reset()
        let baseDate = Date()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            course: 0,
            speed: 1.0,
            timestamp: baseDate,
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4184),
            altitude: 20.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            course: 90,
            speed: 2.0,
            timestamp: baseDate.addingTimeInterval(120),
        )

        database.record(location1)
        database.record(location2)

        let queryDate = baseDate.addingTimeInterval(60)
        let result = try database.location(at: queryDate)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.coordinate.latitude ?? 0, 37.7754, accuracy: 0.0001)
        XCTAssertEqual(result?.coordinate.longitude ?? 0, -122.4189, accuracy: 0.0001)
        XCTAssertEqual(result?.altitude ?? 0, 15.0, accuracy: 0.1)
        XCTAssertEqual(result?.speed ?? 0, 1.5, accuracy: 0.1)
    }

    @MainActor
    func testLocationAtWithOnlyBefore() throws {
        try database.reset()
        let baseDate = Date()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            timestamp: baseDate,
        )
        database.record(location)
        let queryDate = baseDate.addingTimeInterval(120)
        let result = try database.location(at: queryDate)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.coordinate.latitude ?? 0, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(result?.coordinate.longitude ?? 0, -122.4194, accuracy: 0.0001)
    }

    @MainActor
    func testLocationAtWithOnlyAfter() throws {
        try database.reset()
        let baseDate = Date()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            timestamp: baseDate.addingTimeInterval(120),
        )

        database.record(location)
        let queryDate = baseDate
        let result = try database.location(at: queryDate)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.coordinate.latitude ?? 0, 37.7749, accuracy: 0.0001)
    }

    @MainActor
    func testLocationAtOutsideTolerance() throws {
        try database.reset()
        let baseDate = Date()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            timestamp: baseDate,
        )

        database.record(location)
        let queryDate = baseDate.addingTimeInterval(600)
        let result = try database.location(at: queryDate)
        XCTAssertNil(result, "Should not find location outside tolerance")
    }

    @MainActor
    func testLocationAtNoData() throws {
        try database.reset()
        let queryDate = Date()
        let result = try database.location(at: queryDate)
        XCTAssertNil(result, "Should return nil when no data exists")
    }

    // MARK: - Performance Tests

    @MainActor
    func testDatabasePerformanceWithLargeDataset() throws {
        try database.reset()
        let baseDate = Date()
        let locations = generateTestLocations(count: 1000, startDate: baseDate, interval: 10)

        measure {
            for location in locations {
                database.record(location)
            }
        }
    }

    @MainActor
    func testQueryPerformanceWithLargeDataset() throws {
        try database.reset()
        let baseDate = Date()
        let locations = generateTestLocations(count: 1000, startDate: baseDate, interval: 10)

        for location in locations {
            database.record(location)
        }

        measure {
            let queryDate = baseDate.addingTimeInterval(5000)
            _ = try? database.location(at: queryDate)
        }
    }

    // MARK: - Helper Methods

    private func generateTestLocations(count: Int, startDate: Date, interval: TimeInterval) -> [CLLocation] {
        var locations: [CLLocation] = []

        for i in 0 ..< count {
            let timestamp = startDate.addingTimeInterval(TimeInterval(i) * interval)
            let latitude = 37.7749 + Double(i) * 0.0001 // San Francisco area
            let longitude = -122.4194 + Double(i) * 0.0001

            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: 10.0 + Double(i),
                horizontalAccuracy: 5.0 + Double(i % 3),
                verticalAccuracy: 10.0,
                course: Double(i * 10 % 360),
                speed: Double(i % 20),
                timestamp: timestamp,
            )

            locations.append(location)
        }

        return locations
    }
}

// MARK: - Image Generation Tests

final class ImageGenerationTests: XCTestCase {
    func testGenerateWhiteImage() {
        let image = generateWhiteImage(size: CGSize(width: 256, height: 256))

        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 256)
        XCTAssertEqual(image.size.height, 256)
    }

    func testSaveImageToTemporaryFile() throws {
        let image = generateWhiteImage(size: CGSize(width: 256, height: 256))
        let tempURL = try saveImageToTemporaryFile(image: image)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        let loadedImage = UIImage(contentsOfFile: tempURL.path)
        XCTAssertNotNil(loadedImage)
        XCTAssertEqual(image.size.width, 256)
        XCTAssertEqual(image.size.height, 256)

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testGenerateMultipleImages() {
        let images = (0 ..< 5).map { _ in
            generateWhiteImage(size: CGSize(width: 256, height: 256))
        }

        XCTAssertEqual(images.count, 5)
        for image in images {
            XCTAssertEqual(image.size.width, 256)
            XCTAssertEqual(image.size.height, 256)
        }
    }

    // MARK: - Helper Methods

    private func generateWhiteImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func saveImageToTemporaryFile(image: UIImage) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "test_image_\(UUID().uuidString).png"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        guard let imageData = image.pngData() else {
            throw NSError(domain: "ImageGenerationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG data"])
        }

        try imageData.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Integration Tests

final class LocationInterpolationTests: XCTestCase {
    @MainActor
    func testLinearInterpolation() throws {
        let database = LocationDatabase.shared
        _ = try database.reset()

        let baseDate = Date()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 5,
            verticalAccuracy: 10,
            course: 0,
            speed: 1.0,
            timestamp: baseDate,
        )

        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            altitude: 20.0,
            horizontalAccuracy: 5,
            verticalAccuracy: 10,
            course: 90,
            speed: 2.0,
            timestamp: baseDate.addingTimeInterval(120),
        )

        database.record(location1)
        database.record(location2)

        let queryDate = baseDate.addingTimeInterval(60)
        let result = try database.location(at: queryDate)

        XCTAssertNotNil(result)

        XCTAssertEqual(result?.coordinate.latitude ?? 0, 37.7799, accuracy: 0.0001)
        XCTAssertEqual(result?.coordinate.longitude ?? 0, -122.4144, accuracy: 0.0001)
        XCTAssertEqual(result?.altitude ?? 0, 15.0, accuracy: 0.1)
        XCTAssertEqual(result?.speed ?? 0, 1.5, accuracy: 0.1)

        _ = try database.reset()
    }

    @MainActor
    func testInterpolationWithMultiplePoints() throws {
        let database = LocationDatabase.shared
        _ = try database.reset()

        // Create a path with 10 points over 10 minutes
        let baseDate = Date()
        let startLat = 37.7749
        let startLon = -122.4194
        let endLat = 37.7849
        let endLon = -122.4094

        for i in 0 ..< 10 {
            let progress = Double(i) / 9.0
            let lat = startLat + (endLat - startLat) * progress
            let lon = startLon + (endLon - startLon) * progress

            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: Double(i * 10),
                horizontalAccuracy: 5,
                verticalAccuracy: 10,
                course: Double(i * 10),
                speed: Double(i),
                timestamp: baseDate.addingTimeInterval(TimeInterval(i * 60)),
            )

            database.record(location)
        }

        let records = try database.records(in: nil)
        XCTAssertEqual(records.count, 10)

        for i in 0 ..< 9 {
            let queryDate = baseDate.addingTimeInterval(TimeInterval(i * 60 + 30))
            let (before, after) = database.nearestRecords(to: queryDate, tolerance: 5 * 60, records: records)

            XCTAssertNotNil(before, "Should find before record at index \(i)")
            XCTAssertNotNil(after, "Should find after record at index \(i)")
        }

        _ = try database.reset()
    }
}

// MARK: - Compatibility Mode Tests

final class CompatibilityModeTests: XCTestCase {
    @MainActor
    func testBypassEXIFCheckDefaultValue() {
        // Clear any previously stored value to test the actual default
        UserDefaults.standard.removeObject(forKey: "BypassEXIFCheck")

        // Create a fresh viewmodel state by accessing the current value
        let viewModel = ViewModel.shared
        // The default value should be false
        XCTAssertFalse(viewModel.bypassEXIFCheck, "bypassEXIFCheck should default to false")
    }

    @MainActor
    func testBypassEXIFCheckPersistence() {
        let viewModel = ViewModel.shared
        let photoLibraryService = PhotoLibraryService.shared

        // Test that setting bypassEXIFCheck updates PhotoLibraryService
        viewModel.bypassEXIFCheck = true
        XCTAssertTrue(photoLibraryService.bypassEXIFCheck, "PhotoLibraryService should reflect bypassEXIFCheck = true")

        viewModel.bypassEXIFCheck = false
        XCTAssertFalse(photoLibraryService.bypassEXIFCheck, "PhotoLibraryService should reflect bypassEXIFCheck = false")
    }

    @MainActor
    func testPhotoLibraryServiceBypassProperty() {
        let service = PhotoLibraryService.shared

        // Test that the property can be set directly
        service.bypassEXIFCheck = true
        XCTAssertTrue(service.bypassEXIFCheck, "bypassEXIFCheck should be true")

        service.bypassEXIFCheck = false
        XCTAssertFalse(service.bypassEXIFCheck, "bypassEXIFCheck should be false")
    }
}
