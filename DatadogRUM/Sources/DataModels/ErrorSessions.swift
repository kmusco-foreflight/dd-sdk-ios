//
//  ErrorSessions.swift
//  Datadog
//
//  Created by Kyle Musco on 4/9/25.
//

import DatadogInternal
import Foundation

internal struct ErrorSessions {
    var sessions: [ErrorSession]

    struct ErrorSession: Codable {
        let id: String
        var date: Date

        init(id: String) {
            self.id = id
            self.date = Date()
        }
    }
    
    // File URL for storing the error sessions in the cache directory.
    private static let fileURL: URL = {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachesDirectory.appendingPathComponent("RUM_ERROR_SESSIONS.plist")
    }()

    init() {
        self.sessions = Self.getSessions()
    }

    /// Reads the error sessions from the file in the cache directory. If the file doesn't exist or decoding fails, returns an empty array.
    /// - Returns: Array of `ErrorSession` objects sorted in ascending order by date.
    private static func getSessions() -> [ErrorSession] {
        if let data = UserDefaults.standard.data(forKey: "RUM_ERROR_SESSIONS") {
            do {
                var sessions = try PropertyListDecoder().decode([ErrorSession].self, from: data)
                sessions.sort { $0.date < $1.date }
                return sessions
            } catch {
                DD.logger.error("Failed to decode ErrorSessions: \(error)")
            }
        }

        return []
    }

    /// Checks whether a session with the given identifier already exists.
    /// - Parameter id: The identifier to look for.
    /// - Returns: `true` if a session with the given id exists; otherwise, `false`.
    func contains(_ id: String) -> Bool {
        for session in self.sessions {
            if session.id == id {
                return true
            }
        }

        return false
    }

    /// Adds a new error session with the provided identifier
    /// - Parameter id: The new session id to add.
    mutating func add(_ id: String) {
        // Ignore ids we've already seen
        if contains(id) { return }

        let session = ErrorSession(id: id)
        self.sessions.append(session)
        save()
    }

    /// Saves the current sessions array to the cache file after filtering out those older than 7 days.
    private func save() {
        // Only keep sessions from the last 7 days.
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let trimmedSessions = self.sessions.filter { $0.date > cutoffDate }
        
        do {
            let encodedData = try PropertyListEncoder().encode(trimmedSessions)
            try encodedData.write(to: Self.fileURL, options: .atomic)
        } catch {
            DD.logger.error("Failed to encode ErrorSessions: \(error)")
        }
    }
}
