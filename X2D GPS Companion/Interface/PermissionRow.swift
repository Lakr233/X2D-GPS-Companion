//
//  PermissionRow.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import SwiftUI
import UIKit

struct PermissionRow: View {
    let icon: String
    let title: LocalizedStringKey
    let status: AuthStatus
    let requestAction: () -> Void
    let limitedExplanation: LocalizedStringKey?

    init(
        icon: String,
        title: LocalizedStringKey,
        status: AuthStatus,
        requestAction: @escaping () -> Void,
        limitedExplanation: LocalizedStringKey? = "LIMITED_PHOTO_ACCESS_EXPLANATION"
    ) {
        self.icon = icon
        self.title = title
        self.status = status
        self.requestAction = requestAction
        self.limitedExplanation = limitedExplanation
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 16) {
                AlignedLabel(icon: icon, text: title)
                AccessBadge(status: status)
                if status == .limited, let explanation = limitedExplanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if status == .denied {
                Button("OPEN_SETTINGS") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                .font(.body.bold())
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
                .underline()
            } else if status == .unknown {
                Button("GRANT_PERMISSION") {
                    requestAction()
                }
                .font(.body.bold())
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
                .underline()
            } else {
                Button("VIEW_SETTINGS") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                .font(.body.bold())
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
                .underline()
            }
        }
    }
}
