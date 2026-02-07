//
//  LiveActivityManager.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import ActivityKit
import CoreLocation
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<GPSActivityAttributes>?
    private var activityStateObserver: Task<Void, Never>?

    private init() {}

    func start() {
        terminate()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        do {
            let content = GPSActivityAttributes.ContentState()
            let contentState = ActivityContent(state: content, staleDate: nil)
            let activity = try Activity.request(
                attributes: GPSActivityAttributes(),
                content: contentState,
            )
            self.activity = activity
            activityStateObserver = Task.detached(priority: .userInitiated) {
                for await state in activity.activityStateUpdates {
                    await self.processNewLiveActivityState(state)
                }
            }
        } catch {
            print("🔴 Failed to start Live Activity: \(error)")
        }
    }

    nonisolated func processNewLiveActivityState(_ state: ActivityState) async {
        print("🔔 Live Activity state updated to: \(state)")
        switch state {
        case .pending, .active: break
        case .dismissed, .ended, .stale:
            fallthrough
        @unknown default:
            await MainActor.run { self.terminate() }
        }
    }

    func updateLocation(_ location: CLLocation, photoProcessedCount: Int = 0) {
        guard let activity else { return }
        let content = GPSActivityAttributes.ContentState(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            photoProcessedCount: photoProcessedCount,
        )
        let contentState = ActivityContent(state: content, staleDate: nil)
        Task.detached(priority: .userInitiated) {
            await activity.update(contentState)
        }
    }

    func terminate() {
        activityStateObserver?.cancel()
        defer {
            activity = nil
            activityStateObserver = nil
        }

        let sema = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            let activities = Activity<GPSActivityAttributes>.activities
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            sema.signal()
        }
        sema.wait()
    }
}
