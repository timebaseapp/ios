import SwiftUI

/// City detail — the full-bleed gradient panel with the city name, the time
/// large, the timezone offset, delta from home, distance from home. v1
/// minimal; the day-bar with sunrise/sunset lands in a later slice along
/// with the matrix view.
struct CityDetailPopover: View {
    let city: City

    @Environment(TimebaseMacStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let date = store.displayDate
        let tz = city.timeZoneObject
        let hour = ClockMath.fractionalHour(in: tz, date: date)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark)
        let fg = Palette.foreground(forHour: hour, scheme: .dark)

        ZStack {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .font(.system(size: 30, weight: .regular))
                        .kerning(-0.3)
                    Text(city.country)
                        .font(.system(size: 13))
                        .opacity(0.65)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(ClockMath.timeString(date: date, tz: tz,
                                              pref: store.settings.hourPreference))
                        .font(.system(size: 52, weight: .heavy))
                        .monospacedDigit()
                        .kerning(-1)
                    Text(offsetLabel(tz: tz, date: date))
                        .font(.system(size: 12))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .opacity(0.65)
                }

                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: 14) {
                    factRow("From home", fromHomeText)
                    factRow("Distance", distanceText)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(fg)
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onReceive(timer) { tick = $0 }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(Brand.mono(10))
                .tracking(1.2)
                .opacity(0.55)
            Text(value)
                .font(.system(size: 17))
        }
    }

    private func offsetLabel(tz: TimeZone, date: Date) -> String {
        let abbr = tz.abbreviation(for: date) ?? ""
        let secs = tz.secondsFromGMT(for: date)
        let sign = secs >= 0 ? "+" : "−"
        let h = abs(secs) / 3600
        let m = (abs(secs) % 3600) / 60
        let off = m == 0 ? "UTC\(sign)\(h)" : "UTC\(sign)\(h):" + String(format: "%02d", m)
        return abbr.isEmpty ? off : "\(abbr)  ·  \(off)"
    }

    private var fromHomeText: String {
        guard let home = store.homeCity, home.id != city.id else { return "This is home" }
        let label = store.deltaLabel(for: city)
        return "\(label) from \(home.name)"
    }

    private var distanceText: String {
        guard let home = store.homeCity, home.id != city.id else { return "—" }
        let km = haversineKm(lat1: home.latitude, lon1: home.longitude,
                             lat2: city.latitude, lon2: city.longitude)
        return "\(Int(km.rounded()).formatted(.number)) km"
    }
}

/// Great-circle distance in kilometers.
private func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371.0
    let toRad = { (d: Double) in d * .pi / 180 }
    let dLat = toRad(lat2 - lat1)
    let dLon = toRad(lon2 - lon1)
    let a = sin(dLat/2) * sin(dLat/2)
        + cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon/2) * sin(dLon/2)
    return R * 2 * asin(sqrt(a))
}
