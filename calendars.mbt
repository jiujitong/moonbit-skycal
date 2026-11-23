///|
// Calendar conversions beyond the Gregorian calendar: the Julian calendar
// (pre-1582 historical dates), Julian Day Numbers, and Unix epoch seconds.
// All anchored on the Julian Date base of julian_date.

///|
// Converts a Julian calendar date (used historically before the 1582
// Gregorian reform) to a Julian Date at midnight.
pub fn julian_calendar_to_jd(
  year : Int32,
  month : Int32,
  day : Int32,
) -> Double {
  let mut y = year
  let mut m = month
  if m <= 2 {
    y = y - 1
    m = m + 12
  }
  // No century correction (B = 0) — that is the whole difference from the
  // Gregorian algorithm in julian_date
  (365.25 * (y + 4716).to_double()).floor() +
  (30.6001 * (m + 1).to_double()).floor() +
  day.to_double() -
  1524.5
}

// Converts a Julian Date (midnight-aligned) to a Julian calendar date.

///|
pub fn jd_to_julian_calendar(jd : Double) -> (Int32, Int32, Int32) {
  let z = (jd + 0.5).floor()
  let b = z + 1524.0
  let c = ((b - 122.1) / 365.25).floor()
  let d = (365.25 * c).floor()
  let e = ((b - d) / 30.6001).floor()
  let day = (b - d - (30.6001 * e).floor()).to_int()
  let month = if e < 14.0 { (e - 1.0).to_int() } else { (e - 13.0).to_int() }
  let year = if month > 2 {
    (c - 4716.0).to_int()
  } else {
    (c - 4715.0).to_int()
  }
  (year, month, day)
}

///|
// Julian Day Number: the integer count of days since -4712-01-01 (Julian),
// each JDN spanning noon to noon. jd_to_jdn aligns a JD to the JDN of the
// day containing its noon.
pub fn jd_to_jdn(jd : Double) -> Int32 {
  (jd + 0.5).floor().to_int()
}

///|
pub fn jdn_to_jd(jdn : Int32) -> Double {
  jdn.to_double() - 0.5
}

///|
// Unix epoch seconds (UTC) ↔ Julian Date. Unix epoch 1970-01-01 00:00 UTC
// = JD 2440587.5.
pub const UNIX_EPOCH_JD : Double = 2440587.5

///|
pub fn jd_to_unix_seconds(jd : Double) -> Double {
  (jd - UNIX_EPOCH_JD) * 86400.0
}

///|
pub fn unix_seconds_to_jd(seconds : Double) -> Double {
  UNIX_EPOCH_JD + seconds / 86400.0
}

// Converts a Gregorian date/time to Unix epoch seconds (UTC).

///|
pub fn to_unix_seconds(
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
) -> Double {
  jd_to_unix_seconds(julian_date(year, month, day, hour, minute, second))
}

// Converts Unix epoch seconds back to a Gregorian date/time (UTC).

///|
pub fn from_unix_seconds(
  seconds : Double,
) -> (Int32, Int32, Int32, Int32, Int32, Int32) {
  jd_to_datetime(unix_seconds_to_jd(seconds))
}
