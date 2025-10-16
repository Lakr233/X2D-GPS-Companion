//
//  WidgetsLiveActivity+View.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import SwiftUI
import WidgetKit

extension WidgetsLiveActivity {
    func activityConfiguration(for context: ActivityViewContext<GPSActivityAttributes>) -> some View {
        let count = context.state.photoProcessedCount
        let title = count > 0
            ? String(format: String(localized: "PHOTOS_UPDATED_COUNT"), count)
            : String(localized: "WAITING_FOR_NEW_PHOTOS")

        // x-axis relates to longitude
        // y-axis relates to latitude
        // (x,y) order is usually preferred
        let subtitle: String = {
            if let lat = context.state.latitude,
               let lon = context.state.longitude
            {
                let lat = String(format: "%.4f", lat)
                let lon = String(format: "%.4f", lon)
                let acc = String(format: "%.0f", context.state.accuracy ?? -1)
                return "(\(lon), \(lat)) ±\(acc)m"
            } else {
                return "..."
            }
        }()

        return HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.title.bold())
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.bold())
                    .contentTransition(.numericText())
                    .animation(.interactiveSpring, value: context.state.photoProcessedCount)

                Text(subtitle)
                    .font(.system(.caption))
                    .monospaced()
                    .contentTransition(.numericText())
                    .animation(.interactiveSpring, value: context.state.latitude)
            }
            Spacer()
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title2.bold())
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Color.black.ignoresSafeArea())
        .activityBackgroundTint(Color.black.opacity(0.8))
        .preferredColorScheme(.dark)
    }
}
