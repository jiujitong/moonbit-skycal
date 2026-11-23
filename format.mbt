///|
// Formatting helpers for Julian Dates and geographic coordinates.

// Zero-pads an integer to 2 digits, e.g. 7 → "07".
pub fn pad2(n : Int32) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

// Formats a Julian Date as "YYYY-MM-DD HH:MM:SS" (UTC).

///|
pub fn jd_to_string(jd : Double) -> String {
  let (y, m, d, h, mi, s) = jd_to_datetime(jd)
  y.to_string() +
  "-" +
  pad2(m) +
  "-" +
  pad2(d) +
  " " +
  pad2(h) +
  ":" +
  pad2(mi) +
  ":" +
  pad2(s) +
  " UTC"
}

// Formats a Julian Date shifted to the given UTC offset, as
// "YYYY-MM-DD HH:MM" in local time (seconds truncated).

///|
pub fn jd_to_local_string(jd : Double, tz_offset_hours : Double) -> String {
  let (y, m, d, h, mi, _) = jd_to_datetime(jd + tz_offset_hours / 24.0)
  y.to_string() + "-" + pad2(m) + "-" + pad2(d) + " " + pad2(h) + ":" + pad2(mi)
}

// Formats degrees with one decimal place, e.g. "39.9°N".

///|
pub fn format_lat(lat : Double) -> String {
  if lat >= 0.0 {
    lat.to_string() + "°N"
  } else {
    (-lat).to_string() + "°S"
  }
}

///|
pub fn format_lon(lon : Double) -> String {
  if lon >= 0.0 {
    lon.to_string() + "°E"
  } else {
    (-lon).to_string() + "°W"
  }
}

// Formats a duration in minutes as "Hh MMm", e.g. "15h 03m".

///|
pub fn format_minutes(minutes : Double) -> String {
  let total = minutes.round().to_int()
  let hours = total / 60
  let mins = total % 60
  hours.to_string() + "h " + pad2(mins) + "m"
}
