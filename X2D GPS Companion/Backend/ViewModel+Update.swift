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

    enum FillMode: String, CaseIterable, Identifiable {
        case halfHour
        case twoHours
        case oneDay
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .halfHour: String(localized: "FILL_MODE_HALF_HOUR")
            case .twoHours: String(localized: "FILL_MODE_TWO_HOURS")
            case .oneDay: String(localized: "FILL_MODE_ONE_DAY")
            case .all: String(localized: "FILL_MODE_ALL")
            }
        }

        var interval: TimeInterval? {
            switch self {
            case .halfHour: 30 * 60
            case .twoHours: 2 * 60 * 60
            case .oneDay: 24 * 60 * 60
            case .all: nil
            }
        }
    }

    func fillPhotos(using mode: FillMode) async {
        guard !fillInProgress else { return }
        guard photoAccess == .granted || photoAccess == .limited else {
            presentResult(String(localized: "FILL_IN_REQUIRES_PHOTO_ACCESS"))
            return
        }

        fillInProgress = true
        showFillSheet = true
        fillSheetMessage = String(localized: "FILL_IN_PROGRESS")
        defer { fillInProgress = false }

        do {
            let interval = makeDateInterval(from: mode.interval)
            let records = try await locationDatabase.records(in: interval)
            guard !records.isEmpty else {
                presentResult(String(localized: "FILL_IN_NO_LOCATIONS"))
                return
            }

            let assets = try await fetchAssets(in: interval)
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

    private func makeDateInterval(from interval: TimeInterval?) -> DateInterval? {
        guard let interval else { return nil }
        let now = Date()
        return DateInterval(start: now.addingTimeInterval(-interval), end: now)
    }

    private func fetchAssets(in interval: DateInterval?) async throws -> [PHAsset] {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                if let interval {
                    options.predicate = NSPredicate(
                        format: "creationDate >= %@ AND creationDate <= %@",
                        interval.start as NSDate,
                        interval.end as NSDate
                    )
                }

                let assets = PHAsset.fetchAssets(with: .image, options: options)
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
        for asset in assets {
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
