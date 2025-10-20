//
//  LocationDatabase.swift
//  X2D GPS Companion
//
//  Created by qaq on 21/10/2025.
//

import CoreData
import CoreLocation
import Foundation

struct LocationRecord: Identifiable {
    let id: NSManagedObjectID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double

    var location: CLLocation {
        CLLocation(
            coordinate: .init(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}

@objc(LocationSample)
final class LocationSample: NSManagedObject {
    @NSManaged var timestamp: Date
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var altitude: Double
    @NSManaged var horizontalAccuracy: Double
    @NSManaged var verticalAccuracy: Double
    @NSManaged var speed: Double
    @NSManaged var course: Double
}

extension LocationSample {
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocationSample> {
        NSFetchRequest<LocationSample>(entityName: "LocationSample")
    }
}

@MainActor
final class LocationDatabase {
    static let shared = LocationDatabase()

    private let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext

    // Model version identifier - increment this when the data model changes
    private static let currentModelVersion = 2

    private init() {
        let model = LocationDatabase.makeModel()
        container = NSPersistentContainer(name: "LocationStore", managedObjectModel: model)

        let storeURL = LocationDatabase.storeURL()
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            print("❌ Failed to create directory for CoreData store: \(error.localizedDescription)")
        }

        // Check if we need to reset the database due to model version change
        Self.checkAndResetIfNeeded(storeURL: storeURL)

        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { [weak container] _, error in
            if let error {
                // If migration fails, delete the old store and try again
                print("⚠️ Failed to load location store, attempting to recreate: \(error.localizedDescription)")
                Self.deleteStore(at: storeURL)

                container?.loadPersistentStores { _, retryError in
                    if let retryError {
                        fatalError("Failed to load location store after retry: \(retryError)")
                    } else {
                        // Save the new model version after successful recreation
                        Self.saveModelVersion()
                    }
                }
            } else {
                // Save the current model version on successful load
                Self.saveModelVersion()
            }
        }

        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Public API

    /// Record a location to the database. All locations are saved without filtering.
    func record(_ location: CLLocation) {
        persistSnapshot(LocationSnapshot(location: location))
    }

    /// Get the location at a specific date with interpolation support.
    /// - Parameters:
    ///   - date: The target date to search for
    ///   - tolerance: Maximum time difference allowed (default: 5 minutes)
    /// - Returns: The interpolated or nearest location, or nil if none found
    /// - Throws: Error if no location is available within tolerance
    ///
    /// This method attempts to find locations before and after the target date.
    /// If both are found within tolerance, it interpolates between them.
    /// If only one is found, it returns that location.
    /// If none are found, it returns nil.
    func location(at date: Date, tolerance: TimeInterval = 5 * 60) async throws -> CLLocation? {
        let interval = DateInterval(
            start: date.addingTimeInterval(-tolerance),
            end: date.addingTimeInterval(tolerance)
        )
        let records = try await records(in: interval)

        let (before, after) = nearestRecords(to: date, tolerance: tolerance, records: records)

        // If we have both before and after, interpolate
        if let before, let after {
            return interpolate(from: before, to: after, at: date)
        }

        // If we only have one, return it
        if let before {
            return before.location
        }
        if let after {
            return after.location
        }

        // No location found
        return nil
    }

    /// Get all location records within a date interval.
    /// - Parameter interval: The date interval to query, or nil for all records
    /// - Returns: Array of location records sorted by timestamp
    func records(in interval: DateInterval? = nil) async throws -> [LocationRecord] {
        let context = container.viewContext
        return try context.performAndWait {
            let request = LocationSample.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(LocationSample.timestamp), ascending: true)]
            if let interval {
                request.predicate = NSPredicate(
                    format: "timestamp >= %@ AND timestamp <= %@",
                    interval.start as NSDate,
                    interval.end as NSDate
                )
            }

            let samples = try context.fetch(request)
            return samples.map { sample in
                LocationRecord(
                    id: sample.objectID,
                    timestamp: sample.timestamp,
                    latitude: sample.latitude,
                    longitude: sample.longitude,
                    altitude: sample.altitude,
                    horizontalAccuracy: sample.horizontalAccuracy,
                    verticalAccuracy: sample.verticalAccuracy,
                    speed: sample.speed,
                    course: sample.course
                )
            }
        }
    }

    /// Delete all location records from the database.
    /// - Returns: The number of records deleted
    @discardableResult
    func reset() throws -> Int {
        let deletedCount = try backgroundContext.performAndWait {
            let countRequest = NSFetchRequest<LocationSample>(entityName: "LocationSample")
            let count = try self.backgroundContext.count(for: countRequest)

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LocationSample")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            let result = try self.backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [self.container.viewContext]
                )
            }
            self.backgroundContext.reset()

            do {
                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                    self.backgroundContext.reset()
                }
            } catch {
                print("❌ Failed to save location sample: \(error.localizedDescription)")
            }

