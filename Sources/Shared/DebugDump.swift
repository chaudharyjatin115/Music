//
//  DebugDump.swift
//  YT Music
//

import Foundation

/// Writes a response body or script to Caches for inspection.
nonisolated enum DebugDump {
    @discardableResult
    static func write(_ data: Data, to name: String) -> String? {
        #if DEBUG
        guard let dir = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let safeName = (name as NSString).lastPathComponent
        let url = dir.appendingPathComponent(safeName)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
