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
            guard asset.location == nil else { continue }
            guard let captureDate = asset.creationDate else { continue }
            guard let record = locationDatabase.nearestRecord(
                to: captureDate,
                tolerance: tolerance,
                records: records
            ) else { continue }

            do {
                try await asset.writeGPSLocation(record.location)
                updatedCount += 1
                fillSheetMessage = String(
                    format: String(localized: "FILL_IN_PROGRESS_COUNT_%@"),
                    arguments: ["\(index + 1)/\(assets.count)"]
                )
                let lat = String(format: "%.6f", record.location.coordinate.latitude)
                let lon = String(format: "%.6f", record.location.coordinate.longitude)
                let acc = String(format: "%.0f", record.location.horizontalAccuracy)
                print("✅ Updated asset [\(asset.localIdentifier)] \(index + 1)/\(assets.count) with location: (\(lat), \(lon)) ±\(acc)m")
            } catch {
                print("❌ Failed to fill GPS for asset [\(asset.localIdentifier)]: \(error.localizedDescription)")
            }
        }
        return updatedCount
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
