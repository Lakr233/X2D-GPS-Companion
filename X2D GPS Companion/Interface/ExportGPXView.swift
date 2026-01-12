//
//  ExportGPXView.swift
//  X2D GPS Companion
//
//  Created by Codex on 12/01/2026.
//

import SwiftUI
import UIKit

struct ExportGPXView<Content: View>: View {
    @Bindable var model: ViewModel

    @State private var isPresented: Bool = false
    @State private var fromDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var toDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var isExporting: Bool = false
    @State private var presentError: String = ""
    @State private var shareItem: ShareItem?

    let content: () -> Content

    init(model: ViewModel, @ViewBuilder content: @escaping () -> Content) {
        self.model = model
        self.content = content
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            content()
        }
        .disabled(isExporting)
        .sheet(isPresented: $isPresented) {
            ExportGPXSheet(
                model: model,
                fromDate: $fromDate,
                toDate: $toDate,
                isExporting: $isExporting,
                presentError: $presentError,
                shareItem: $shareItem
            )
        }
    }
}

private struct ExportGPXSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: ViewModel
    @Binding var fromDate: Date
    @Binding var toDate: Date
    @Binding var isExporting: Bool
    @Binding var presentError: String
    @Binding var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("EXPORT_GPX_DATE_RANGE") {
                    DatePicker(
                        "EXPORT_GPX_FROM",
                        selection: $fromDate,
                        displayedComponents: [.date]
                    )
                    DatePicker(
                        "EXPORT_GPX_TO",
                        selection: $toDate,
                        in: fromDate...,
                        displayedComponents: [.date]
                    )
                }

                Section {
                    Button { export() } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            AlignedLabel(icon: "square.and.arrow.up", text: "EXPORT_GPX")
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("EXPORT_GPX")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("CANCEL") { dismiss() }
                }
            }
        }
        .alert(
            "ERROR",
            isPresented: .init(
                get: { !presentError.isEmpty },
                set: { newValue in if !newValue { presentError = "" } }
            )
        ) {
            Button("OK", role: .cancel) { presentError = "" }
        } message: {
            Text(presentError)
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private func export() {
        isExporting = true
        presentError = ""
        shareItem = nil

        Task { @MainActor in
            defer { isExporting = false }
            do {
                let (start, end) = normalizeDateRange(from: fromDate, to: toDate)
                let url = try model.exportGPX(from: start, to: end)
                shareItem = ShareItem(url: url)
            } catch {
                print("❌ Failed to export GPX: \(error.localizedDescription)")
                presentError = error.localizedDescription
            }
        }
    }

    private func normalizeDateRange(from start: Date, to end: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: start)
        let endStart = calendar.startOfDay(for: end)
        let end = calendar.date(byAdding: .day, value: 1, to: endStart) ?? endStart
        return (start: start, end: end)
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
