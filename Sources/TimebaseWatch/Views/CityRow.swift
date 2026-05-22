import SwiftUI

/// One city as a full-bleed gradient band — edge to edge, no card chrome,
/// no rounded corners. Every band is given an identical explicit height by
/// the parent, so the screen divides into equal stripes. The name is in the
/// system font (matching iOS); home is marked by a small dot in a slot
/// reserved on every row, so it never compresses a city name; no
/// time-of-day emoji — the gradient already says what hour it is.
struct CityRow: View {
    let city: City
    /// The exact band height — identical for every row, so bands are equal.
    var bandHeight: CGFloat
    /// Nudges the text down within the fixed band so the first row clears
    /// the system clock. Does not change the band height.
    var topInset: CGFloat = 0
    /// Likewise lifts the last row's text off the bottom curve.
    var bottomInset: CGFloat = 0

    @Environment(TimebaseWatchStore.self) private var store
    @Environment(\.isLuminanceReduced) private var aod

    var body: some View {
        let date = store.displayDate
        let hour = ClockMath.fractionalHour(in: city.timeZoneObject, date: date)
        let scrubMute: Double = store.scrubOffsetMinutes == 0 ? 0 : 0.5
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark,
                                                  scrubMute: scrubMute, aod: aod)
        let fg = Palette.foreground(forHour: hour, scheme: .dark, aod: aod)
        let isHome = city.id == store.homeCityId

        ZStack {
            LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)

            VStack(spacing: 0) {
                if topInset > 0 { Color.clear.frame(height: topInset) }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(city.name)
                        .font(.system(size: 16, weight: .regular))
                        .kerning(-0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    // Home marker: the brand 🏠, small, just right of the
                    // name — every city name keeps the same left edge.
                    if isHome {
                        Text("🏠")
                            .font(.system(size: 10))
                    }
                    // Day offset as quiet plain text beside the name — never
                    // a chip near the time, so the clock stays pristine.
                    if let chip = dayOffsetChip {
                        Text(chip)
                            .font(.system(size: 11, weight: .regular))
                            .opacity(0.55)
                    }
                    Spacer(minLength: 6)
                    Text(ClockMath.timeString(date: date, tz: city.timeZoneObject,
                                              pref: store.effectiveHourPreference,
                                              showMeridiem: false))
                        .font(.system(size: 22, weight: .heavy))
                        .monospacedDigit()
                        .kerning(-0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxHeight: .infinity)
                if bottomInset > 0 { Color.clear.frame(height: bottomInset) }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: bandHeight)
        .foregroundStyle(fg)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5)
        }
        .clipped()
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
