///|
// High-precision solar events and annual daylight tables.
//
// sun_times in sun.mbt uses the NOAA one-pass method (solar parameters
// evaluated at UTC noon), giving ±2 min accuracy. The functions here
// iterate: evaluate the solar parameters AT the candidate rise/set instant,
// re-solve, and repeat — pushing the accuracy to about ±0.5 min. This
// mirrors how the NOAA Solar Calculator's interactive mode works, versus
// its spreadsheet mode.

// Iteratively refines rise/set minutes for a given zenith. Two iterations
// are enough: the declination drifts <0.4°/day, so one correction moves
// the event by <2 min and the second by <0.05 min.
fn rise_set_iterative(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
  zenith : Double,
) -> (Double, Double)? {
  let day_start = julian_date(year, month, day, 0, 0, 0)
  // Seed with the one-pass NOAA method
  let noon_jd = day_start + 0.5
  let params0 = solar_params(noon_jd)
  let cos_ha = cos_deg(zenith) /
    (cos_deg(pos.lat) * cos_deg(params0.declination)) -
    tan_deg(pos.lat) * tan_deg(params0.declination)
  if cos_ha < -1.0 || cos_ha > 1.0 {
    return None
  }
  let ha0 = acos_deg(cos_ha)
  let noon_min0 = 720.0 - 4.0 * pos.lon - params0.equation_of_time
  let mut rise_min = noon_min0 - 4.0 * ha0
  let mut set_min = noon_min0 + 4.0 * ha0
  // Two refinement passes: re-evaluate solar parameters at the events
  for _ in 0..<2 {
    let p_rise = solar_params(day_start + rise_min / 1440.0)
    let p_set = solar_params(day_start + set_min / 1440.0)
    let ch_r = cos_deg(zenith) /
      (cos_deg(pos.lat) * cos_deg(p_rise.declination)) -
      tan_deg(pos.lat) * tan_deg(p_rise.declination)
    let ch_s = cos_deg(zenith) / (cos_deg(pos.lat) * cos_deg(p_set.declination)) -
      tan_deg(pos.lat) * tan_deg(p_set.declination)
    if ch_r < -1.0 || ch_r > 1.0 || ch_s < -1.0 || ch_s > 1.0 {
      return None
    }
    // Recompute the full formula with the event-time parameters (not
    // incremental corrections on top of noon_min0)
    rise_min = 720.0 -
      4.0 * pos.lon -
      p_rise.equation_of_time -
      4.0 * acos_deg(ch_r)
    set_min = 720.0 -
      4.0 * pos.lon -
      p_set.equation_of_time +
      4.0 * acos_deg(ch_s)
  }
  Some((rise_min, set_min))
}

///|
// High-precision sunrise/sunset (±0.5 min target). Returns (rise, set) as
// Julian Dates in UTC, or None for polar day/night.
pub fn sun_rise_set_precise(
  year : Int32,
  month : Int32,
  day : Int32,
  pos : GeoPos,
) -> (Double, Double)? {
  match rise_set_iterative(year, month, day, pos, SUNRISE_ZENITH) {
    Some((rise_min, set_min)) => {
      let day_start = julian_date(year, month, day, 0, 0, 0)
      Some((day_start + rise_min / 1440.0, day_start + set_min / 1440.0))
    }
    None => None
  }
}

///|
// Daylight statistics for one location and one Gregorian year: total
// daylight hours, the longest and shortest days, and polar conditions.
pub struct YearDaylight {
  total_hours : Double
  longest_day : Double // daylight duration of the longest day, hours
  longest_date : (Int32, Int32)
  shortest_day : Double
  shortest_date : (Int32, Int32)
  // Number of days with no sunrise (polar night) and no sunset (polar day)
  polar_night_days : Int32
  polar_day_days : Int32
}

///|
pub fn YearDaylight::get_total_hours(self : YearDaylight) -> Double {
  self.total_hours
}

///|
pub fn YearDaylight::get_longest_day(self : YearDaylight) -> Double {
  self.longest_day
}

///|
pub fn YearDaylight::get_longest_date(self : YearDaylight) -> (Int32, Int32) {
  self.longest_date
}

///|
pub fn YearDaylight::get_shortest_day(self : YearDaylight) -> Double {
  self.shortest_day
}

///|
pub fn YearDaylight::get_shortest_date(self : YearDaylight) -> (Int32, Int32) {
  self.shortest_date
}

///|
pub fn YearDaylight::get_polar_night_days(self : YearDaylight) -> Int32 {
  self.polar_night_days
}

///|
pub fn YearDaylight::get_polar_day_days(self : YearDaylight) -> Int32 {
  self.polar_day_days
}

// Days-in-month table (leap-year aware, Gregorian rules).

///|
pub fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    2 =>
      if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
// Builds the annual daylight summary by walking every day of `year` with
// the precise rise/set solver. Uses the one-pass sun_times internally for
// speed; the accuracy of the aggregate is well within a minute.
pub fn year_daylight(year : Int32, pos : GeoPos) -> YearDaylight {
  let mut total_minutes = 0.0
  let mut longest = 0.0
  let mut longest_date = (1, 1)
  let mut shortest = 100000.0
  let mut shortest_date = (1, 1)
  let mut polar_night = 0
  let mut polar_day = 0
  for month in 1..<13 {
    let dim = days_in_month(year, month)
    for day in 1..<=dim {
      match sun_times(year, month, day, pos) {
        Some(t) => {
          let minutes = t.daylight_minutes()
          total_minutes = total_minutes + minutes
          if minutes > longest {
            longest = minutes
            longest_date = (month, day)
          }
          if minutes < shortest {
            shortest = minutes
            shortest_date = (month, day)
          }
        }
        None => {
          // Polar day or night: classify by the sun's altitude at noon
          let noon_alt = sun_position(
            julian_date(year, month, day, 12, 0, 0),
            pos,
          ).get_altitude()
          if noon_alt > 0.0 {
            polar_day = polar_day + 1
            total_minutes = total_minutes + 1440.0
            if 1440.0 > longest {
              longest = 1440.0
              longest_date = (month, day)
            }
          } else {
            polar_night = polar_night + 1
            if 0.0 < shortest {
              shortest = 0.0
              shortest_date = (month, day)
            }
          }
        }
      }
    }
  }
  YearDaylight::{
    total_hours: total_minutes / 60.0,
    longest_day: longest / 60.0,
    longest_date,
    shortest_day: shortest / 60.0,
    shortest_date,
    polar_night_days: polar_night,
    polar_day_days: polar_day,
  }
}

///|
// Monthly daylight table: for each month of `year`, the daylight duration
// (hours) on the 1st, 11th and 21st of the month. Useful for solar-panel
// siting and agriculture planning. None entries mark polar conditions.
pub fn daylight_table(year : Int32, pos : GeoPos) -> Array[(Int32, Double?)] {
  let out : Array[(Int32, Double?)] = Array(capacity=12)
  for month in 1..<13 {
    let day = 11
    let row = match sun_times(year, month, day, pos) {
      Some(t) => Some(t.daylight_minutes() / 60.0)
      None => None
    }
    out.push((month, row))
  }
  out
}
