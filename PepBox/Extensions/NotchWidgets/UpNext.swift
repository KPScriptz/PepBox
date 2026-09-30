//
//  UpNext.swift
//  PepBox
//
//  Weather and your next calendar events in the shelf, and a live activity
//  when a meeting is about to start. Weather is Open-Meteo (free, no key) for
//  a city you type once, so no location permission is needed.
//

import SwiftUI
import EventKit
import AppKit

// MARK: - Calendar

struct UpcomingEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let color: Color
    let joinURL: URL?
}

@Observable
final class UpNextCalendar {
    static let shared = UpNextCalendar()

    private let store = EKEventStore()
    private(set) var events: [UpcomingEvent] = []
    private(set) var authorized = false
    /// Ticks every 30 s so countdowns (and the live activity) stay current.
    private(set) var now = Date()
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    private init() {
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.reload()
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.now = Date()
            if Int(Date().timeIntervalSince1970) % 300 < 30 { self?.reload() }  // refresh every ~5 min
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        reload()
    }

    func requestAccess() {
        Task { @MainActor in
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            authorized = granted
            if granted { reload() }
        }
    }

    func reload() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            authorized = false
            events = []
            return
        }
        authorized = true
        now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: now.addingTimeInterval(24 * 3600), calendars: nil)
        events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
            .map { event in
                UpcomingEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Event",
                    start: event.startDate,
                    end: event.endDate,
                    color: Color(nsColor: event.calendar.color ?? .systemBlue),
                    joinURL: Self.meetingURL(in: event)
                )
            }
    }

    /// First Zoom / Meet / Teams / Webex link in the event's URL, location or notes.
    static func meetingURL(in event: EKEvent) -> URL? {
        let texts = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }
        let pattern = #"https://[^\s<>"]*(zoom\.us/j|meet\.google\.com/|teams\.microsoft\.com/l/meetup-join|webex\.com/)[^\s<>"]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        for text in texts {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range), let r = Range(match.range, in: text) {
                return URL(string: String(text[r]))
            }
        }
        return nil
    }

    /// The event starting within 10 minutes (or in progress for its first 5), for the live activity.
    var imminentEvent: UpcomingEvent? {
        events.first { event in
            let untilStart = event.start.timeIntervalSince(now)
            return untilStart <= 600 && untilStart > -300
        }
    }

    static func relative(_ date: Date, from now: Date) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes)m" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Weather

@Observable
final class UpNextWeather {
    static let shared = UpNextWeather()

    struct Current: Equatable {
        let temperature: Double
        let high: Double
        let low: Double
        let code: Int
        /// The next few hours: (hour start, temperature, weather code).
        var hourly: [Hour] = []
    }

    struct Hour: Equatable {
        let time: Date
        let temperature: Double
        let code: Int
    }

    private enum Keys {
        static let city = "upNext_city"
        static let latitude = "upNext_latitude"
        static let longitude = "upNext_longitude"
    }

    private(set) var city: String? = UserDefaults.standard.string(forKey: Keys.city)
    private(set) var current: Current?
    private(set) var message: String?
    private var lastFetch: Date?

    var usesFahrenheit: Bool { Locale.current.measurementSystem == .us }

    /// Looks the city up with Open-Meteo's geocoder and remembers it.
    func setCity(_ name: String) {
        let query = name.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        message = "Looking up \(query)…"
        Task { @MainActor in
            var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
            components?.queryItems = [URLQueryItem(name: "name", value: query), URLQueryItem(name: "count", value: "1")]
            guard let url = components?.url,
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let first = (json["results"] as? [[String: Any]])?.first,
                  let latitude = first["latitude"] as? Double,
                  let longitude = first["longitude"] as? Double else {
                message = "Couldn't find \(query)"
                return
            }
            let name = first["name"] as? String ?? query
            UserDefaults.standard.set(name, forKey: Keys.city)
            UserDefaults.standard.set(latitude, forKey: Keys.latitude)
            UserDefaults.standard.set(longitude, forKey: Keys.longitude)
            city = name
            message = nil
            lastFetch = nil
            refresh()
        }
    }

