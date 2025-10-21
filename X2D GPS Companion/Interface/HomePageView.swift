//
//  HomePageView.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import MapKit
import PhotosUI
import SwiftUI

struct HomePageView: View {
    @State private var model = ViewModel.shared
    @State private var isPhotoPickerPresented: Bool = false

    private func makePickerConfiguration() -> PHPickerConfiguration {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 0
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current
        return configuration
    }

    var header: some View {
        Text("START_RECORDING_TO_CAPTURE_GPS_AND_AUTO_TAG_NEW_PHOTOS_FROM_YOUR_X2D")
            .font(.body)
    }

    var card: some View {
        VStack(spacing: 16) {
            PermissionRow(
                icon: "photo.on.rectangle",
                title: "PHOTO_ACCESS",
                status: model.photoAccess,
                requestAction: { Task { await model.requestPhotos() } },
                limitedExplanation: "PHOTO_ACCESS_LIMITED_EXPLANATION"
            )
            Divider()
                .padding(.horizontal, -16)
            PermissionRow(
                icon: "location",
                title: "LOCATION_ACCESS",
                status: model.locationAccess,
                requestAction: { model.requestLocationAlways() },
                limitedExplanation: "LOCATION_REQUIRES_ALWAYS_ACCESS_FOR_BACKGROUND_RECORDING"
            )
            if model.photoAccess == .unknown, model.locationAccess == .unknown {
                Divider()
                    .padding(.horizontal, -16)
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHY_WE_NEED_THESE_PERMISSIONS")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("PERMISSIONS_EXPLANATION_DETAIL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if model.locationAccess == .granted {
                Map {
                    UserAnnotation()
                }
                .mapControlVisibility(.hidden)
                .mapStyle(.standard)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, -16)
                .padding(.bottom, -16)
                .transition(.opacity)
                .frame(minHeight: 50, maxHeight: .infinity)
            }
        }
        .padding(16)
        .clipShape(.rect(cornerRadius: 16))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    var buttons: some View {
        HStack(spacing: 12) {
            RecordingButton(model: model)

            Button {
                isPhotoPickerPresented = true
            } label: {
                AlignedLabel(icon: "photo.on.rectangle.angled", text: "MANUAL_TAG_PHOTOS")
                    .padding(8)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.accent)
            .buttonStyle(.glass)
            .disabled(model.fillInProgress)
        }
    }

    var footer: some View {
        let location = model.locationService.location ?? .init()
        let lat = String(format: "%.5f", location.coordinate.latitude)
        let lon = String(format: "%.5f", location.coordinate.longitude)
        let acc = String(format: "%.0f", location.horizontalAccuracy)
        // x-axis relates to longitude
        // y-axis relates to latitude
        // (x,y) order is usually preferred
        let text = String(format: "(%@, %@) ±%@m", lon, lat, acc)
        print("ℹ️ \(text)")
        return Text(text)
            .contentTransition(.numericText())
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
            .animation(.interactiveSpring, value: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            card
                .fixedSize(horizontal: false, vertical: true)
            if model.locationAccess != .granted {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
            }
            buttons
            footer
        }
        .padding(16)
        .animation(.interactiveSpring, value: model.locationAccess == .granted)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(model: model)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .navigationTitle("X2D_GPS_COMPANION")
        .background(BackgroundGradient().ignoresSafeArea())
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
        .alert("FILL_COMPLETE", isPresented: $model.showFillAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.fillAlertMessage)
        }
        .alert("RECORDING_STARTED_WITH_LIMITED_ACCESS", isPresented: .init(
            get: { model.isRecording && model.photoAccess == .limited },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("LIMITED_PHOTO_ACCESS_RECORDING_INFO")
        }
    }
}
