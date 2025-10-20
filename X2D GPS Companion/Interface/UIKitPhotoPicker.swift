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
    var completion: ([String]) -> Void

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
                let identifiers = await self.resolveIdentifiers(from: results)
                await MainActor.run {
                    self.parent.completion(identifiers)
                }
            }
        }

        private func resolveIdentifiers(from results: [PHPickerResult]) async -> [String] {
            var identifiers: [String] = []
            identifiers.reserveCapacity(results.count)
            for result in results {
                if let identifier = result.assetIdentifier {
                    identifiers.append(identifier)
                }
            }
            return identifiers
        }
    }
}
