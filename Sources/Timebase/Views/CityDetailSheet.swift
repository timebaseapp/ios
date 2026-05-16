import SwiftUI
import WeatherKit

struct CityDetailSheet: View {
    let city: City
    @Environment(TimebaseStore.self) private var store
    @EnvironmentObject private var weather: WeatherStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let date = store.displayDate
        let tz = city.timeZoneObject

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .font(.system(size: 28, weight: .regular))
                    Text(city.country)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedTime(date: date, tz: tz))
                        .font(.system(size: 48, weight: .heavy))
                        .monospacedDigit()
                        .kerning(-1)
                    Text(timezoneLabel(date: date, tz: tz))
                        .font(.system(size: 13))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }

                DayBarView(tz: tz, latitude: city.latitude, longitude: city.longitude)

                if let current = weather.snapshot(for: city) {
                    weatherRow(current)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    factRow(label: "From home", value: homeDeltaText)
                    factRow(label: "Distance", value: distanceText)
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    if city.id != store.homeCityId {
                        Button("Make home") {
                            store.makeHome(cityId: city.id)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                    if city.id != store.homeCityId {
                        Button("Remove", role: .destructive) {
                            store.remove(cityId: city.id)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(24)
        }
        .task(id: city.id) {
            await weather.refresh(for: city)
        }
    }

    @ViewBuilder
    private func weatherRow(_ current: CurrentWeather) -> some View {
        HStack(spacing: 12) {
            Image(systemName: current.symbolName)
                .font(.system(size: 28, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTemperature(current.temperature))
                    .font(.system(size: 17, weight: .regular))
                    .monospacedDigit()
                Text(current.condition.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formattedTemperature(_ m: Measurement<UnitTemperature>) -> String {
        let f = MeasurementFormatter()
        f.unitOptions = [.temperatureWithoutUnit]
        f.numberFormatter.maximumFractionDigits = 0
        return f.string(from: m)
    }

    private func factRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17))
        }
    }

    private func formattedTime(date: Date, tz: TimeZone) -> String {
        var fmt = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
        if let is24 = store.settings.hourPreference.is24Hour {
            fmt = is24
                ? Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
                : Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
        }
        fmt.timeZone = tz
        return fmt.format(date)
    }

    private func timezoneLabel(date: Date, tz: TimeZone) -> String {
        let abbr = tz.abbreviation(for: date) ?? ""
        let offsetSec = tz.secondsFromGMT(for: date)
        let sign = offsetSec >= 0 ? "+" : "−"
        let h = Swift.abs(offsetSec) / 3600
        let m = (Swift.abs(offsetSec) % 3600) / 60
        let off = m == 0 ? "UTC\(sign)\(h)" : "UTC\(sign)\(h):\(String(format: "%02d", m))"
        return abbr.isEmpty ? off : "\(abbr)  ·  \(off)"
    }

    private var homeDeltaText: String {
        guard let home = store.homeCity, home.id != city.id else { return "This is home" }
        let homeTZ = home.timeZoneObject
        let cityTZ = city.timeZoneObject
        let date = store.displayDate
        let homeOff = homeTZ.secondsFromGMT(for: date)
        let cityOff = cityTZ.secondsFromGMT(for: date)
        let diffHours = Double(cityOff - homeOff) / 3600
        let sign = diffHours >= 0 ? "+" : "−"
        let abs = Swift.abs(diffHours)
        let whole = Int(abs)
        let frac = abs - Double(whole)
        var fracStr = ""
        if abs >= 0.05 && Swift.abs(frac - 0.5) < 0.05 { fracStr = "½" }
        else if abs >= 0.05 && (Swift.abs(frac - 0.25) < 0.05 || Swift.abs(frac - 0.75) < 0.05) { fracStr = "¾" }
        return "\(sign)\(whole)\(fracStr) hours from \(home.name)"
    }

    private var distanceText: String {
        guard let home = store.homeCity, home.id != city.id else { return "—" }
        let km = haversine(lat1: home.latitude, lon1: home.longitude, lat2: city.latitude, lon2: city.longitude)
        let formatted = Int(km.rounded()).formatted(.number)
        return "\(formatted) km"
    }
}

func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371.0
    let toRad = { (d: Double) in d * .pi / 180 }
    let dLat = toRad(lat2 - lat1)
    let dLon = toRad(lon2 - lon1)
    let a = sin(dLat/2) * sin(dLat/2) +
            cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon/2) * sin(dLon/2)
    return R * 2 * asin(sqrt(a))
}

struct DayBarView: View {
    let tz: TimeZone
    let latitude: Double
    let longitude: Double
    @Environment(TimebaseStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let now = nowFractionalHour
            ZStack(alignment: .leading) {
                // 24h gradient
                LinearGradient(
                    colors: dayGradientColors,
                    startPoint: .leading, endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Circle()
                    .fill(.primary)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: CGFloat(now / 24) * width - 4)
            }
        }
        .frame(height: 16)
    }

    private var nowFractionalHour: Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.hour, .minute], from: store.displayDate)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    private var dayGradientColors: [Color] {
        (0...24).map { i in
            Color(TimeColor.background(forHour: Double(i), scheme: colorScheme).cgColor!)
        }
    }
}