            return count
        }

        container.viewContext.performAndWait {
            self.container.viewContext.reset()
        }

        return deletedCount
    }

    // MARK: - Private Methods

    private func persistSnapshot(_ snapshot: LocationSnapshot) {
        backgroundContext.performAndWait {
            let sample = LocationSample(context: self.backgroundContext)
            sample.timestamp = snapshot.timestamp
            sample.latitude = snapshot.latitude
            sample.longitude = snapshot.longitude
            sample.altitude = snapshot.altitude
            sample.horizontalAccuracy = snapshot.horizontalAccuracy
            sample.verticalAccuracy = snapshot.verticalAccuracy
            sample.speed = snapshot.speed
            sample.course = snapshot.course

            do {
                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                    self.backgroundContext.reset()
                }
            } catch {
                print("❌ Failed to save location sample: \(error.localizedDescription)")
            }
        }
    }

    func nearestRecords(to date: Date, tolerance: TimeInterval, records: [LocationRecord]) -> (before: LocationRecord?, after: LocationRecord?) {
        guard !records.isEmpty else { return (nil, nil) }

        var lower = 0
        var upper = records.count - 1
        while lower < upper {
            let mid = (lower + upper) / 2
            if records[mid].timestamp < date {
                lower = mid + 1
            } else {
                upper = mid
            }
        }

        let idx = lower
        var before: LocationRecord?
        var after: LocationRecord?

        // Find the record before the target date
        if idx > 0 {
            let candidate = records[idx - 1]
            if abs(candidate.timestamp.timeIntervalSince(date)) <= tolerance {
                before = candidate
            }
        }

        // Find the record after the target date
        if idx < records.count {
            let candidate = records[idx]
            if abs(candidate.timestamp.timeIntervalSince(date)) <= tolerance {
                after = candidate
            }
        }

        return (before, after)
    }

    private func interpolate(from before: LocationRecord, to after: LocationRecord, at date: Date) -> CLLocation {
        let totalInterval = after.timestamp.timeIntervalSince(before.timestamp)
        let targetInterval = date.timeIntervalSince(before.timestamp)
        let ratio = totalInterval > 0 ? targetInterval / totalInterval : 0.5

        let latitude = before.latitude + (after.latitude - before.latitude) * ratio
        let longitude = before.longitude + (after.longitude - before.longitude) * ratio
        let altitude = before.altitude + (after.altitude - before.altitude) * ratio
        let horizontalAccuracy = before.horizontalAccuracy + (after.horizontalAccuracy - before.horizontalAccuracy) * ratio
        let verticalAccuracy = before.verticalAccuracy + (after.verticalAccuracy - before.verticalAccuracy) * ratio

        // For speed and course, use the average if both are valid, otherwise use the valid one
        var speed: Double = -1
        if before.speed >= 0, after.speed >= 0 {
            speed = before.speed + (after.speed - before.speed) * ratio
        } else if before.speed >= 0 {
            speed = before.speed
        } else if after.speed >= 0 {
            speed = after.speed
        }

        var course: Double = -1
        if before.course >= 0, after.course >= 0 {
            course = before.course + (after.course - before.course) * ratio
        } else if before.course >= 0 {
            course = before.course
        } else if after.course >= 0 {
            course = after.course
        }

        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: date
        )
    }

    private struct LocationSnapshot {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let horizontalAccuracy: Double
        let verticalAccuracy: Double
        let speed: Double
        let course: Double

        init(location: CLLocation) {
            timestamp = location.timestamp
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            altitude = location.altitude
            horizontalAccuracy = max(location.horizontalAccuracy, 0)
            verticalAccuracy = max(location.verticalAccuracy, 0)
            speed = max(location.speed, -1)
            course = max(location.course, -1)
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "LocationSample"
        entity.managedObjectClassName = NSStringFromClass(LocationSample.self)

        let timestamp = NSAttributeDescription()
        timestamp.name = "timestamp"
        timestamp.attributeType = .dateAttributeType
        timestamp.isOptional = false

        let latitude = NSAttributeDescription()
        latitude.name = "latitude"
        latitude.attributeType = .doubleAttributeType
        latitude.isOptional = false

        let longitude = NSAttributeDescription()
        longitude.name = "longitude"
        longitude.attributeType = .doubleAttributeType
        longitude.isOptional = false

        let altitude = NSAttributeDescription()
        altitude.name = "altitude"
        altitude.attributeType = .doubleAttributeType
        altitude.isOptional = false

        let horizontalAccuracy = NSAttributeDescription()
        horizontalAccuracy.name = "horizontalAccuracy"
        horizontalAccuracy.attributeType = .doubleAttributeType
        horizontalAccuracy.isOptional = false

        let verticalAccuracy = NSAttributeDescription()
        verticalAccuracy.name = "verticalAccuracy"
        verticalAccuracy.attributeType = .doubleAttributeType
        verticalAccuracy.isOptional = false

        let speed = NSAttributeDescription()
        speed.name = "speed"
        speed.attributeType = .doubleAttributeType
        speed.isOptional = false

        let course = NSAttributeDescription()
        course.name = "course"
        course.attributeType = .doubleAttributeType
        course.isOptional = false

        entity.properties = [timestamp, latitude, longitude, altitude, horizontalAccuracy, verticalAccuracy, speed, course]

        let timestampIndex = NSFetchIndexDescription(name: "timestampIndex", elements: [
            NSFetchIndexElementDescription(property: timestamp, collationType: .binary),
        ])
        entity.indexes = [timestampIndex]

        model.entities = [entity]
        return model
    }

    private static func storeURL() -> URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return url.appendingPathComponent("LocationStore.sqlite")
    }

    private static func modelVersionURL() -> URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return url.appendingPathComponent("LocationStore.version")
    }

    private static func deleteStore(at storeURL: URL) {
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
        try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
    }

    private static func checkAndResetIfNeeded(storeURL: URL) {
        let versionURL = modelVersionURL()
        let savedVersion: Int = if let versionData = try? Data(contentsOf: versionURL),
                                   let version = try? JSONDecoder().decode(Int.self, from: versionData)
        {
            version
        } else {
            0
        }

        if savedVersion != currentModelVersion {
            print("ℹ️ Model version changed from \(savedVersion) to \(currentModelVersion), resetting database")
            deleteStore(at: storeURL)
            saveModelVersion()
        }
    }

    private static func saveModelVersion() {
        let versionURL = modelVersionURL()
        if let versionData = try? JSONEncoder().encode(currentModelVersion) {
            try? versionData.write(to: versionURL)
        }
    }
}
