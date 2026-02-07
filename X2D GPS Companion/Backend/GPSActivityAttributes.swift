//
//  GPSActivityAttributes.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import ActivityKit
import Foundation

nonisolated struct GPSActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var latitude: Double?
        var longitude: Double?
        var accuracy: Double?
        var timestamp: Date = .init()
        var photoProcessedCount: Int = 0

        init(
            latitude: Double? = nil,
            longitude: Double? = nil,
            accuracy: Double? = nil,
            timestamp: Date = .init(),
            photoProcessedCount: Int = 0,
        ) {
            self.latitude = latitude
            self.longitude = longitude
            self.accuracy = accuracy
            self.timestamp = timestamp
            self.photoProcessedCount = photoProcessedCount
        }
    }
}
