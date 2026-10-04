//
//  Preferences.swift
//  SetSplitter
//
//  Persists the last-used parse options,
//  genre, and a security-scoped bookmark to the last output folder.
//

import Foundation
import SetSplitterCore

@MainActor
protocol PreferencesStoring {
    func loadParseOptions() -> ParseOptions
    func saveParseOptions(_ options: ParseOptions)
    func loadGenre() -> String?
    func saveGenre(_ genre: String)
    func loadOutputFolder() -> SecurityScopedAccess?
    func saveOutputFolder(_ url: URL)
}

@MainActor
struct UserDefaultsPreferences: PreferencesStoring {

    private let defaults: UserDefaults

    private enum Key {
        static let parseOptions = "parseOptions.v1"
        static let genre = "genre"
        static let outputBookmark = "outputFolderBookmark"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadParseOptions() -> ParseOptions {
        guard let data = defaults.data(forKey: Key.parseOptions),
              let options = try? JSONDecoder().decode(ParseOptions.self, from: data)
        else { return .default }
        return options
    }

    func saveParseOptions(_ options: ParseOptions) {
        if let data = try? JSONEncoder().encode(options) {
            defaults.set(data, forKey: Key.parseOptions)
        }
    }

    func loadGenre() -> String? { defaults.string(forKey: Key.genre) }

    func saveGenre(_ genre: String) { defaults.set(genre, forKey: Key.genre) }

    /// Resolves the stored bookmark and starts access. Returns `nil` when
    /// there is none, or the folder is gone / no longer accessible.
    func loadOutputFolder() -> SecurityScopedAccess? {
        guard let data = defaults.data(forKey: Key.outputBookmark) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
        else { return nil }
        let access = SecurityScopedAccess(url: url)
        // Refreshing a stale bookmark needs the security scope to be active, so it
        // must happen after `access` starts, not before.
        if stale { saveOutputFolder(url) }
        return access
    }

    func saveOutputFolder(_ url: URL) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope) else { return }
        defaults.set(data, forKey: Key.outputBookmark)
    }
}
