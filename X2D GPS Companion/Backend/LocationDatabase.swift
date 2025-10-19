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
    let horizontalAccuracy: Double

    var location: CLLocation {
        CLLocation(
            coordinate: .init(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: timestamp
        )
    }
}

@objc(LocationSample)
final class LocationSample: NSManagedObject {
    @NSManaged var timestamp: Date
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var horizontalAccuracy: Double
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
    private var lastPersistedLocation: CLLocation?

    private let timeEpsilon: TimeInterval = 20
    private let distanceEpsilon: CLLocationDistance = 5

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

        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load location store: \(error)")
            }
        }

        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func record(_ location: CLLocation) async {
        guard shouldPersist(location: location) else { return }
        lastPersistedLocation = location

        let snapshot = LocationSnapshot(location: location)
        await backgroundContext.perform {
            let sample = LocationSample(context: self.backgroundContext)
            sample.timestamp = snapshot.timestamp
            sample.latitude = snapshot.latitude
            sample.longitude = snapshot.longitude
            sample.horizontalAccuracy = snapshot.horizontalAccuracy

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

    func records(in interval: DateInterval?) async throws -> [LocationRecord] {
        let context = container.viewContext
        return try await context.perform {
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
                    horizontalAccuracy: sample.horizontalAccuracy
                )
            }
        }
    }

    func nearestRecord(to date: Date, tolerance: TimeInterval, records: [LocationRecord]) -> LocationRecord? {
        guard !records.isEmpty else { return nil }

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

        var candidates: [LocationRecord] = []
        let idx = lower
        if idx < records.count {
            candidates.append(records[idx])
        }
        if idx > 0 {
            candidates.append(records[idx - 1])
        }

        let best = candidates.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
        }

        guard let best else { return nil }
        let delta = abs(best.timestamp.timeIntervalSince(date))
        guard delta <= tolerance else { return nil }
        return best
    }

    func reset() async throws {
        try await backgroundContext.perform {
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
        }
        lastPersistedLocation = nil
    }

    private func shouldPersist(location: CLLocation) -> Bool {
        guard let lastPersistedLocation else { return true }
        let delta = location.timestamp.timeIntervalSince(lastPersistedLocation.timestamp)
        if abs(delta) > timeEpsilon { return true }

        let distance = location.distance(from: lastPersistedLocation)
        if distance > distanceEpsilon { return true }

        if location.horizontalAccuracy + 1 < lastPersistedLocation.horizontalAccuracy {
            return true
        }

        return false
    }

    private struct LocationSnapshot {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let horizontalAccuracy: Double

        init(location: CLLocation) {
            timestamp = location.timestamp
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            horizontalAccuracy = max(location.horizontalAccuracy, 0)
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

        let accuracy = NSAttributeDescription()
        accuracy.name = "horizontalAccuracy"
        accuracy.attributeType = .doubleAttributeType
        accuracy.isOptional = false

        entity.properties = [timestamp, latitude, longitude, accuracy]

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
}
