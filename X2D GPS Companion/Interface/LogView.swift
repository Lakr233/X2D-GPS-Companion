//
//  LogView.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import SwiftUI

struct LogView: View {
    @State private var messages: [String] = []

    private func fill() {
        messages = LogManager.shared.getMessages()
    }

    var body: some View {
        List {
            ForEach(Array(messages.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(nil)
                    .textSelection(.enabled)
            }
        }
        .listStyle(.plain)
        .navigationTitle("LOGS")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { fill() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear { fill() }
    }
}
