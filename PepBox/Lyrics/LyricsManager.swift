//
//  LyricsManager.swift
//  PepBox
//
//  Synced lyrics for the expanded media player, from LRCLIB (lrclib.net: free,
//  open, no API key). Off by default because it sends the song title and artist.
//

import Foundation
import Combine

@MainActor
final class LyricsManager: ObservableObject {
    static let shared = LyricsManager()
    static let enabledKey = "syncedLyricsEnabled"

    /// Lyrics for the current track, if LRCLIB has synced ones.
    @Published private(set) var lyrics: SyncedLyrics?

    private var currentKey: String?
    private var cache: [String: SyncedLyrics?] = [:]
    private var task: Task<Void, Never>?

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    /// Looks up lyrics when the track changes.
    func load(title: String, artist: String, duration: TimeInterval) {
        guard isEnabled, !title.isEmpty, !artist.isEmpty else {
            lyrics = nil
            currentKey = nil
            return
        }
        let key = "\(artist)\u{1F}\(title)"
        guard key != currentKey else { return }
        currentKey = key
        task?.cancel()
        if let cached = cache[key] {
            lyrics = cached
            return
        }
        lyrics = nil
        task = Task { [weak self] in
            let result = await Self.fetch(title: title, artist: artist, duration: duration)
            guard !Task.isCancelled, let self, self.currentKey == key else { return }
            self.cache[key] = result
            self.lyrics = result
        }
    }

    private static func fetch(title: String, artist: String, duration: TimeInterval) async -> SyncedLyrics? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ] + (duration > 0 ? [URLQueryItem(name: "duration", value: String(Int(duration.rounded())))] : [])
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        // LRCLIB asks clients to identify themselves.
        request.setValue("PepBox (https://github.com/KPScriptz/PepBox)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let synced = json["syncedLyrics"] as? String, !synced.isEmpty else { return nil }
        let lyrics = SyncedLyrics(lrc: synced)
        return lyrics.lines.isEmpty ? nil : lyrics
    }
}
