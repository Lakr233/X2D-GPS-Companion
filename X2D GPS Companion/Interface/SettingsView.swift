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
    @State private var showResetConfirmation: Bool = false

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
                FillManuallyView(model: model) {
                    if isInProgress {
                        ProgressView()
                    } else {
                        AlignedLabel(icon: "sparkles.square.filled.on.square", text: "FILL_IN_PICKER_BUTTON")
                    }
                }
                .disabled(isInProgress)

                ExportGPXView(model: model) {
                    AlignedLabel(icon: "square.and.arrow.up.on.square.fill", text: "EXPORT_GPX")
                }
                .disabled(isInProgress)

                Toggle("OVERWRITE_EXISTING_LOCATION", isOn: $model.overwriteExistingLocation)

                VStack(alignment: .leading, spacing: 8) {
                    Text("FILL_IN_PICKER_DESCRIPTION")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("FILL_IN_DETAILED_EXPLANATION")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                    showResetConfirmation = true
                } label: {
                    AlignedLabel(icon: "trash", text: "RESET_LOCATION_DATABASE")
                }
                .disabled(model.fillInProgress)

                Text("RESET_LOCATION_DATABASE_DESCRIPTION")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("SETTINGS")
        .alert("FILL_COMPLETE", isPresented: $model.showFillAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.fillAlertMessage)
        }
        .alert("RESET_LOCATION_DATABASE", isPresented: $showResetConfirmation) {
            Button("CANCEL", role: .cancel) {}
            Button("RESET", role: .destructive) {
                model.resetLocationDatabase()
            }
        } message: {
            Text("RESET_LOCATION_DATABASE_CONFIRMATION")
        }
        .alert("DATABASE_RESET_COMPLETE", isPresented: $model.showResetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.resetAlertMessage)
        }
    }
}
