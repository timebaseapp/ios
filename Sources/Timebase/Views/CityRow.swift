import SwiftUI

struct CityRow: View {
    let city: City
    var rowCount: Int = 5
    var topContentInset: CGFloat = 0
    var bottomContentInset: CGFloat = 0
    @Environment(TimebaseStore.self) private var store
    @Environment(MotionStore.self) private var motion
    @EnvironmentObject private var weather: WeatherStore
    @Environment(\.colorScheme) private var colorScheme

    private var isHome: Bool { city.id == store.homeCityId }

    private var nameFontSize: CGFloat {
        switch rowCount {
        case ...5: return 22
        case 6...7: return 20
        default:   return 18
        }
    }
    private var timeFontSize: CGFloat {
        switch rowCount {
        case ...5: return 28
        case 6...7: return 25
        default:   return 22
        }
    }
    private var chipFontSize: CGFloat {
        switch rowCount {
        case ...5: return 13
        case 6...7: return 12
        default:   return 11
        }
    }

    var body: some View {
        let displayDate = store.displayDate
        let hour = fractionalHour(in: city.timeZoneObject, date: displayDate)
        let scrubMute: Double = store.scrubOffsetMinutes == 0 ? 0 : 0.5
        let gradient = TimeColor.backgroundGradient(forHour: hour, scheme: colorScheme, scrubMute: scrubMute)
        let fg = TimeColor.foreground(forHour: hour, scheme: colorScheme)

        VStack(spacing: 0) {
            if topContentInset > 0 {
                Color.clear.frame(height: topContentInset)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(city.name)
                    .font(.system(size: nameFontSize, weight: .regular))
                    .kerning(-0.1)
                if isHome {
                    // Filled circle as home marker — always rasterizes
                    // identically in capture + on-device renders, no font
                    // fallback risk.
                    Circle()
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: nameFontSize * 0.28, height: nameFontSize * 0.28)
                        .padding(.leading, -4)
                }
                Spacer(minLength: 8)
                timeAndDay(in: city.timeZoneObject, date: displayDate)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if bottomContentInset > 0 {
                Color.clear.frame(height: bottomContentInset)
            }
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // Parallax: gradient endpoints shift slightly with device
                // tilt so the colors feel fluid as you move the phone.
                LinearGradient(
                    colors: gradient,
                    startPoint: UnitPoint(x: 0.5 + motion.roll * 0.18,
                                          y: 0.0 + motion.pitch * 0.10),
                    endPoint:   UnitPoint(x: 0.5 - motion.roll * 0.18,
                                          y: 1.0 - motion.pitch * 0.10)
                )
                if let w = weather.snapshot(for: city) {
                    WeatherEffectOverlay(condition: w.condition, tint: fg)
                }
                Image("grain")
                    .resizable(resizingMode: .tile)
                    .blendMode(.softLight)
                    .opacity(0.95)
                    .allowsHitTesting(false)
                Image("grain")
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.35)
                    .allowsHitTesting(false)
            }
            .clipped()
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.primary.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func timeAndDay(in tz: TimeZone, date: Date) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(formattedTime(date: date, tz: tz))
                .font(.system(size: timeFontSize, weight: .heavy))
                .monospacedDigit()
                .kerning(-0.5)
            if let dayOffset = dayOffsetChip(tz: tz, date: date) {
                Text(dayOffset)
                    .font(.system(size: chipFontSize, weight: .regular))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.primary.opacity(0.5), lineWidth: 0.5)
                    )
                    .opacity(0.7)
            }
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

    private func dayOffsetChip(tz: TimeZone, date: Date) -> String? {
        guard let home = store.homeCity else { return nil }
        var homeCal = Calendar(identifier: .gregorian); homeCal.timeZone = home.timeZoneObject
        var cityCal = Calendar(identifier: .gregorian); cityCal.timeZone = tz
        let homeStart = homeCal.startOfDay(for: date)
        let cityStart = cityCal.startOfDay(for: date)
        // Translate each midnight back to a Y/M/D triple. Compare those.
        let homeYMD = homeCal.dateComponents([.year, .month, .day], from: homeStart)
        let cityYMD = cityCal.dateComponents([.year, .month, .day], from: cityStart)
        // Use a UTC calendar to compute the day delta between the two Y/M/D dates.
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        guard let homeAbs = utc.date(from: homeYMD),
              let cityAbs = utc.date(from: cityYMD) else { return nil }
        let days = Int(((cityAbs.timeIntervalSince(homeAbs)) / 86400).rounded())
        guard days != 0 else { return nil }
        let sign = days > 0 ? "+" : ""
        return "\(sign)\(days)d"
    }
}

private func fractionalHour(in tz: TimeZone, date: Date) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let comps = cal.dateComponents([.hour, .minute, .second], from: date)
    let h = Double(comps.hour ?? 0)
    let m = Double(comps.minute ?? 0)
    let s = Double(comps.second ?? 0)
    return h + m/60 + s/3600
}
