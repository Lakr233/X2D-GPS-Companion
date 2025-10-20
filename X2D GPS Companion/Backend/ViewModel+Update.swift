//
//  ViewModel+Update.swift
//  X2D GPS Companion
//
//  Created by qaq on 19/10/2025.
//

import Foundation
import Photos

extension ViewModel {
    func updateLiveActivity() {
        guard let location = locationService.location else { return }
        liveActivity.updateLocation(
            location,
            photoProcessedCount: photoLibraryService.photoProcessedCount
        )
    }

    func fillPhotos(using identifiers: [String]) async {
        guard !fillInProgress else {
            print("⚠️ Fill request ignored because another fill is in progress")
            return
        }
        guard photoAccess == .granted || photoAccess == .limited else {
            presentResult(String(localized: "FILL_IN_REQUIRES_PHOTO_ACCESS"))
            return
        }

        fillInProgress = true
        showFillSheet = true
        fillSheetMessage = String(localized: "FILL_IN_PROGRESS")
        print("🧭 Begin filling locations for \(identifiers.count) selected assets")
        defer {
            fillInProgress = false
            print("🧭 Fill request finished")
        }

        do {
            let records = try await locationDatabase.records(in: nil)
            print("ℹ️ Loaded \(records.count) location records for matching")
            guard !records.isEmpty else {
                presentResult(String(localized: "FILL_IN_NO_LOCATIONS"))
                return
            }

            let assets = try await fetchAssets(identifiers: identifiers)
            print("ℹ️ Resolved \(assets.count) assets from selection")
            guard !assets.isEmpty else {
                presentResult(String(localized: "FILL_IN_NO_ASSETS"))
                return
            }

            let updatedCount = await updateAssets(assets, with: records)
            print("ℹ️ Updated \(updatedCount) assets with location metadata")
            if updatedCount == 0 {
                print("⚠️ No assets matched within tolerance")
                presentResult(String(localized: "FILL_IN_NO_MATCHES"))
            } else {
                photoLibraryService.incrementProcessedCount(by: updatedCount)
                let template = String(localized: "FILL_IN_SUCCESS_%@")
                let message = String(format: template, updatedCount.description)
                presentResult(message)
            }
        } catch {
            print("❌ Fill operation failed: \(error.localizedDescription)")
            presentResult(error.localizedDescription)
        }
    }

    func resetLocationDatabase() async {
        guard !fillInProgress else { return }
        fillInProgress = true
        defer { fillInProgress = false }

        do {
            let deletedCount = try await locationDatabase.reset()
            let template = String(localized: "DELETED_%@_RECORDS")
            let message = String(format: template, deletedCount.description)
            resetAlertMessage = message
            showResetAlert = true
        } catch {
            resetAlertMessage = error.localizedDescription
            showResetAlert = true
        }
    }

    private func fetchAssets(identifiers: [String]) async throws -> [PHAsset] {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                guard !identifiers.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                var result: [PHAsset] = []
                result.reserveCapacity(assets.count)
                assets.enumerateObjects { asset, _, _ in
                    result.append(asset)
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func updateAssets(_ assets: [PHAsset], with records: [LocationRecord]) async -> Int {
        let tolerance: TimeInterval = 5 * 60
        var updatedCount = 0
        for (index, asset) in assets.enumerated() {
            if !overwriteExistingLocation {
                guard asset.location == nil else { continue }
            }
            guard let captureDate = asset.creationDate else { continue }
            
            // Get the two nearest records (before and after)
            let (before, after) = locationDatabase.nearestRecords(
                to: captureDate,
                tolerance: tolerance,
                records: records
            )
            
            guard before != nil || after != nil else { continue }
            
            let location: CLLocation
            if let before, let after {
                // Both records exist, check if we need interpolation
                let timeDiff = abs(before.timestamp.timeIntervalSince(captureDate))
                if timeDiff > 30 {
                    // Interpolate between the two points
                    location = interpolateLocation(from: before, to: after, at: captureDate)
                    print("🔄 Interpolating location for asset [\(asset.localIdentifier)] between \(before.timestamp) and \(after.timestamp)")
                } else {
                    // Use the closer one
                    let beforeDiff = abs(before.timestamp.timeIntervalSince(captureDate))
                    let afterDiff = abs(after.timestamp.timeIntervalSince(captureDate))
                    location = beforeDiff < afterDiff ? before.location : after.location
                }
            } else if let before {
                location = before.location
            } else if let after {
                location = after.location
            } else {
                continue
            }

            do {
                try await asset.writeGPSLocation(location)
                updatedCount += 1
                fillSheetMessage = String(
                    format: String(localized: "FILL_IN_PROGRESS_COUNT_%@"),
                    arguments: ["\(index + 1)/\(assets.count)"]
                )
                let lat = String(format: "%.6f", location.coordinate.latitude)
                let lon = String(format: "%.6f", location.coordinate.longitude)
                let acc = String(format: "%.0f", location.horizontalAccuracy)
                print("✅ Updated asset [\(asset.localIdentifier)] \(index + 1)/\(assets.count) with location: (\(lat), \(lon)) ±\(acc)m")
            } catch {
                print("❌ Failed to fill GPS for asset [\(asset.localIdentifier)]: \(error.localizedDescription)")
            }
        }
        return updatedCount
    }

    private func interpolateLocation(from start: LocationRecord, to end: LocationRecord, at targetDate: Date) -> CLLocation {
        let startTime = start.timestamp.timeIntervalSince1970
        let endTime = end.timestamp.timeIntervalSince1970
        let targetTime = targetDate.timeIntervalSince1970
        
        // Calculate the interpolation factor (0.0 to 1.0)
        let totalDuration = endTime - startTime
        guard totalDuration > 0 else { return start.location }
        
        let factor = (targetTime - startTime) / totalDuration
        let clampedFactor = max(0.0, min(1.0, factor))
        
        // Interpolate latitude and longitude
        let lat = start.latitude + (end.latitude - start.latitude) * clampedFactor
        let lon = start.longitude + (end.longitude - start.longitude) * clampedFactor
        
        // Use the worse (larger) accuracy of the two points
        let accuracy = max(start.horizontalAccuracy, end.horizontalAccuracy)
        
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: targetDate
        )
    }

    private func presentResult(_ message: String) {
        fillSheetMessage = message
        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {}
            guard let self else { return }
            showFillSheet = false
            fillSheetMessage = ""
        }
    }
}
