import SwiftUI

/// The per-city detail — a calm, watch-face-grade full screen. Full-bleed
/// time-of-day gradient, the city name as an eyebrow, the time as the hero,
/// a weekday + delta line, and a 24-hour day-bar with sunrise / sunset. No
/// back button: a tap anywhere returns to the world clock.
struct CityDetailView: View {
    let city: City
    let onDismiss: () -> Void

    @Environment(TimebaseWatchStore.self) private var store
    @Environment(\.isLuminanceReduced) private var aod

    var body: some View {
        let date = store.displayDate
        let tz = city.timeZoneObject
        let hour = ClockMath.fractionalHour(in: tz, date: date)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark, aod: aod)
        let fg = Palette.foreground(forHour: hour, scheme: .dark, aod: aod)

        ZStack {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 4)

                Text(city.name)
                    .font(.system(size: 15, weight: .medium))
                    .kerning(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(0.9)

                Text(ClockMath.timeString(date: date, tz: tz,
                                          pref: store.effectiveHourPreference,
                                          showMeridiem: false))
                    .font(.system(size: 46, weight: .heavy))
                    .monospacedDigit()
                    .kerning(-1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 1)

                Text(subLine(tz: tz, date: date))
                    .font(Brand.mono(9))
                    .tracking(0.5)
                    .opacity(0.78)
                    .padding(.top, 3)

                Spacer(minLength: 8)

                WatchDayBar(city: city, tz: tz, date: date,
                            scheme: .dark, foreground: fg,
                            pref: store.effectiveHourPreference)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .gesture(DragGesture())   // swallow swipes so the pager beneath stays put
        .onAppear { store.setFocusedCity(city.id) }
    }

    /// `WED · +5h 30m`, or `WED · HOME` for the home city.
    private func subLine(tz: TimeZone, date: Date) -> String {
        var fmt = Date.FormatStyle.dateTime.weekday(.abbreviated)
        fmt.timeZone = tz
        let weekday = fmt.format(date).uppercased()
        if city.id == store.homeCityId { return "\(weekday)  ·  HOME" }
        return "\(weekday)  ·  \(store.deltaLabel(for: city))"
    }
}

/// A 24-hour OKLCH day-bar: the time-of-day gradient swept left to right, a
/// dot at the city's current hour, and notches at sunrise / sunset with a
/// caption below.
struct WatchDayBar: View {
    let city: City
    let tz: TimeZone
    let date: Date
    let scheme: ColorScheme
    let foreground: Color
    let pref: HourPreference

    var body: some View {
        let light = SolarTime.dayLight(latitude: city.latitude, longitude: city.longitude,
                                       date: date, timeZone: tz)
        let nowHour = ClockMath.fractionalHour(in: tz, date: date)

        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .leading) {
                    LinearGradient(colors: dayColors, startPoint: .leading, endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    if let sr = light.sunrise {
                        notch.position(x: w * CGFloat(sr / 24), y: h / 2)
                    }
                    if let ss = light.sunset {
                        notch.position(x: w * CGFloat(ss / 24), y: h / 2)
                    }
                    Circle()
                        .fill(foreground)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 1))
                        .position(x: w * CGFloat(nowHour / 24), y: h / 2)
                }
            }
            .frame(height: 16)

            HStack(spacing: 12) {
                if let sr = light.sunrise {
                    captionRow(symbol: "sunrise", text: ClockMath.hourLabel(sr, pref: pref))
                }
                if let ss = light.sunset {
                    captionRow(symbol: "sunset", text: ClockMath.hourLabel(ss, pref: pref))
                }
                if light.sunrise == nil, light.sunset == nil {
                    Text("Polar day or night")
                        .font(Brand.mono(8))
                        .opacity(0.7)
                }
            }
        }
    }

    private var notch: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(foreground.opacity(0.85))
            .frame(width: 2, height: 16)
    }

    private func captionRow(symbol: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(text).font(Brand.mono(9))
        }
        .opacity(0.85)
    }

    private var dayColors: [Color] {
        stride(from: 0, through: 24, by: 1).map {
            Palette.background(forHour: Double($0), scheme: scheme)
        }
    }
}
