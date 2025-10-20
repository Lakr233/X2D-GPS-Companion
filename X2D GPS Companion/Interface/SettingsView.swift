//
//  SettingsView.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import Observation
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @Bindable var model: ViewModel
    @State private var fillSelection: [PhotosPickerItem] = []

    var body: some View {
        Form {
            Section("GENERAL") {
                Toggle("AUTO_START_RECORDING", isOn: $model.autoStartRecording)
                Text("AUTOMATICALLY_START_RECORDING_WHEN_APP_OPENED")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("MANUAL_FILL_SECTION_TITLE") {
                let isInProgress = model.fillInProgress
                PhotosPicker(
                    selection: $fillSelection,
                    maxSelectionCount: nil,
                    selectionBehavior: .continuous,
                    matching: .images
                ) {
                    if isInProgress {
                        ProgressView()
                    } else {
                        Label("FILL_IN_PICKER_BUTTON", systemImage: "sparkles.square.filled.on.square")
                    }
                }
                .disabled(isInProgress)
                .onChange(of: fillSelection) { _, newItems in
                    let identifiers = newItems.compactMap(\.itemIdentifier)
                    guard !identifiers.isEmpty else { return }
                    Task { await model.fillPhotos(using: identifiers) }
                    fillSelection.removeAll()
                }

                Text("FILL_IN_PICKER_DESCRIPTION")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("WHY_ARENT_MY_PHOTOS_BEING_UPDATED") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ONLY_PHOTOS_RECOGNIZED_AS_TAKEN_FROM_CAMERA_AND_CONTAINING_REQUIRED_EXIF_DATA_WILL_BE_UPDATED")

                    Text("THESE_INCLUDES_APERTURE_SHUTTER_SPEED_AND_ISO_INFORMATION")
                        .underline()

                    Text("SCREENSHOTS_EDITED_IMAGES_OR_PHOTOS_WITHOUT_COMPLETE_EXIF_DATA_WILL_NOT_BE_TAGGED")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("ABOUT") {
                LabeledContent("VERSION", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                LabeledContent("BUILD", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")

                NavigationLink {
                    LogView()
                } label: {
                    AlignedLabel(icon: "doc.text", text: "VIEW_LOGS")
                        .foregroundStyle(.accent)
                }
            }

            Section("DATABASE_MANAGEMENT") {
                Button(role: .destructive) {
                    Task { await model.resetLocationDatabase() }
                } label: {
                    Label("RESET_LOCATION_DATABASE", systemImage: "trash")
                }
                .disabled(model.fillInProgress)

                Text("RESET_LOCATION_DATABASE_DESCRIPTION")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("SETTINGS")
        .sheet(isPresented: $model.showFillSheet) {
            VStack {
                if model.fillInProgress {
                    ProgressView()
                        .padding()
                }
                Text(model.fillSheetMessage)
                    .padding()
            }
            .presentationDetents([.fraction(0.5)])
        }
    }
}
