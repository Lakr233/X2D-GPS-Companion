//
//  ViewModel+Export.swift
//  X2D GPS Companion
//
//  Created by Codex on 12/01/2026.
//

import Foundation

enum GPXExportError: LocalizedError {
    case invalidDateRange
    case noRecords

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            String(localized: "EXPORT_GPX_INVALID_RANGE")
        case .noRecords:
            String(localized: "EXPORT_GPX_NO_RECORDS")
        }
    }
}

extension ViewModel {
    func exportGPX(from startDate: Date, to endDate: Date) throws -> URL {
        guard endDate > startDate else {
            throw GPXExportError.invalidDateRange
        }

        let interval = DateInterval(start: startDate, end: endDate)
        let records = try locationDatabase.records(in: interval)
        guard !records.isEmpty else {
            throw GPXExportError.noRecords
        }

        let inclusiveEndDate = endDate.addingTimeInterval(-1)
        let fileName = GPXExporter.defaultFileName(from: startDate, to: inclusiveEndDate)
        return try GPXExporter.export(records: records, fileName: fileName)
    }
}
