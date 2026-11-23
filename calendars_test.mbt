///|
// Calendar conversion tests. Anchors: the Gregorian reform itself, the
// Unix epoch, and historical Julian-calendar dates.

fn approx7(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() < tol
}

///|
test "Julian calendar round trips" {
  // Historical dates before 1582, plus leap-year edge (Julian leap rule:
  // every 4th year, no century exception)
  let dates = [
    (-44, 3, 15), // assassination of Julius Caesar
    (622, 7, 16), // Islamic epoch reference date
    (1066, 10, 14), // Battle of Hastings
    (1476, 2, 29), // Julian leap day (1476 = 4 × 369)
    (1582, 10, 14), // last full Julian day in Catholic Europe
  ]
  for d in dates {
    let jd = @skycal.julian_calendar_to_jd(d.0, d.1, d.2)
    let back = @skycal.jd_to_julian_calendar(jd)
    assert_eq(back.0, d.0)
    assert_eq(back.1, d.1)
    assert_eq(back.2, d.2)
  }
}

///|
test "Julian vs Gregorian drift of 10 days by 1582" {
  // The Gregorian reform removed 10 days: Julian 1582-10-14 equals
  // Gregorian 1582-10-24
  let julian_jd = @skycal.julian_calendar_to_jd(1582, 10, 14)
  let gregorian_jd = @skycal.julian_date(1582, 10, 24, 0, 0, 0)
  assert_true(approx7(julian_jd, gregorian_jd, 0.001))
}

///|
test "JDN anchors" {
  // J2000 noon: 2000-01-01 12:00 UTC → JDN 2451545
  assert_eq(@skycal.jd_to_jdn(2451545.0), 2451545)
  assert_eq(@skycal.jdn_to_jd(2451545), 2451544.5)
  // Unix epoch day: 1970-01-01 → JDN 2440588
  assert_eq(@skycal.jd_to_jdn(2440587.5), 2440588)
}

///|
test "unix epoch anchor" {
  assert_eq(@skycal.to_unix_seconds(1970, 1, 1, 0, 0, 0), 0.0)
  assert_eq(@skycal.unix_seconds_to_jd(0.0), @skycal.UNIX_EPOCH_JD)
}

///|
test "unix timestamp round trips" {
  let stamps = [
    (2000, 1, 1, 12, 0, 0),
    (2026, 11, 23, 14, 30, 45),
    (2038, 1, 19, 3, 14, 8), // beyond the 32-bit signed limit
  ]
  for s in stamps {
    let sec = @skycal.to_unix_seconds(s.0, s.1, s.2, s.3, s.4, s.5)
    let back = @skycal.from_unix_seconds(sec)
    assert_eq(back.0, s.0)
    assert_eq(back.1, s.1)
    assert_eq(back.2, s.2)
    assert_eq(back.3, s.3)
    assert_eq(back.4, s.4)
    assert_eq(back.5, s.5)
  }
}

///|
test "known unix timestamp value" {
  // 2000-01-01 00:00:00 UTC = 946684800
  assert_eq(@skycal.to_unix_seconds(2000, 1, 1, 0, 0, 0), 946684800.0)
}
