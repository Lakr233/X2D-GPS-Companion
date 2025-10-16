//
//  SettingsView.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var model: ViewModel

    var body: some View {
        Form {
            Section("GENERAL") {
                Toggle("AUTO_START_RECORDING", isOn: $model.autoStartRecording)
                Text("AUTOMATICALLY_START_RECORDING_WHEN_APP_OPENED")
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
        }
        .navigationTitle("SETTINGS")
    }
}
