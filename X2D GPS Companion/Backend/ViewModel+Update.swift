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
        guard !fillInProgress else { return }
        guard photoAccess == .granted || photoAccess == .limited else {
            presentResult(String(localized: "FILL_IN_REQUIRES_PHOTO_ACCESS"))
            return
        }

        fillInProgress = true
        showFillSheet = true
        fillSheetMessage = String(localized: "FILL_IN_PROGRESS")
        print("🧭 Begin filling locations for \(identifiers.count) selected assets")
        defer { fillInProgress = false }

        do {
            let records = try await locationDatabase.records(in: nil)
            guard !records.isEmpty else {
                presentResult(String(localized: "FILL_IN_NO_LOCATIONS"))
                return
            }

            let assets = try await fetchAssets(identifiers: identifiers)
            guard !assets.isEmpty else {
                presentResult(String(localized: "FILL_IN_NO_ASSETS"))
                return
            }

            let updatedCount = await updateAssets(assets, with: records)
            if updatedCount == 0 {
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
            try await locationDatabase.reset()
            presentResult(String(localized: "RESET_LOCATION_DATABASE_SUCCESS"))
        } catch {
            presentResult(error.localizedDescription)
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
                print("✅ Updated asset \(index + 1)/\(assets.count)")
            } catch {
                print("❌ Failed to fill GPS for asset: \(error.localizedDescription)")
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
