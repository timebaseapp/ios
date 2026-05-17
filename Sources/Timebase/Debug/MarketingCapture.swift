// DEBUG-only marketing screenshot capture system. Launched with
// `-MarketingCapture 1`. Walks a deterministic step list to put the app
// into known states, snapshots the key window after each navigation, and
// also renders the widget views via ImageRenderer as transparent PNGs.
//
// Output lands in `Documents/marketing/<locale>/` inside the app sandbox.
// `scripts/capture-marketing.sh` pulls those files out via
// `simctl get_app_container`.

#if DEBUG
import SwiftUI
import UIKit
import WidgetKit
import EventKit

// MARK: - Core

enum MarketingCapture {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-MarketingCapture") &&
        value(for: "-MarketingCapture") == "1"
    }

    static var appearanceFolder: String {
        value(for: "-MarketingAppearance") ?? "light"
    }

    private static func value(for key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: key), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    static var outputRoot: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs
            .appendingPathComponent("marketing", isDirectory: true)
            .appendingPathComponent(appearanceFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func writePNG(_ image: UIImage, name: String, subfolder: String? = nil) {
        var dir = outputRoot
        if let subfolder {
            dir = dir.appendingPathComponent(subfolder, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appendingPathComponent("\(name).png")
        guard let data = image.pngData() else {
            print("[MarketingCapture] failed to encode \(name)")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            print("[MarketingCapture] wrote \(url.path)")
        } catch {
            print("[MarketingCapture] write failed: \(error)")
        }
    }

    static func writeSentinel() {
        let url = outputRoot.appendingPathComponent("_done")
        try? Data().write(to: url)
    }

    @MainActor
    static func snapshotKeyWindow() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return nil }
        // `drawHierarchy(afterScreenUpdates: true)` sometimes fails to
        // include SF Symbols and other system-font glyphs in its offscreen
        // pass; `layer.render(in:)` captures the actual Core Animation
        // layer state, which includes those glyphs reliably.
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        return renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
    }

    /// Bound to a SwiftUI state in TimebaseApp so we can force-present the
    /// detail sheet during capture without going through the full tap path.
    nonisolated(unsafe) static var pendingDetailCityId: String?
    /// When set true, the world-clock screen disables motion-driven parallax
    /// so the gradient renders identically every shot.
    nonisolated(unsafe) static var freezeMotion: Bool = false
    /// Pre-populates SchedulerSheet with these participants when the sheet
    /// is presented during marketing capture.
    nonisolated(unsafe) static var pendingSchedulerCityIds: [String]?
    /// Sets the meeting time when SchedulerSheet appears in marketing mode.
    nonisolated(unsafe) static var pendingSchedulerMeetingTime: Date?
    /// Sets the meeting title (so the Continue button is enabled and the
    /// screenshot doesn't show an empty title field).
    nonisolated(unsafe) static var pendingSchedulerTitle: String?
}

// MARK: - Step coordinator

struct CaptureStep {
    let name: String
    let navigate: @MainActor () -> Void
    let settle: Duration
    let cleanup: (@MainActor () -> Void)?

    init(name: String,
         settle: Duration = .milliseconds(1800),
         navigate: @escaping @MainActor () -> Void,
         cleanup: (@MainActor () -> Void)? = nil)
    {
        self.name = name
        self.settle = settle
        self.navigate = navigate
        self.cleanup = cleanup
    }
}

@MainActor
final class MarketingCaptureCoordinator {
    static let shared = MarketingCaptureCoordinator()
    private init() {}

    func run(steps: [CaptureStep], elements: @MainActor () -> Void) async {
        print("[MarketingCapture] starting appearance=\(MarketingCapture.appearanceFolder)")
        for step in steps {
            step.navigate()
            try? await Task.sleep(for: step.settle)
            if let image = MarketingCapture.snapshotKeyWindow() {
                MarketingCapture.writePNG(image, name: step.name)
            } else {
                print("[MarketingCapture] snapshot failed: \(step.name)")
            }
            step.cleanup?()
            try? await Task.sleep(for: .milliseconds(900))
        }
        elements()
        MarketingCapture.writeSentinel()
        print("[MarketingCapture] done.")
    }
}

