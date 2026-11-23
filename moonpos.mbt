///|
// Lunar position and rise/set events.
//
// Position: Meeus, Astronomical Algorithms ch. 47, truncated series (16
// longitude terms, 10 latitude terms, 13 distance terms). Accuracy ≈ 1'
// longitude, ≈ tens of km distance — sufficient for observation planning
// and rise/set work.
//
// Moonrise/moonset: numerical scan of the topocentric altitude at 10-minute
// steps with linear refinement, robust against the fast lunar motion
// (~13°/day) that breaks the simple two-point solar method.

// Topocentric altitude threshold for moonrise/moonset: upper limb of the
// Moon crossing the horizon (lunar semidiameter ≈ 0.25°, so half = 0.125°).
const MOONRISE_ALT : Double = 0.125

// Mean equatorial parallax of the Moon, degrees.

///|
const MOON_PARALLAX : Double = 0.95

///|
// Geocentric ecliptic position of the Moon at instant jd (UTC).
priv struct MoonEcliptic {
  longitude : Double // degrees [0, 360)
  latitude : Double // degrees [-4, 4]
  distance : Double // km, ~356400..406700
}

// Mean elongation D, moon anomaly M', sun anomaly M, argument of latitude F
// and mean longitude L' (Meeus 47.1-47.5), degrees.

///|
fn lunar_mean_elements(jd : Double) -> (Double, Double, Double, Double, Double) {
  let t = julian_centuries(jd)
  let lp = 218.3164477 +
    481267.88123421 * t -
    0.0015786 * t * t +
    t * t * t / 538841.0 -
    t * t * t * t / 65194000.0
  let d = 297.8501921 +
    445267.1114034 * t -
    0.0018819 * t * t +
    t * t * t / 545868.0 -
    t * t * t * t / 113065000.0
  let m = 357.5291092 +
    35999.0502909 * t -
    0.0001536 * t * t +
    t * t * t / 24490000.0
  let mp = 134.9633964 +
    477198.8675055 * t +
    0.0087414 * t * t +
    t * t * t / 69699.0 -
    t * t * t * t / 14712000.0
  let f = 93.2720950 +
    483202.0175233 * t -
    0.0036539 * t * t -
    t * t * t / 3526000.0 +
    t * t * t * t / 863310000.0
  (lp, d, m, mp, f)
}

// Truncated periodic corrections (Meeus Table 47.A / 47.B / 47.C, dominant
// terms only). Coefficients below are in degrees (table values × 1e-6).

///|
fn moon_ecliptic(jd : Double) -> MoonEcliptic {
  let (lp, d, m, mp, f) = lunar_mean_elements(jd)
  // Longitude terms
  let lon = lp +
    6.288774 * sin_deg(mp) +
    1.274027 * sin_deg(2.0 * d - mp) +
    0.658314 * sin_deg(2.0 * d) +
    0.213618 * sin_deg(2.0 * mp) -
    0.185116 * sin_deg(m) -
    0.114332 * sin_deg(2.0 * f) +
    0.058793 * sin_deg(2.0 * d - 2.0 * mp) +
    0.057066 * sin_deg(2.0 * d - m - mp) +
    0.053322 * sin_deg(2.0 * d + mp) +
    0.045758 * sin_deg(2.0 * d - m) -
    0.040923 * sin_deg(m - mp) -
    0.034720 * sin_deg(d) -
    0.030383 * sin_deg(m + mp) +
    0.015327 * sin_deg(2.0 * d - 2.0 * f) -
    0.012528 * sin_deg(mp + 2.0 * f) +
    0.010980 * sin_deg(mp - 2.0 * f)
  // Latitude terms
  let lat = 5.128122 * sin_deg(f) +
    0.280602 * sin_deg(mp + f) +
    0.277693 * sin_deg(mp - f) +
    0.173237 * sin_deg(2.0 * d - f) +
    0.055413 * sin_deg(2.0 * d - mp + f) +
    0.046271 * sin_deg(2.0 * d - mp - f) +
    0.032573 * sin_deg(2.0 * d + f) +
    0.017198 * sin_deg(2.0 * mp + f) +
    0.009266 * sin_deg(2.0 * d + mp - f) +
    0.008822 * sin_deg(2.0 * mp - f)
  // Distance terms (km), constant term 385000.56 + table × 1e-3 km
  let dist = 385000.56 +
    -20905.355 * cos_deg(mp) +
    -3699.111 * cos_deg(2.0 * d - mp) +
    -2955.968 * cos_deg(2.0 * d) +
    -569.925 * cos_deg(2.0 * mp) +
    48.884 * cos_deg(m) +
    -3.149 * cos_deg(2.0 * f) +
    246.158 * cos_deg(2.0 * d - 2.0 * mp) +
    -152.138 * cos_deg(2.0 * d - m - mp) +
    -170.733 * cos_deg(2.0 * d + mp) +
    -204.586 * cos_deg(2.0 * d - m) +
    -129.620 * cos_deg(m - mp) +
    108.743 * cos_deg(d) +
    104.755 * cos_deg(m + mp)
  MoonEcliptic::{
    longitude: normalize_deg(lon),
    latitude: lat,
    distance: dist,
  }
}

