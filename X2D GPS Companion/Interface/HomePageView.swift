//
//  HomePageView.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import MapKit
import SwiftUI

struct HomePageView: View {
    @State private var model = ViewModel.shared

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
                requestAction: { Task { await model.requestPhotos() } }
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
            Map {
                UserAnnotation()
            }
            .mapControlVisibility(.hidden)
            .mapStyle(.standard)
            .frame(height: 128)
            .padding(.horizontal, -16)
            .padding(.bottom, -16)
        }
        .padding(16)
        .clipShape(.rect(cornerRadius: 16))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    var button: some View {
        RecordingButton(model: model)
    }

    var footer: some View {
        let location = model.locationService.location ?? .init()
        print(location)
        let lat = String(format: "%.5f", location.coordinate.latitude)
        let lon = String(format: "%.5f", location.coordinate.longitude)
        let acc = String(format: "%.0f", location.horizontalAccuracy)
        // x-axis relates to longitude
        // y-axis relates to latitude
        // (x,y) order is usually preferred
        let text = String(format: "(%@, %@) ±%@m", lon, lat, acc)
        return Text(text)
            .contentTransition(.numericText())
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
            .animation(.interactiveSpring, value: text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                card
                button
                footer
            }
            .padding(16)
        }
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
    }
}
