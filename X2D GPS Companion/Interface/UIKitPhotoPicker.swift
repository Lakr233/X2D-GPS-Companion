//
//  UIKitPhotoPicker.swift
//  X2D GPS Companion
//
//  Created by qaq on 20/10/2025.
//

import PhotosUI
import SwiftUI

struct UIKitPhotoPicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = PHPickerViewController

    var configuration: PHPickerConfiguration
    var completion: ([PHAsset]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: PHPickerViewController, context _: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: UIKitPhotoPicker

        init(parent: UIKitPhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            if results.isEmpty {
                DispatchQueue.main.async {
                    self.parent.completion([])
                }
                return
            }

            Task {
                let assets = await self.resolveAssets(from: results)
                await MainActor.run {
                    self.parent.completion(assets)
                }
            }
        }

        private func resolveAssets(from results: [PHPickerResult]) async -> [PHAsset] {
            let identifiers = results.compactMap(\.assetIdentifier)
            guard !identifiers.isEmpty else { return [] }

            return await withCheckedContinuation { continuation in
                Task.detached(priority: .userInitiated) {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                    var assets: [PHAsset] = []
                    assets.reserveCapacity(fetchResult.count)
                    fetchResult.enumerateObjects { asset, _, _ in
                        assets.append(asset)
                    }
                    continuation.resume(returning: assets)
                }
            }
        }
    }
}
