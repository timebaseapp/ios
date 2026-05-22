import Foundation

/// Sunrise / sunset from latitude, longitude and date — the standard NOAA
/// "sunrise equation". Pure math, no network, no WeatherKit. Accurate to a
/// minute or two, which is plenty for a day-bar visualization.
enum SolarTime {

    struct DayLight {
        /// Fractional local hour (0..<24), or nil for polar day / night.
        let sunrise: Double?
        let sunset: Double?
    }

    static func dayLight(latitude: Double, longitude: Double,
                         date: Date, timeZone: TimeZone) -> DayLight {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return DayLight(sunrise: nil, sunset: nil)
        }

        let rad = Double.pi / 180
        let jdn = Double(julianDayNumber(year: year, month: month, day: day))
        let n = jdn - 2451545.0 + 0.0008

        let meanSolarNoon = n - longitude / 360.0
        let M = (357.5291 + 0.98560028 * meanSolarNoon)
            .truncatingRemainder(dividingBy: 360)
        let center = 1.9148 * sin(M * rad)
            + 0.0200 * sin(2 * M * rad)
            + 0.0003 * sin(3 * M * rad)
        let lambda = (M + center + 180 + 102.9372)
            .truncatingRemainder(dividingBy: 360)
        let transit = 2451545.0 + meanSolarNoon
            + 0.0053 * sin(M * rad) - 0.0069 * sin(2 * lambda * rad)
        let sinDecl = sin(lambda * rad) * sin(23.4397 * rad)
        let cosDecl = cos(asin(sinDecl))
        let phi = latitude * rad
        let cosHourAngle = (sin(-0.833 * rad) - sin(phi) * sinDecl)
            / (cos(phi) * cosDecl)
        guard cosHourAngle >= -1, cosHourAngle <= 1 else {
            return DayLight(sunrise: nil, sunset: nil)   // polar day / night
        }
        let hourAngle = acos(cosHourAngle) / rad
        let rise = transit - hourAngle / 360.0
        let set = transit + hourAngle / 360.0

        return DayLight(
            sunrise: localHour(julianDate: rise, timeZone: timeZone),
            sunset: localHour(julianDate: set, timeZone: timeZone)
        )
    }

    private static func julianDayNumber(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    private static func localHour(julianDate jd: Double, timeZone: TimeZone) -> Double {
        let date = Date(timeIntervalSince1970: (jd - 2440587.5) * 86400)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }
}

/// Great-circle distance in kilometers — ported from the iOS `haversine`.
func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let radius = 6371.0
    let toRad = { (d: Double) in d * .pi / 180 }
    let dLat = toRad(lat2 - lat1)
    let dLon = toRad(lon2 - lon1)
    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2)
    return radius * 2 * asin(sqrt(a))
}