// Mean obliquity of the ecliptic + nutation correction, degrees.

///|
pub fn obliquity(jd : Double) -> Double {
  let t = julian_centuries(jd)
  let seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))
  let eps0 = 23.0 + (26.0 + seconds / 60.0) / 60.0
  let omega = 125.04 - 1934.136 * t
  eps0 + 0.00256 * cos_deg(omega)
}

// Converts ecliptic (longitude, latitude) to equatorial (RA, declination)
// at the given instant (using the true obliquity).

///|
pub fn ecliptic_to_equatorial(
  lon : Double,
  lat : Double,
  jd : Double,
) -> (Double, Double) {
  let eps = obliquity(jd)
  let ra = atan2_deg(
    sin_deg(lon) * cos_deg(eps) - tan_deg(lat) * sin_deg(eps),
    cos_deg(lon),
  )
  let dec = asin_deg(
    sin_deg(lat) * cos_deg(eps) + cos_deg(lat) * sin_deg(eps) * sin_deg(lon),
  )
  (normalize_deg(ra), dec)
}

///|
// Geocentric equatorial position of the Moon: right ascension and
// declination, plus ecliptic coordinates and distance.
pub struct MoonPosition {
  longitude : Double
  latitude : Double
  distance : Double
  right_ascension : Double
  declination : Double
}

///|
pub fn MoonPosition::get_longitude(self : MoonPosition) -> Double {
  self.longitude
}

///|
pub fn MoonPosition::get_latitude(self : MoonPosition) -> Double {
  self.latitude
}

///|
pub fn MoonPosition::get_distance(self : MoonPosition) -> Double {
  self.distance
}

///|
pub fn MoonPosition::get_right_ascension(self : MoonPosition) -> Double {
  self.right_ascension
}

///|
pub fn MoonPosition::get_declination(self : MoonPosition) -> Double {
  self.declination
}

///|
pub fn moon_position(jd : Double) -> MoonPosition {
  let e = moon_ecliptic(jd)
  let (ra, dec) = ecliptic_to_equatorial(e.longitude, e.latitude, jd)
  MoonPosition::{
    longitude: e.longitude,
    latitude: e.latitude,
    distance: e.distance,
    right_ascension: ra,
    declination: dec,
  }
}

///|
// Apparent (topocentric) altitude and azimuth of the Moon at instant jd
// seen from pos. Includes lunar parallax (mean 0.95°) and atmospheric
// refraction (Bennett's formula). Azimuth from north, clockwise.
pub fn moon_altaz(jd : Double, pos : GeoPos) -> (Double, Double) {
  let mp = moon_position(jd)
  let (alt, az) = equatorial_to_horizontal(
    mp.right_ascension,
    mp.declination,
    jd,
    pos,
  )
  // Parallax lowers the apparent position; refraction raises it again.
  let h = alt - MOON_PARALLAX * cos_deg(alt)
  (h + refract(h), az)
}

