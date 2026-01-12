//
//  GPXExporter.swift
//  X2D GPS Companion
//
//  Created by Codex on 12/01/2026.
//

import Foundation

struct GPXExporter {
    static func export(records: [LocationRecord], fileName: String) throws -> URL {
        let gpx = makeGPX(records: records, creator: "X2D GPS Companion")

        var url = FileManager.default.temporaryDirectory
        url.appendPathComponent(fileName)
        url.appendPathExtension("gpx")

        try gpx.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func defaultFileName(from startDate: Date, to endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"

        return "X2D-GPS-Track-\(formatter.string(from: startDate))-\(formatter.string(from: endDate))"
    }

    static func makeGPX(records: [LocationRecord], creator: String) -> String {
        var lines: [String] = []
        lines.reserveCapacity(max(64, records.count * 10))

        let iso8601 = ISO8601DateFormatter()
        iso8601.timeZone = TimeZone(secondsFromGMT: 0)
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(
            #"<gpx version="1.1" creator="\#(xmlEscape(creator))" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">"#
        )
        lines.append("  <trk>")
        lines.append("    <name>\(xmlEscape("Location Track"))</name>")
        lines.append("    <trkseg>")

        for record in records {
            let time = iso8601.string(from: record.timestamp)
            lines.append(String(format: "      <trkpt lat=\"%.8f\" lon=\"%.8f\">", record.latitude, record.longitude))
            lines.append(String(format: "        <ele>%.3f</ele>", record.altitude))
            lines.append("        <time>\(time)</time>")
            lines.append("        <extensions>")
            lines.append(String(format: "          <horizontalAccuracy>%.3f</horizontalAccuracy>", record.horizontalAccuracy))
            lines.append(String(format: "          <verticalAccuracy>%.3f</verticalAccuracy>", record.verticalAccuracy))
            lines.append(String(format: "          <speed>%.3f</speed>", record.speed))
            lines.append(String(format: "          <course>%.3f</course>", record.course))
            lines.append("        </extensions>")
            lines.append("      </trkpt>")
        }

        lines.append("    </trkseg>")
        lines.append("  </trk>")
        lines.append("</gpx>")

        return lines.joined(separator: "\n")
    }

    private static func xmlEscape(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
