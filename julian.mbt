///|
// Julian date conversions. All public date/time values in this package are
// expressed as Julian Dates (days since -4712-01-01 12:00 UTC, Julian
// proleptic calendar). Anchors used in tests: JD 2451545.0 = 2000-01-01
// 12:00 UTC, MJD 0.0 = 1858-11-17 00:00 UTC.

const DAYS_PER_CENTURY : Double = 36525.0

///|
const J2000 : Double = 2451545.0

// Converts a Gregorian calendar date/time to a Julian Date.
// month 1-12, day 1-31, hour 0-23, minute 0-59, second 0-61 (leap seconds
// allowed as in ISO 8601). Supports dates after 1582-10-15 (Gregorian
// reform). Negative hours etc. are normalized.

///|
pub fn julian_date(
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
) -> Double {
  let mut y = year
  let mut m = month
  // Treat Jan/Feb as months 13/14 of the previous year (Meeus)
  if m <= 2 {
    y = y - 1
    m = m + 12
  }
  let a = y / 100
  let b = (2 - a + a / 4).to_double()
  // Day with fractional time: day 1 at 12:00 → 1.5
  let day_frac = day.to_double() +
    (hour * 3600 + minute * 60 + second).to_double() / 86400.0
  let jd = (365.25 * (y + 4716).to_double()).floor() +
    (30.6001 * (m + 1).to_double()).floor() +
    day_frac +
    b -
    1524.5
  jd
}

// Converts a Julian Date back to a Gregorian date/time.
// Returns (year, month, day, hour, minute, second). Second is rounded to the
// nearest integer, so round-trips are exact for whole seconds.

///|
pub fn jd_to_datetime(
  jd : Double,
) -> (Int32, Int32, Int32, Int32, Int32, Int32) {
  let z = (jd + 0.5).floor()
  let f = jd + 0.5 - z
  // Gregorian calendar reform epoch: JD 2299160.5 = 1582-10-15
  let mut a = z
  if z >= 2299161.0 {
    let alpha = ((z - 1867216.25) / 36524.25).floor()
    a = z + 1.0 + alpha - (alpha / 4.0).floor()
  }
  let b = a + 1524.0
  let c = ((b - 122.1) / 365.25).floor()
  let d = (365.25 * c).floor()
  let e = ((b - d) / 30.6001).floor()
  let day_frac = b - d - (30.6001 * e).floor() + f
  let day = day_frac.floor().to_int()
  let month = if e < 14.0 { (e - 1.0).to_int() } else { (e - 13.0).to_int() }
  let year = if month > 2 {
    (c - 4716.0).to_int()
  } else {
    (c - 4715.0).to_int()
  }
  // Fractional day → h:m:s
  let frac = day_frac - day.to_double()
  let total_seconds = (frac * 86400.0 + 0.5).floor().to_int()
  let hour = total_seconds / 3600
  let minute = total_seconds % 3600 / 60
  let second = total_seconds % 60
  (year, month, day, hour, minute, second)
}

// Julian centuries since J2000.0, the time argument of all solar/lunar
// polynomials in this package.

///|
pub fn julian_centuries(jd : Double) -> Double {
  (jd - J2000) / DAYS_PER_CENTURY
}

// Modified Julian Date: MJD = JD - 2400000.5. MJD 0.0 = 1858-11-17 00:00 UTC.

///|
pub fn to_mjd(jd : Double) -> Double {
  jd - 2400000.5
}

///|
pub fn from_mjd(mjd : Double) -> Double {
  mjd + 2400000.5
}

///|
// Normalizes an angle in degrees to [0, 360).
pub fn normalize_deg(deg : Double) -> Double {
  let mut d = deg % 360.0
  if d < 0.0 {
    d = d + 360.0
  }
  d
}

// Normalizes an angle in degrees to (-180, 180].

///|
pub fn wrap_deg(deg : Double) -> Double {
  let d = normalize_deg(deg)
  if d > 180.0 {
    d - 360.0
  } else {
    d
  }
}

// Radians ↔ degrees helpers.

///|
pub fn deg2rad(deg : Double) -> Double {
  deg * 3.14159265358979323846 / 180.0
}

///|
pub fn rad2deg(rad : Double) -> Double {
  rad * 180.0 / 3.14159265358979323846
}

///|
pub fn sin_deg(deg : Double) -> Double {
  @math.sin(deg2rad(deg))
}

///|
pub fn cos_deg(deg : Double) -> Double {
  @math.cos(deg2rad(deg))
}

///|
pub fn tan_deg(deg : Double) -> Double {
  @math.tan(deg2rad(deg))
}

///|
pub fn asin_deg(x : Double) -> Double {
  rad2deg(@math.asin(x))
}

///|
pub fn acos_deg(x : Double) -> Double {
  rad2deg(@math.acos(x))
}

///|
pub fn atan2_deg(y : Double, x : Double) -> Double {
  rad2deg(@math.atan2(y, x))
}

///|
// Geographic position. Latitude and longitude in degrees; north and east are
// positive (as in GNSS/NMEA convention).
pub struct GeoPos {
  lat : Double
  lon : Double
}

///|
pub fn make_geo(lat : Double, lon : Double) -> GeoPos {
  GeoPos::{ lat, lon, }
}
