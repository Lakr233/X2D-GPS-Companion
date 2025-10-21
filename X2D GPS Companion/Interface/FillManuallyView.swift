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
        // Check photo access permission before proceeding
        switch model.photoAccess {
        case .granted, .limited:
            // We have permission, show photo picker
            isPhotoPickerPresented = true
        case .denied, .restricted:
            // No permission, show error
            model.fillAlertMessage = String(localized: "PHOTO_ACCESS_REQUIRED_FOR_MANUAL_TAG")
            model.showFillAlert = true
        case .notDetermined:
            // Request permission first
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
        .sheet(isPresented: $isPhotoPickerPresented) {
            UIKitPhotoPicker(configuration: makePickerConfiguration()) { identifiers in
                isPhotoPickerPresented = false
                guard !identifiers.isEmpty else {
                    print("ℹ️ Picker dismissed without selecting assets")
                    return
                }

                print("🧭 Running fill for \(identifiers.count) assets after picker dismissal")
                Task { @MainActor [model] in
                    await model.fillPhotos(using: identifiers)
                }
            }
        }
    }
}