// MARK: - Steps for Timebase

@MainActor
enum TimebaseCaptureSteps {
    static func make(store: TimebaseStore) -> [CaptureStep] {
        [
            // 1. World Clock — full city list, no scrub, motion frozen.
            CaptureStep(name: "01-world-clock") {
                MarketingCapture.freezeMotion = true
                store.scrubOffsetMinutes = 0
                store.currentTab = .clock
            },

            // 2. Up Next — fake calendar events visible.
            CaptureStep(name: "02-up-next") {
                store.currentTab = .upNextAbout
            },

            // 3. Scheduler — pendingShowScheduler trips the sheet inside
            //    UpNextScreen. We pre-populate participants + meeting time
            //    so the shot shows the populated state, not the empty one.
            CaptureStep(name: "03-scheduler",
                        settle: .milliseconds(2200)) {
                store.currentTab = .upNextAbout
                let names = ["San Francisco", "New York", "London", "Bengaluru", "Tokyo"]
                let ids = names.compactMap { name in
                    store.cities.first(where: { $0.name == name })?.id
                }
                MarketingCapture.pendingSchedulerCityIds = ids
                MarketingCapture.pendingSchedulerTitle = "Q3 launch sync"
                // Today at 10:00 AM home tz — the result block then shows
                // home @ 10am (working), London @ 6pm (winding down),
                // Bengaluru @ 10:30pm (sleeping), Tokyo @ 2am next day.
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = store.homeCity?.timeZoneObject ?? .current
                var comps = cal.dateComponents([.year, .month, .day], from: .now)
                comps.hour = 10; comps.minute = 0
                MarketingCapture.pendingSchedulerMeetingTime = cal.date(from: comps) ?? .now
                store.pendingShowScheduler = true
            } cleanup: {
                store.pendingShowScheduler = false
                MarketingCapture.pendingSchedulerCityIds = nil
                MarketingCapture.pendingSchedulerTitle = nil
                MarketingCapture.pendingSchedulerMeetingTime = nil
                NotificationCenter.default.post(name: .mcDismissSheet, object: nil)
            },

            // 4. City detail sheet (Tokyo, mid-evening).
            CaptureStep(name: "04-city-detail",
                        settle: .milliseconds(2200)) {
                store.currentTab = .clock
                if let tokyo = store.cities.first(where: { $0.name == "Tokyo" }) {
                    MarketingCapture.pendingDetailCityId = tokyo.id
                }
            } cleanup: {
                MarketingCapture.pendingDetailCityId = nil
                NotificationCenter.default.post(name: .mcDismissSheet, object: nil)
            }
        ]
    }
}

extension Notification.Name {
    static let mcDismissSheet = Notification.Name("MarketingCapture.dismissSheet")
}

// MARK: - Widget element renders

@MainActor
enum MarketingElementHarness {
    static func renderAllWidgets() {
        let persisted = persistedSnapshotFromStore()
        let events = mockWidgetEvents()
        let date = Date()

        // World Clock — small / medium / large
        render(name: "widget-worldclock-small", size: CGSize(width: 170, height: 170)) {
            WidgetWorldClockSmallPreview(persisted: persisted, date: date)
        }
        render(name: "widget-worldclock-medium", size: CGSize(width: 364, height: 170)) {
            WidgetWorldClockMediumPreview(persisted: persisted, date: date)
        }
        render(name: "widget-worldclock-large", size: CGSize(width: 364, height: 382)) {
            WidgetWorldClockLargePreview(persisted: persisted, date: date)
        }

        // Up Next — small / medium / large
        render(name: "widget-upnext-small", size: CGSize(width: 170, height: 170)) {
            WidgetCountdownSmallPreview(events: events)
        }
        render(name: "widget-upnext-medium", size: CGSize(width: 364, height: 170)) {
            WidgetCountdownMediumPreview(events: events)
        }
        render(name: "widget-upnext-large", size: CGSize(width: 364, height: 382)) {
            WidgetCountdownLargePreview(events: events)
        }
    }

