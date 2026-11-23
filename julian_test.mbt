///|
// Julian date conversion tests.

test "JD anchor: J2000.0 epoch" {
  // 2000-01-01 12:00 UTC is exactly JD 2451545.0
  assert_eq(@skycal.julian_date(2000, 1, 1, 12, 0, 0), 2451545.0)
}

///|
test "JD anchor: MJD epoch" {
  // 1858-11-17 00:00 UTC is JD 2400000.5 = MJD 0
  assert_eq(@skycal.julian_date(1858, 11, 17, 0, 0, 0), 2400000.5)
  assert_eq(@skycal.to_mjd(2400000.5), 0.0)
  assert_eq(@skycal.from_mjd(0.0), 2400000.5)
}

///|
test "JD anchor: 2026-06-21 midnight" {
  assert_eq(@skycal.julian_date(2026, 6, 21, 0, 0, 0), 2461212.5)
}

///|
test "JD round trip across epochs" {
  let dates = [
    (1600, 2, 29, 3, 14, 15),
    (1858, 11, 17, 0, 0, 0),
    (1987, 1, 1, 0, 0, 0),
    (2000, 2, 29, 12, 34, 56),
    (2026, 11, 23, 9, 30, 1),
    (2100, 3, 1, 23, 59, 59),
  ]
  for d in dates {
    let jd = @skycal.julian_date(d.0, d.1, d.2, d.3, d.4, d.5)
    let back = @skycal.jd_to_datetime(jd)
    assert_eq(back.0, d.0)
    assert_eq(back.1, d.1)
    assert_eq(back.2, d.2)
    assert_eq(back.3, d.3)
    assert_eq(back.4, d.4)
    assert_eq(back.5, d.5)
  }
}

///|
test "leap year handling" {
  // 1900 is not a leap year (century rule), 2000 is
  assert_eq(
    @skycal.julian_date(1900, 3, 1, 0, 0, 0) -
    @skycal.julian_date(1900, 2, 28, 0, 0, 0),
    1.0,
  )
  assert_eq(
    @skycal.julian_date(2000, 3, 1, 0, 0, 0) -
    @skycal.julian_date(2000, 2, 28, 0, 0, 0),
    2.0,
  )
}

///|
test "angle normalization" {
  assert_eq(@skycal.normalize_deg(370.0), 10.0)
  assert_eq(@skycal.normalize_deg(-10.0), 350.0)
  assert_eq(@skycal.wrap_deg(190.0), -170.0)
  assert_eq(@skycal.wrap_deg(-190.0), 170.0)
  assert_eq(@skycal.wrap_deg(360.0), 0.0)
}

///|
test "julian centuries at J2000" {
  assert_eq(@skycal.julian_centuries(2451545.0), 0.0)
  assert_eq(@skycal.julian_centuries(2451545.0 + 36525.0), 1.0)
}
