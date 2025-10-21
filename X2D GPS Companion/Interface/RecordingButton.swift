//
//  RecordingButton.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import SwiftUI
import UIKit

struct RecordingButton: View {
    @Bindable var model: ViewModel
    @State var presentError: String = ""
    @State var showPermissionAlert = false
    @State var permissionAlertMessage = ""

    var isRecording: Bool { model.isRecording }
    var icon: String { isRecording ? "stop.fill" : "record.circle" }
    var text: LocalizedStringKey { isRecording ? "STOP_RECORDING" : "START_RECORDING" }

    var body: some View {
        Button { execute() } label: {
            AlignedLabel(icon: icon, text: text)
                .padding(8)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.accent)
        .buttonStyle(.glass)
        .alert(
            "ERROR",
            isPresented: .init(
                get: { !presentError.isEmpty },
                set: { newValue in if !newValue { presentError = "" } }
            )
        ) {
            Button("OK") { presentError = "" }
        } message: {
            Text(presentError)
        }
        .alert(
            "PERMISSION_REQUIRED",
            isPresented: $showPermissionAlert
        ) {
            Button("CANCEL", role: .cancel) {
                showPermissionAlert = false
            }
            Button("OPEN_SETTINGS") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                showPermissionAlert = false
            }
        } message: {
            Text(permissionAlertMessage)
        }
    }

    func execute() {
        do {
            switch model.isRecording {
            case true:
                model.stopRecording()
            case false:
                try model.startRecording()
            }
        } catch let error as RecordingError {
            print("❌ Failed to toggle recording: \(error.localizedDescription)")
            // Show permission alert with option to open settings
            permissionAlertMessage = error.localizedDescription
            showPermissionAlert = true
        } catch {
            print("❌ Failed to toggle recording: \(error.localizedDescription)")
            presentError = error.localizedDescription
        }
    }
}