    private static func render<V: View>(name: String, size: CGSize, @ViewBuilder content: () -> V) {
        let view = content()
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = false
        if let img = renderer.uiImage {
            MarketingCapture.writePNG(img, name: name, subfolder: "widgets")
        }
    }

    private static func persistedSnapshotFromStore() -> WidgetPersistedSnapshot {
        // The widget views live in TimebaseWidgets — they read from the
        // App Group. Build an equivalent local snapshot from the seeded
        // store so the previews render identically.
        let cities = TimebaseStore.marketingCitySeed.map { name, country, tz, lat, lon in
            WidgetPersistedSnapshot.City(name: name, country: country, tz: tz, lat: lat, lon: lon)
        }
        return WidgetPersistedSnapshot(cities: cities, homeCityId: "San Francisco|America/Los_Angeles")
    }

    private static func mockWidgetEvents() -> [WidgetPersistedSnapshot.Event] {
        let now = Date()
        return [
            .init(title: "Standup with London",
                  startDate: now.addingTimeInterval(11 * 60),
                  endDate: now.addingTimeInterval(40 * 60),
                  tz: "Europe/London"),
            .init(title: "Design review",
                  startDate: now.addingTimeInterval(2 * 3600),
                  endDate: now.addingTimeInterval(3 * 3600),
                  tz: TimeZone.current.identifier),
            .init(title: "Dinner — Saakshi",
                  startDate: now.addingTimeInterval(7 * 3600),
                  endDate: now.addingTimeInterval(9 * 3600),
                  tz: TimeZone.current.identifier)
        ]
    }
}

/// In-app mirror of the App Group widget persistence shape, so the
/// preview-only widget renderers can run without touching UserDefaults.
struct WidgetPersistedSnapshot {
    struct City: Identifiable, Hashable {
        let name: String
        let country: String
        let tz: String
        let lat: Double
        let lon: Double
        var id: String { "\(name)|\(tz)" }
        var timeZone: TimeZone { TimeZone(identifier: tz) ?? .current }
    }
    struct Event: Identifiable, Hashable {
        let id = UUID().uuidString
        let title: String
        let startDate: Date
        let endDate: Date
        let tz: String
        var timeZone: TimeZone { TimeZone(identifier: tz) ?? .current }
    }
    let cities: [City]
    let homeCityId: String?
}

// MARK: - In-app widget previews (mirror the real widget views)

private struct WidgetWorldClockSmallPreview: View {
    let persisted: WidgetPersistedSnapshot
    let date: Date

    var body: some View {
        let city = persisted.cities.first(where: { $0.id == persisted.homeCityId }) ?? persisted.cities.first
        let h = fractionalHour(date: date, tz: city?.timeZone ?? .current)
        let grad = TimeColor.backgroundGradient(forHour: h, scheme: .light, scrubMute: 0)
        let fg = TimeColor.foreground(forHour: h, scheme: .light)
        ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(city?.name ?? "—").font(.system(size: 13))
                Spacer()
                Text(formattedTime(date: date, tz: city?.timeZone ?? .current))
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(fg)
        }
    }
}