///|
// Moonrise, moonset and transit for the calendar day (UTC day convention,
// same as sun_times). Numerical scan with 10-minute resolution refined to
// about ±1 minute. In polar-lunar cases (moon never rises or never sets)
// the missing event is None.
pub struct MoonTimes {
  moonrise : Double?
  moonset : Double?
  transit : Double // JD of the altitude maximum
}

///|
pub fn MoonTimes::get_moonrise(self : MoonTimes) -> Double? {
  self.moonrise
}

///|
pub fn MoonTimes::get_moonset(self : MoonTimes) -> Double? {
  self.moonset
}

///|
pub fn MoonTimes::get_transit(self : MoonTimes) -> Double {
  self.transit
}

///|
pub fn moon_times(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
) -> MoonTimes? {
  let day_start = julian_date(year, month, day, 0, 0, 0)
  // Transit: the moment when local sidereal time equals the Moon's RA.
  // LST - RA grows ~14.5°/h, so it crosses a full 360° once per ~24.84 h.
  // Scanning 25 h guarantees exactly one crossing, even across the UTC day
  // boundary.
  let transit = moon_transit_jd(day_start, pos)
  // Rise/set: scan the UTC day window at 10-minute steps
  let step = 10.0 / 1440.0
  let n = 144
  let mut prev_alt = sample_moon_alt(day_start, pos)
  let mut rise : Double? = None
  let mut set : Double? = None
  for i in 0..<n {
    let jd1 = day_start + (i + 1).to_double() * step
    let alt = sample_moon_alt(jd1, pos)
    if rise is None && prev_alt < MOONRISE_ALT && alt >= MOONRISE_ALT {
      rise = Some(
        refine_crossing(
          day_start + i.to_double() * step,
          jd1,
          pos,
          MOONRISE_ALT,
        ),
      )
    }
    if set is None && prev_alt >= MOONRISE_ALT && alt < MOONRISE_ALT {
      set = Some(
        refine_crossing(
          day_start + i.to_double() * step,
          jd1,
          pos,
          MOONRISE_ALT,
        ),
      )
    }
    prev_alt = alt
  }
  Some(MoonTimes::{ moonrise: rise, moonset: set, transit, })
}

// Finds the meridian transit of the Moon after day_start by locating the
// zero crossing of wrap_deg(LST - RA_moon) within a 25-hour window,
// refined by linear interpolation (accuracy ≈ 1 min). wrap_deg has range
// (-180, 180], so the transit (LST = RA) is a continuous crossing of zero.

///|
fn moon_transit_jd(day_start : Double, pos : GeoPos) -> Double {
  let step = 10.0 / 1440.0
  let fn_f = fn(jd : Double) -> Double {
    let mp = moon_position(jd)
    wrap_deg(local_sidereal_time(jd, pos.lon) - mp.right_ascension)
  }
  let mut prev = fn_f(day_start)
  for i in 0..<(25 * 6) {
    let jd1 = day_start + (i + 1).to_double() * step
    let cur = fn_f(jd1)
    if prev < 0.0 && cur >= 0.0 {
      let frac = (0.0 - prev) / (cur - prev)
      return day_start + i.to_double() * step + frac * step
    }
    prev = cur
  }
  // Fallback (should not occur for reasonable dates): noon
  day_start + 0.5
}

// Topocentric apparent altitude of the Moon's center (with parallax and
// refraction), used by the rise/set scan.

///|
fn sample_moon_alt(jd : Double, pos : GeoPos) -> Double {
  let mp = moon_position(jd)
  let (geo_alt, az) = equatorial_to_horizontal(
    mp.right_ascension,
    mp.declination,
    jd,
    pos,
  )
  ignore(az)
  let h = geo_alt - MOON_PARALLAX * cos_deg(geo_alt)
  h + refract(h)
}

// Linear interpolation between two samples bracketing the crossing.

///|
fn refine_crossing(
  jd0 : Double,
  jd1 : Double,
  pos : GeoPos,
  threshold : Double,
) -> Double {
  let a0 = sample_moon_alt(jd0, pos)
  let a1 = sample_moon_alt(jd1, pos)
  if a1 == a0 {
    return jd0
  }
  jd0 + (threshold - a0) / (a1 - a0) * (jd1 - jd0)
}