    func clearCity() {
        [Keys.city, Keys.latitude, Keys.longitude].forEach(UserDefaults.standard.removeObject(forKey:))
        city = nil
        current = nil
    }

    /// Fetches the forecast at most every 15 minutes.
    func refresh() {
        guard city != nil, lastFetch.map({ Date().timeIntervalSince($0) > 900 }) ?? true else { return }
        let defaults = UserDefaults.standard
        let latitude = defaults.double(forKey: Keys.latitude), longitude = defaults.double(forKey: Keys.longitude)
        lastFetch = Date()
        Task { @MainActor in
            var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
            components?.queryItems = [
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
                URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
                URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
                URLQueryItem(name: "forecast_hours", value: "7"),
                URLQueryItem(name: "timeformat", value: "unixtime"),
                URLQueryItem(name: "forecast_days", value: "1"),
                URLQueryItem(name: "timezone", value: "auto"),
                URLQueryItem(name: "temperature_unit", value: usesFahrenheit ? "fahrenheit" : "celsius")
            ]
            guard let url = components?.url,
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let now = json["current"] as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let temperature = now["temperature_2m"] as? Double,
                  let code = now["weather_code"] as? Int,
                  let high = (daily["temperature_2m_max"] as? [Double])?.first,
                  let low = (daily["temperature_2m_min"] as? [Double])?.first else {
                lastFetch = nil
                return
            }
            var hours: [Hour] = []
            if let hourly = json["hourly"] as? [String: Any],
               let times = hourly["time"] as? [Double],
               let temps = hourly["temperature_2m"] as? [Double],
               let codes = hourly["weather_code"] as? [Int] {
                hours = zip(times, zip(temps, codes))
                    .map { Hour(time: Date(timeIntervalSince1970: $0), temperature: $1.0, code: $1.1) }
                    .filter { $0.time > Date() }
            }
            current = Current(temperature: temperature, high: high, low: low, code: code, hourly: Array(hours.prefix(5)))
        }
    }

    /// WMO weather code → SF Symbol.
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Panel

struct UpNextNotchView: View {
    var calendar: UpNextCalendar
    var weather: UpNextWeather
    @State private var cityInput = ""

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            weatherColumn
                .frame(width: 110, alignment: .leading)
            eventsColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            calendar.reload()
            weather.refresh()
        }
    }

    @ViewBuilder
    private var weatherColumn: some View {
        if weather.city == nil {
            VStack(alignment: .leading, spacing: 6) {
                Text("Weather")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                TextField("Your city", text: $cityInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.1)))
                    .onSubmit { weather.setCity(cityInput) }
                if let message = weather.message {
                    Text(message).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                }
            }
        } else if let now = weather.current {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: UpNextWeather.symbol(for: now.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 22))
                    Text("\(Int(now.temperature.rounded()))°")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("H \(Int(now.high.rounded()))°  L \(Int(now.low.rounded()))°")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Text(weather.city ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .contextMenu { Button("Change City") { weather.clearCity() } }
            }
        } else {
            ProgressView().controlSize(.small)
        }
    }

    @ViewBuilder
    private var eventsColumn: some View {
        if !calendar.authorized {
            VStack(alignment: .leading, spacing: 6) {
                Text("See your next meetings here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Button("Allow Calendar Access") { calendar.requestAccess() }
                    .controlSize(.small)
            }
        } else if calendar.events.isEmpty {
            Text("Nothing else today")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(calendar.events.prefix(3)) { event in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(event.color)
                            .frame(width: 3, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(UpNextCalendar.relative(event.start, from: calendar.now))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer(minLength: 4)
                        if let url = event.joinURL {
                            Button { NSWorkspace.shared.open(url) } label: {
                                Text("Join")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(.green))
                            }
                            .buttonStyle(.plain)
                            .help(url.host ?? "Join")
                        }
                    }
                }
            }
        }
    }
}
