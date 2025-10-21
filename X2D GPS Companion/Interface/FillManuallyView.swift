//
//  FillManuallyView.swift
//  X2D GPS Companion
//
//  Created by qaq on 21/10/2025.
//

import PhotosUI
import SwiftUI

struct FillManuallyView<Content: View>: View {
    @Bindable var model: ViewModel
    @State private var isPhotoPickerPresented: Bool = false

    let content: () -> Content

    init(model: ViewModel, @ViewBuilder content: @escaping () -> Content) {
        self.model = model
        self.content = content
    }

    private func makePickerConfiguration() -> PHPickerConfiguration {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 0
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current
        return configuration
    }

    private func handleManualTagPhotos() {
        switch model.photoAccess {
        case .granted, .limited:
            isPhotoPickerPresented = true
        case .denied:
            model.fillAlertMessage = String(localized: "PHOTO_ACCESS_REQUIRED_FOR_MANUAL_TAG")
            model.showFillAlert = true
        case .unknown:
            Task {
                await model.requestPhotos()
                // After permission request, check again
                if model.photoAccess == .granted || model.photoAccess == .limited {
                    isPhotoPickerPresented = true
                }
            }
        }
    }

    var body: some View {
        Button {
            handleManualTagPhotos()
        } label: {
            content()
        }
        .disabled(model.fillInProgress)
        .sheet(isPresented: $isPhotoPickerPresented) {
            UIKitPhotoPicker(configuration: makePickerConfiguration()) { assets in
                isPhotoPickerPresented = false
                guard !assets.isEmpty else {
                    print("ℹ️ Picker dismissed without selecting assets")
                    if model.photoAccess == .limited {
                        // present error alert to warn user that selected photo is not granted for writing
                        // please open systems settings to grant full access or grant access to this photo
                        model.fillAlertMessage = String(localized: "PHOTO_ACCESS_LIMITED_WRITE_EXPLANATION")
                        model.showFillAlert = true
                    }
                    return
                }

                print("🧭 Running fill for \(assets.count) assets after picker dismissal")
                Task { @MainActor [model] in
                    await model.fillPhotos(using: assets)
                }
            }
        }
    }
}
