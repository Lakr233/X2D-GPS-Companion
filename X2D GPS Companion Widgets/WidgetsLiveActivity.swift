//
//  WidgetsLiveActivity.swift
//  X2D GPS Companion Widgets
//
//  Created by qaq on 18/10/2025.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GPSActivityAttributes.self) { context in
            activityConfiguration(for: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Spacer()
                        Spacer()
                        Text(String("🎉"))
                        Divider().hidden()
                        Text("X2D_GPS_COMPANION_IS_WORKING")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .preferredColorScheme(.dark)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.accent)
            } compactTrailing: {
                let accuracy = context.state.accuracy ?? -1
                Text(String("±\(Int(accuracy))m"))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.accent)
            }
            .keylineTint(.green)
        }
    }
}
