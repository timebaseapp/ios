import SwiftUI

/// One compact gradient strip inside the menubar popover. Emoji + name + 🏠
/// on the left, time and delta on the right, OKLCH gradient as the row's
/// background — the menubar version of the iOS world-clock row, sized for a
/// 360pt popover.
struct MenubarCityRow: View {
    let city: City
    let now: Date

    @Environment(TimebaseMacStore.self) private var store

    var body: some View {
        let hour = ClockMath.fractionalHour(in: city.timeZoneObject, date: now)
        let gradient = Palette.backgroundGradient(forHour: hour, scheme: .dark)
        let fg = Palette.foreground(forHour: hour, scheme: .dark)
        let isHome = city.id == store.homeCityId

        HStack(alignment: .center, spacing: 6) {
            Text(city.name)
                .font(.system(size: 13, weight: .regular))
                .lineLimit(1)
            if isHome {
                Text("🏠").font(.system(size: 10))
            }
            Spacer(minLength: 6)
            Text(store.deltaLabel(for: city))
                .font(Brand.mono(9))
                .opacity(0.75)
            Text(ClockMath.timeString(date: now, tz: city.timeZoneObject,
                                      pref: store.settings.hourPreference,
                                      showMeridiem: false))
                .font(.system(size: 15, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