private struct WidgetWorldClockMediumPreview: View {
    let persisted: WidgetPersistedSnapshot
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedCities().prefix(3)), id: \.id) { city in
                row(city: city)
            }
        }
    }

    private func row(city: WidgetPersistedSnapshot.City) -> some View {
        let h = fractionalHour(date: date, tz: city.timeZone)
        let grad = TimeColor.backgroundGradient(forHour: h, scheme: .light, scrubMute: 0)
        let fg = TimeColor.foreground(forHour: h, scheme: .light)
        return ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            HStack {
                Text(city.name).font(.system(size: 14))
                Spacer()
                Text(formattedTime(date: date, tz: city.timeZone))
                    .font(.system(size: 18, weight: .heavy)).monospacedDigit()
            }
            .padding(.horizontal, 14)
            .foregroundStyle(fg)
        }
        .frame(maxHeight: .infinity)
    }

    private func orderedCities() -> [WidgetPersistedSnapshot.City] {
        persisted.cities.sorted {
            $0.timeZone.secondsFromGMT() < $1.timeZone.secondsFromGMT()
        }
    }
}

private struct WidgetWorldClockLargePreview: View {
    let persisted: WidgetPersistedSnapshot
    let date: Date
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedCities().prefix(5)), id: \.id) { city in
                row(city: city)
            }
        }
    }
    private func row(city: WidgetPersistedSnapshot.City) -> some View {
        let h = fractionalHour(date: date, tz: city.timeZone)
        let grad = TimeColor.backgroundGradient(forHour: h, scheme: .light, scrubMute: 0)
        let fg = TimeColor.foreground(forHour: h, scheme: .light)
        return ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            HStack {
                Text(city.name).font(.system(size: 15))
                Spacer()
                Text(formattedTime(date: date, tz: city.timeZone))
                    .font(.system(size: 19, weight: .heavy)).monospacedDigit()
            }
            .padding(.horizontal, 14)
            .foregroundStyle(fg)
        }
        .frame(maxHeight: .infinity)
    }
    private func orderedCities() -> [WidgetPersistedSnapshot.City] {
        persisted.cities.sorted {
            $0.timeZone.secondsFromGMT() < $1.timeZone.secondsFromGMT()
        }
    }
}

private struct WidgetCountdownSmallPreview: View {
    let events: [WidgetPersistedSnapshot.Event]
    var body: some View {
        let event = events.first!
        let h = fractionalHour(date: event.startDate, tz: event.timeZone)
        let grad = TimeColor.backgroundGradient(forHour: h, scheme: .light, scrubMute: 0)
        ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text("UP NEXT")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
                Text(event.title).font(.system(size: 13))
                    .foregroundStyle(.white).lineLimit(2)
                Spacer()
                Text(timerInterval: Date()...event.startDate, countsDown: true)
                    .font(.system(size: 26, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct WidgetCountdownMediumPreview: View {
    let events: [WidgetPersistedSnapshot.Event]
    var body: some View {
        let primary = events.first!
        let h = fractionalHour(date: primary.startDate, tz: primary.timeZone)
        let grad = TimeColor.backgroundGradient(forHour: h, scheme: .light, scrubMute: 0)
        ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(events.prefix(3))) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.system(size: 14))
                                .foregroundStyle(.white).lineLimit(1)
                        }
                        Spacer()
                        Text(timerInterval: Date()...max(event.startDate, Date().addingTimeInterval(1)),
                             countsDown: true)
                            .font(.system(size: 14, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct WidgetCountdownLargePreview: View {
    let events: [WidgetPersistedSnapshot.Event]
    var body: some View {
        let primary = events.first!
        let h = fractionalHour(date: primary.startDate, tz: primary.timeZone)
        let grad = TimeColor.backgroundGradient(forHour: h, scheme: .light, scrubMute: 0)
        ZStack {
            LinearGradient(colors: grad, startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(events.prefix(6))) { event in
                    HStack {
                        Text(event.title).font(.system(size: 15))
                            .foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        Text(timerInterval: Date()...max(event.startDate, Date().addingTimeInterval(1)),
                             countsDown: true)
                            .font(.system(size: 16, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Helpers

private func fractionalHour(date: Date, tz: TimeZone) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let c = cal.dateComponents([.hour, .minute], from: date)
    return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60.0
}

private func formattedTime(date: Date, tz: TimeZone) -> String {
    var fmt = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
    fmt.timeZone = tz
    return fmt.format(date)
}

#endif
