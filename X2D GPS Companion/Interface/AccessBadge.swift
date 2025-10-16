//
//  AccessBadge.swift
//  X2D GPS Companion
//
//  Created by qaq on 16/10/2025.
//

import SwiftUI

struct AccessBadge: View {
    let status: AuthStatus

    var body: some View {
        switch status {
        case .unknown:
            AlignedLabel(icon: "questionmark.circle", text: "UNKNOWN")
                .foregroundStyle(.secondary)
        case .granted:
            AlignedLabel(icon: "checkmark.circle.fill", text: "ALLOWED")
                .foregroundStyle(.green)
        case .limited:
            AlignedLabel(icon: "exclamationmark.triangle.fill", text: "LIMITED")
                .foregroundStyle(.red)
        case .denied:
            AlignedLabel(icon: "xmark.octagon.fill", text: "DENIED")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        AccessBadge(status: .unknown)
        AccessBadge(status: .granted)
        AccessBadge(status: .limited)
        AccessBadge(status: .denied)
    }
}
