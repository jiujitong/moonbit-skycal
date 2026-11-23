///|
// Solar position and rise/set calculations based on the NOAA Solar
// Calculator algorithm (low-precision solar equations, accuracy ≈ ±0.03°
// position, ±1-2 min rise/set between years 1900-2100). Reference: NOAA
// Global Monitoring Division "Solar Calculation Details" and the
// General Solar Position Calculations NOAA technical document.

// Solar position parameters for a given instant.
priv struct SolarParams {
  declination : Double // degrees, [-23.44, 23.44]
  right_ascension : Double // degrees, [0, 360)
  equation_of_time : Double // minutes
}

// Computes declination, right ascension and equation of time at instant jd
// (UTC).

///|
fn solar_params(jd : Double) -> SolarParams {
  let t = julian_centuries(jd)
  // Geometric mean longitude of the sun (degrees)
  let l0 = normalize_deg(280.46646 + 36000.76983 * t + 0.0003032 * t * t)
  // Mean anomaly of the sun (degrees)
  let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
  // Eccentricity of Earth orbit
  let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
  // Sun's equation of center
  let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin_deg(m) +
    (0.019993 - 0.000101 * t) * sin_deg(2.0 * m) +
    0.000289 * sin_deg(3.0 * m)
  let true_long = l0 + c
  // Apparent longitude (aberration + nutation)
  let omega = 125.04 - 1934.136 * t
  let lambda = true_long - 0.00569 - 0.00478 * sin_deg(omega)
  // Mean obliquity of the ecliptic
  let seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))
  let eps0 = 23.0 + (26.0 + seconds / 60.0) / 60.0
  let eps = eps0 + 0.00256 * cos_deg(omega)
  // Declination
  let declination = asin_deg(sin_deg(eps) * sin_deg(lambda))
  // Right ascension
  let ra = normalize_deg(
    atan2_deg(cos_deg(eps) * sin_deg(lambda), cos_deg(lambda)),
  )
  // Equation of time (minutes)
  let y = tan_deg(eps / 2.0) * tan_deg(eps / 2.0)
  let eqtime = 4.0 *
    rad2deg(
      y * sin_deg(2.0 * l0) -
      2.0 * e * sin_deg(m) +
      4.0 * e * y * sin_deg(m) * cos_deg(2.0 * l0) -
      0.5 * y * y * sin_deg(4.0 * l0) -
      1.25 * e * e * sin_deg(2.0 * m),
    )
  SolarParams::{ declination, right_ascension: ra, equation_of_time: eqtime, }
}

///|
// Observed solar position at instant `jd` (UTC) seen from `pos`.
// `altitude` and `azimuth` are apparent values in degrees; azimuth is
// measured clockwise from true north (0 = north, 90 = east).
pub struct SunPosition {
  altitude : Double
  azimuth : Double
  declination : Double
  right_ascension : Double
}

///|
pub fn SunPosition::get_altitude(self : SunPosition) -> Double {
  self.altitude
}

///|
pub fn SunPosition::get_azimuth(self : SunPosition) -> Double {
  self.azimuth
}

///|
pub fn SunPosition::get_declination(self : SunPosition) -> Double {
  self.declination
}

///|
pub fn SunPosition::get_right_ascension(self : SunPosition) -> Double {
  self.right_ascension
}

///|
pub fn sun_position(jd : Double, pos : GeoPos) -> SunPosition {
  let params = solar_params(jd)
  let (altitude, azimuth) = equatorial_to_horizontal(
    params.right_ascension,
    params.declination,
    jd,
    pos,
  )
  SunPosition::{
    altitude,
    azimuth,
    declination: params.declination,
    right_ascension: params.right_ascension,
  }
}

///|
// Apparent ecliptic longitude of the Sun, degrees [0, 360). This is the
// quantity used by the solar terms (节气) calculation.
pub fn solar_apparent_longitude(jd : Double) -> Double {
  let t = julian_centuries(jd)
  let l0 = normalize_deg(280.46646 + 36000.76983 * t + 0.0003032 * t * t)
  let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
  let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin_deg(m) +
    (0.019993 - 0.000101 * t) * sin_deg(2.0 * m) +
    0.000289 * sin_deg(3.0 * m)
  let true_long = l0 + c
  let omega = 125.04 - 1934.136 * t
  normalize_deg(true_long - 0.00569 - 0.00478 * sin_deg(omega))
}

///|
// Rise, set and solar noon events for one local calendar day, as Julian
// Dates in UTC. `None` for polar day / polar night, where the reference
// altitude is never crossed.
pub struct SunTimes {
  sunrise : Double
  sunset : Double
  solar_noon : Double
}

///|
pub fn SunTimes::get_sunrise(self : SunTimes) -> Double {
  self.sunrise
}

///|
pub fn SunTimes::get_sunset(self : SunTimes) -> Double {
  self.sunset
}

///|
pub fn SunTimes::get_solar_noon(self : SunTimes) -> Double {
  self.solar_noon
}

// Daylight duration in minutes (0 for polar events reported via Option).

///|
pub fn SunTimes::daylight_minutes(self : SunTimes) -> Double {
  (self.sunset - self.sunrise) * 1440.0
}

// Zenith angle used by NOAA for sunrise/sunset: 90° + refraction + solar
// radius correction (0.833°).

