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
    override func setUp() async throws {
        try await super.setUp()
        database = LocationDatabase.shared
        _ = try await database.reset()
    }

    @MainActor
    override func tearDown() async throws {
        _ = try await database.reset()
        try await super.tearDown()
    }

    // MARK: - Basic Database Operations

    @MainActor
    func testDatabaseRecordAndRetrieve() async throws {
        // Create test locations
        let baseDate = Date()
        let locations = generateTestLocations(count: 10, startDate: baseDate, interval: 60)

        // Record all locations
        for location in locations {
            await database.record(location)
        }

        // Retrieve all records
        let records = try await database.records(in: nil)

        XCTAssertEqual(records.count, 10, "Should have 10 records")
        XCTAssertEqual(records.first?.latitude ?? 0, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(records.last?.latitude ?? 0, 37.7758, accuracy: 0.0001)
    }

    @MainActor
    func testDatabaseFilterByInterval() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 20, startDate: baseDate, interval: 30)

        for location in locations {
            await database.record(location)
        }

        // Query for middle 10 records (5 minutes to 10 minutes)
        let interval = DateInterval(
            start: baseDate.addingTimeInterval(5 * 60),
            end: baseDate.addingTimeInterval(10 * 60)
        )
        let records = try await database.records(in: interval)

        XCTAssertEqual(records.count, 10, "Should have 10 records in the interval")
    }

    @MainActor
    func testDatabaseReset() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 5, startDate: baseDate, interval: 60)

        for location in locations {
            await database.record(location)
        }

        var records = try await database.records(in: nil)
        XCTAssertEqual(records.count, 5)

        let deletedCount = try await database.reset()
        XCTAssertEqual(deletedCount, 5, "Should delete 5 records")

        records = try await database.records(in: nil)
        XCTAssertEqual(records.count, 0, "Should have no records after reset")
    }

    // MARK: - Nearest Record Tests

    @MainActor
    func testNearestRecordWithinTolerance() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 10, startDate: baseDate, interval: 60)

        for location in locations {
            await database.record(location)
        }

        let records = try await database.records(in: nil)

        // Query for a time 30 seconds after the 5th record
        let queryDate = baseDate.addingTimeInterval(5 * 60 + 30)
        let nearest = database.nearestRecord(to: queryDate, tolerance: 5 * 60, records: records)

        XCTAssertNotNil(nearest)
        XCTAssertEqual(nearest?.latitude ?? 0, 37.7753, accuracy: 0.0001)
    }

    @MainActor
    func testNearestRecordOutsideTolerance() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 5, startDate: baseDate, interval: 60)

        for location in locations {
            await database.record(location)
        }

        let records = try await database.records(in: nil)

        // Query for a time 10 minutes after the last record (outside 5 min tolerance)
        let queryDate = baseDate.addingTimeInterval(15 * 60)
        let nearest = database.nearestRecord(to: queryDate, tolerance: 5 * 60, records: records)

        XCTAssertNil(nearest, "Should not find record outside tolerance")
    }

    // MARK: - Interpolation Tests

    @MainActor
    func testNearestRecordsBeforeAndAfter() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 10, startDate: baseDate, interval: 60)

        for location in locations {
            await database.record(location)
        }

        let records = try await database.records(in: nil)

        // Query for a time between 5th and 6th record
        let queryDate = baseDate.addingTimeInterval(5 * 60 + 30)
        let (before, after) = database.nearestRecords(to: queryDate, tolerance: 5 * 60, records: records)

        XCTAssertNotNil(before)
        XCTAssertNotNil(after)
        XCTAssertEqual(before?.latitude ?? 0, 37.7753, accuracy: 0.0001)
        XCTAssertEqual(after?.latitude ?? 0, 37.7754, accuracy: 0.0001)
    }

    @MainActor
    func testNearestRecordsOnlyBefore() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 5, startDate: baseDate, interval: 60)

        for location in locations {
            await database.record(location)
        }

        let records = try await database.records(in: nil)

        // Query for a time after all records but within tolerance
        let queryDate = baseDate.addingTimeInterval(5 * 60 + 30)
        let (before, after) = database.nearestRecords(to: queryDate, tolerance: 5 * 60, records: records)

        XCTAssertNotNil(before)
        XCTAssertNil(after)
    }

    @MainActor
    func testNearestRecordsOnlyAfter() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 5, startDate: baseDate.addingTimeInterval(60), interval: 60)

        for location in locations {
            await database.record(location)
        }

        let records = try await database.records(in: nil)

        // Query for a time before all records but within tolerance
        let queryDate = baseDate.addingTimeInterval(30)
        let (before, after) = database.nearestRecords(to: queryDate, tolerance: 5 * 60, records: records)

        XCTAssertNil(before)
        XCTAssertNotNil(after)
    }

    // MARK: - Performance Tests

    @MainActor
    func testDatabasePerformanceWithLargeDataset() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 1000, startDate: baseDate, interval: 10)

        measure {
            Task { @MainActor in
                for location in locations {
                    await database.record(location)
                }
            }
        }
    }

    @MainActor
    func testQueryPerformanceWithLargeDataset() async throws {
        let baseDate = Date()
        let locations = generateTestLocations(count: 1000, startDate: baseDate, interval: 10)

        for location in locations {
            await database.record(location)
        }

        let records = try await database.records(in: nil)

        measure {
            let queryDate = baseDate.addingTimeInterval(5000)
            _ = database.nearestRecord(to: queryDate, tolerance: 5 * 60, records: records)
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
                timestamp: timestamp
            )

            locations.append(location)
        }

        return locations
    }
}

