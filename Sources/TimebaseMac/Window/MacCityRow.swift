import SwiftUI

/// One row of the macOS world clock — full-window-width gradient band with
/// the city name, 🏠 marker if home, the time large and tabular-numeral, and
/// the delta from home in Departure Mono. Mac-grown from the iOS row — taller
/// (the window is taller than a phone), the time set larger, more breathing
/// room. Tapping pushes its detail.
struct MacCityRow: View {
    let city: City

    @Environment(TimebaseMacStore.self) private var store

    var body: some View {
        let date = store.displayDate
        let hour = ClockMath.fractionalHour(in: city.timeZoneObject, date: date)
        let scrubMute: Double = store.scrubOffsetMinutes == 0 ? 0 : 0.5
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark,
                                                  scrubMute: scrubMute)
        let fg = Palette.foreground(forHour: hour, scheme: .dark)
        let isHome = city.id == store.homeCityId

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(displayName(isHome: isHome))
                .font(.system(size: 22, weight: .regular))
                .kerning(-0.2)
                .lineLimit(1)
            Spacer(minLength: 12)
            if let chip = dayOffsetChip {
                Text(chip)
                    .font(Brand.mono(11))
                    .tracking(0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(fg.opacity(0.5), lineWidth: 0.5)
                    )
                    .opacity(0.7)
            }
            Text(ClockMath.timeString(date: date, tz: city.timeZoneObject,
                                      pref: store.settings.hourPreference))
                .font(.system(size: 30, weight: .heavy))
                .monospacedDigit()
                .kerning(-0.5)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 0.5)
        }
        .clipped()
    }

    /// 🏠 as a name suffix so all city names share the same left edge —
    /// the same iOS pattern (`CityRow`).
    private func displayName(isHome: Bool) -> String {
        isHome ? "\(city.name)  🏠" : city.name
    }

    /// `+1d` / `-1d` when the city's calendar day differs from home.
    private var dayOffsetChip: String? {
        guard let home = store.homeCity else { return nil }
        let days = ClockMath.dayOffset(cityTZ: city.timeZoneObject,
                                       homeTZ: home.timeZoneObject,
                                       date: store.displayDate)
        guard days != 0 else { return nil }
        return days > 0 ? "+\(days)d" : "\(days)d"
    }
}