///|
const SUNRISE_ZENITH : Double = 90.833

// Computes rise/set/noon for the calendar day interpreted as a UTC day.
// Solar parameters are evaluated at that day's UTC noon, matching the NOAA
// spreadsheet methodology. For |tz| < 12h the caller can render results in
// local time with `jd_to_local_string` and the events of the matching local
// calendar day are reproduced exactly.

///|
pub fn sun_times(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
) -> SunTimes? {
  rise_set_at(year, month, day, pos, SUNRISE_ZENITH).map(fn(result) {
    let (rise_min, set_min, noon_min) = result
    // rise_min/set_min/noon_min are minutes relative to 00:00 UTC of the
    // same Y-M-D day (they may be negative or exceed 1440 when events
    // cross midnight, which Julian Date arithmetic absorbs naturally).
    let day_start = julian_date(year, month, day, 0, 0, 0)
    SunTimes::{
      sunrise: day_start + rise_min / 1440.0,
      sunset: day_start + set_min / 1440.0,
      solar_noon: day_start + noon_min / 1440.0,
    }
  })
}

// Core minute-of-day computation, shared by rise/set and twilight events.
// Returns (rise_min, set_min, noon_min) in UTC minutes for the local day.

///|
fn rise_set_at(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
  zenith : Double,
) -> (Double, Double, Double)? {
  // Solar parameters evaluated at UTC noon of the UTC day matching the
  // requested local calendar day (NOAA spreadsheet methodology)
  let noon_jd = julian_date(year, month, day, 12, 0, 0)
  let params = solar_params(noon_jd)
  // Hour angle for the given zenith
  let cos_ha = cos_deg(zenith) /
    (cos_deg(pos.lat) * cos_deg(params.declination)) -
    tan_deg(pos.lat) * tan_deg(params.declination)
  if cos_ha < -1.0 {
    // Polar day: sun never crosses below zenith
    return None
  }
  if cos_ha > 1.0 {
    // Polar night: sun never rises above zenith
    return None
  }
  let ha = acos_deg(cos_ha)
  let noon_min = 720.0 - 4.0 * pos.lon - params.equation_of_time
  let rise_min = noon_min - 4.0 * ha
  let set_min = noon_min + 4.0 * ha
  Some((rise_min, set_min, noon_min))
}

///|
// Morning and evening golden hour windows (JD, UTC). Photography
// convention: golden hour while the sun is between -4° and +6° altitude;
// blue hour while between -6° and -4°.
pub struct GoldenHours {
  // Morning window [blue_start, golden_end]
  morning_start : Double
  morning_end : Double
  // Evening window [golden_start, blue_end]
  evening_start : Double
  evening_end : Double
}

///|
pub fn GoldenHours::get_morning_start(self : GoldenHours) -> Double {
  self.morning_start
}

///|
pub fn GoldenHours::get_morning_end(self : GoldenHours) -> Double {
  self.morning_end
}

///|
pub fn GoldenHours::get_evening_start(self : GoldenHours) -> Double {
  self.evening_start
}

///|
pub fn GoldenHours::get_evening_end(self : GoldenHours) -> Double {
  self.evening_end
}

///|
pub fn golden_hours(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
) -> GoldenHours? {
  // Sun crosses +6° (zenith 84°) and -6° (zenith 96°) altitude
  let upper = rise_set_at(year, month, day, pos, 84.0)
  let lower = rise_set_at(year, month, day, pos, 96.0)
  match (upper, lower) {
    (Some(u), Some(l)) => {
      let day_start = julian_date(year, month, day, 0, 0, 0)
      let up_rise = day_start + u.0 / 1440.0
      let up_set = day_start + u.1 / 1440.0
      let lo_rise = day_start + l.0 / 1440.0
      let lo_set = day_start + l.1 / 1440.0
      Some(GoldenHours::{
        // Morning: sun climbs from -6° (lo_rise) through -4° to +6° (up_rise)
        morning_start: lo_rise,
        morning_end: up_rise,
        // Evening: sun descends from +6° (up_set) to -6° (lo_set)
        evening_start: up_set,
        evening_end: lo_set,
      })
    }
    _ => None
  }
}

///|
// Civil twilight boundaries (sun crosses -6°). Returns (dawn, dusk) as
// Julian Dates in UTC, or None in polar regions/seasons.
pub fn civil_twilight(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
) -> (Double, Double)? {
  twilight_pair(year, month, day, pos, 96.0)
}

// Nautical twilight boundaries (sun crosses -12°).

///|
pub fn nautical_twilight(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
) -> (Double, Double)? {
  twilight_pair(year, month, day, pos, 102.0)
}

// Astronomical twilight boundaries (sun crosses -18°).

///|
pub fn astronomical_twilight(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
) -> (Double, Double)? {
  twilight_pair(year, month, day, pos, 108.0)
}

///|
fn twilight_pair(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
  zenith : Double,
) -> (Double, Double)? {
  match rise_set_at(year, month, day, pos, zenith) {
    Some((rise_min, set_min, _)) => {
      let day_start = julian_date(year, month, day, 0, 0, 0)
      Some((day_start + rise_min / 1440.0, day_start + set_min / 1440.0))
    }
    None => None
  }
}
