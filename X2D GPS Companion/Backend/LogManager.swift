//
//  LogManager.swift
//  X2D GPS Companion
//
//  Created by qaq on 18/10/2025.
//

import Foundation

final nonisolated class LogManager: Sendable {
    static let shared = LogManager()

    private let messageQueue = DispatchQueue(label: "wiki.qaq.log")
    private nonisolated(unsafe) var messages: [String] = []

    func write(_ content: String) {
        messageQueue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logMessage = "[\(timestamp)]\n\(content)"
            self.messages.append(logMessage)
        }
    }

    func getMessages() -> [String] {
        messageQueue.sync { messages }
    }
}

nonisolated func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    Swift.print(items, separator: separator, terminator: terminator)

    let message = items.map { String(describing: $0) }.joined(separator: separator)
    LogManager.shared.write(message)
}
