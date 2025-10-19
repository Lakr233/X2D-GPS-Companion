//
//  PhotoLibraryService.swift
//  X2D GPS Companion
//
//  Created by qaq on 19/10/2025.
//

import CoreLocation
import Foundation
import ImageIO
import Observation
import Photos

protocol PhotoLibraryServiceDelegate: AnyObject {
    func photoLibraryService(_ service: PhotoLibraryService, didUpdatePhotoProcessedCount count: Int)
}

@MainActor
@Observable
final class PhotoLibraryService: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoLibraryService()

    private(set) var photoProcessedCount: Int = 0
    private(set) var isMonitoring: Bool = false

    weak var delegate: PhotoLibraryServiceDelegate?
    private let locationService = LocationService.shared
    private var allPhotosCache: PHFetchResult<PHAsset>?

    override private init() {
        super.init()
    }

    func beginMonitoring() throws {
        guard !isMonitoring else { return }

        photoProcessedCount = 0
        isMonitoring = true

        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allPhotosCache = PHAsset.fetchAssets(with: .image, options: allPhotosOptions)
        PHPhotoLibrary.shared().register(self)
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        allPhotosCache = nil
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard isMonitoring else { return }
            guard let location = locationService.location else { return }
            guard let allPhotosCache else { return }
            guard let collectionChanges = changeInstance.changeDetails(for: allPhotosCache) else { return }
            let fetchedAssets = collectionChanges.fetchResultAfterChanges
            guard let insertedIndexes = collectionChanges.insertedIndexes else { return }
            guard !insertedIndexes.isEmpty else { return }

            print("🔔 Detected \(insertedIndexes.count) new photos")
            fetchedAssets.enumerateObjects(at: insertedIndexes, options: []) { asset, _, _ in
                Task { await self.handle(asset: asset, location: location) }
            }
        }
    }

    func handle(asset: PHAsset, location: CLLocation) async {
        guard asset.location == nil else { return }
        guard await asset.hasCameraEXIF() else { return }

        do {
            try await asset.writeGPSLocation(location)
            photoProcessedCount += 1
            delegate?.photoLibraryService(self, didUpdatePhotoProcessedCount: photoProcessedCount)
            print("📍 Tagged photo with location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } catch {
            print("❌ \(error.localizedDescription)")
        }
    }

    func incrementProcessedCount(by value: Int) {
        guard value > 0 else { return }
        photoProcessedCount += value
        delegate?.photoLibraryService(self, didUpdatePhotoProcessedCount: photoProcessedCount)
    }
}

extension PHAsset {
    func hasCameraEXIF() async -> Bool {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.version = .current
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: self, options: options) { data, _, _, _ in
                guard let data,
                      let src = CGImageSourceCreateWithData(data as CFData, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                      let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
                else {
                    continuation.resume(returning: false)
                    return
                }

                let hasAperture = exif[kCGImagePropertyExifApertureValue] != nil || exif[kCGImagePropertyExifFNumber] != nil
                let hasShutter = exif[kCGImagePropertyExifShutterSpeedValue] != nil || exif[kCGImagePropertyExifExposureTime] != nil
                let hasISO = exif[kCGImagePropertyExifISOSpeedRatings] != nil

                continuation.resume(returning: hasAperture && hasShutter && hasISO)
            }
        }
    }

    func writeGPSLocation(_ location: CLLocation) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetChangeRequest(for: self)
                req.location = location
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if let error {
                        continuation.resume(throwing: error)
                    } else if !success {
                        continuation.resume(throwing: NSError())
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