// MARK: - Image Generation Tests

final class ImageGenerationTests: XCTestCase {
    func testGenerateWhiteImage() throws {
        let image = generateWhiteImage(size: CGSize(width: 256, height: 256))

        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 256)
        XCTAssertEqual(image.size.height, 256)

        // Verify the image is white by checking a pixel
        guard let cgImage = image.cgImage else {
            XCTFail("Failed to get CGImage")
            return
        }

        XCTAssertEqual(cgImage.width, 256)
        XCTAssertEqual(cgImage.height, 256)
    }

    func testSaveImageToTemporaryFile() throws {
        let image = generateWhiteImage(size: CGSize(width: 256, height: 256))
        let tempURL = try saveImageToTemporaryFile(image: image)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        // Verify we can load the image back
        let loadedImage = UIImage(contentsOfFile: tempURL.path)
        XCTAssertNotNil(loadedImage)
        XCTAssertEqual(loadedImage?.size.width, 256)
        XCTAssertEqual(loadedImage?.size.height, 256)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testGenerateMultipleImages() throws {
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
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image
    }

    private func saveImageToTemporaryFile(image: UIImage) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "test_image_\(UUID().uuidString).jpg"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            throw NSError(domain: "ImageGenerationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])
        }

        try imageData.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Integration Tests

final class LocationInterpolationTests: XCTestCase {
    @MainActor
    func testLinearInterpolation() async throws {
        let database = LocationDatabase.shared
        _ = try await database.reset()

        // Create two locations 2 minutes apart
        let baseDate = Date()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: baseDate
        )

        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: baseDate.addingTimeInterval(120)
        )

        await database.record(location1)
        await database.record(location2)

        let records = try await database.records(in: nil)

        // Query for a time exactly in the middle (1 minute)
        let queryDate = baseDate.addingTimeInterval(60)
        let (before, after) = database.nearestRecords(to: queryDate, tolerance: 5 * 60, records: records)

        XCTAssertNotNil(before)
        XCTAssertNotNil(after)

        // The interpolated location should be approximately halfway
        if let before, let after {
            let expectedLat = (before.latitude + after.latitude) / 2
            let expectedLon = (before.longitude + after.longitude) / 2

            XCTAssertEqual(expectedLat, 37.7799, accuracy: 0.0001)
            XCTAssertEqual(expectedLon, -122.4144, accuracy: 0.0001)
        }

        _ = try await database.reset()
    }

    @MainActor
    func testInterpolationWithMultiplePoints() async throws {
        let database = LocationDatabase.shared
        _ = try await database.reset()

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
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: -1,
                course: -1,
                speed: -1,
                timestamp: baseDate.addingTimeInterval(TimeInterval(i * 60))
            )

            await database.record(location)
        }

        let records = try await database.records(in: nil)
        XCTAssertEqual(records.count, 10)

        // Test interpolation at various points
        for i in 0 ..< 9 {
            let queryDate = baseDate.addingTimeInterval(TimeInterval(i * 60 + 30))
            let (before, after) = database.nearestRecords(to: queryDate, tolerance: 5 * 60, records: records)

            XCTAssertNotNil(before, "Should find before record at index \(i)")
            XCTAssertNotNil(after, "Should find after record at index \(i)")
        }

        _ = try await database.reset()
    }
}
