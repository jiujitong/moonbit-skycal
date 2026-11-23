///|
// Tests for the high-precision solar events and annual daylight summaries.

fn approx8(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() < tol
}

///|
test "precise rise/set agrees with one-pass within 2 minutes" {
  let pos = @skycal.make_geo(39.9042, 116.4074)
  match
    (
      @skycal.sun_rise_set_precise(2026, 6, 21, pos),
      @skycal.sun_times(2026, 6, 21, pos),
    ) {
    (Some((pr, ps)), Some(t)) => {
      let dr = (pr - t.get_sunrise()).abs() * 1440.0
      let ds = (ps - t.get_sunset()).abs() * 1440.0
      assert_true(dr < 2.0 && ds < 2.0)
    }
    _ => assert_true(false)
  }
}

///|
test "precise rise/set matches USNO Beijing solstice" {
  // Beijing 2026-06-21: sunrise 04:46, sunset 19:46 CST (±1 min tolerance)
  let pos = @skycal.make_geo(39.9042, 116.4074)
  match @skycal.sun_rise_set_precise(2026, 6, 21, pos) {
    Some((rise, set)) => {
      let rise_ref = @skycal.julian_date(2026, 6, 20, 20, 46, 0)
      let set_ref = @skycal.julian_date(2026, 6, 21, 11, 46, 0)
      let tol = 1.0 / 1440.0
      assert_true(approx8(rise, rise_ref, tol))
      assert_true(approx8(set, set_ref, tol))
    }
    None => assert_true(false)
  }
}

///|
test "year daylight for Beijing: longest June 21, shortest Dec 21" {
  let pos = @skycal.make_geo(39.9042, 116.4074)
  let yd = @skycal.year_daylight(2026, pos)
  assert_eq(yd.get_longest_date().0, 6)
  assert_true(yd.get_longest_date().1 >= 20 && yd.get_longest_date().1 <= 22)
  assert_eq(yd.get_shortest_date().0, 12)
  assert_true(yd.get_shortest_date().1 >= 21 && yd.get_shortest_date().1 <= 23)
  // Annual daylight exceeds 4380 h (365 × 12 h) because refraction
  // lengthens every day by ~10-14 min at this latitude
  assert_true(yd.get_total_hours() > 4420.0 && yd.get_total_hours() < 4480.0)
  // No polar conditions at latitude 40°
  assert_eq(yd.get_polar_night_days(), 0)
  assert_eq(yd.get_polar_day_days(), 0)
  // Longest day ≈ 15 h, shortest ≈ 9.3 h
  assert_true(yd.get_longest_day() > 14.5 && yd.get_longest_day() < 15.5)
  assert_true(yd.get_shortest_day() > 8.8 && yd.get_shortest_day() < 9.8)
}

///|
test "year daylight at high latitude shows polar season" {
  // Tromsø, Norway (69.65°N): about 2 months polar night + 2 months
  // midnight sun per year
  let pos = @skycal.make_geo(69.6492, 18.9553)
  let yd = @skycal.year_daylight(2026, pos)
  assert_true(yd.get_polar_night_days() > 40 && yd.get_polar_night_days() < 75)
  assert_true(yd.get_polar_day_days() > 40 && yd.get_polar_day_days() < 75)
  // Annual daylight balance: refraction gain is largest at high latitudes
  // (sun moves slowly near the horizon) → ~4600 h/yr at 69.6°N
  assert_true(yd.get_total_hours() > 4550.0 && yd.get_total_hours() < 4650.0)
}

///|
test "daylight table covers 12 months" {
  let pos = @skycal.make_geo(31.2304, 121.4737) // Shanghai
  let table = @skycal.daylight_table(2026, pos)
  assert_eq(table.length(), 12)
  // Summer solstice month daylight > winter solstice month at 31°N
  let jun = table[5]
  let dec = table[11]
  match (jun.1, dec.1) {
    (Some(a), Some(b)) => assert_true(a > b)
    _ => assert_true(false)
  }
}

///|
test "leap year day counting" {
  assert_eq(@skycal.days_in_month(2026, 2), 28)
  assert_eq(@skycal.days_in_month(2028, 2), 29)
  assert_eq(@skycal.days_in_month(2000, 2), 29)
  assert_eq(@skycal.days_in_month(1900, 2), 28)
  assert_eq(@skycal.days_in_month(2026, 4), 30)
  assert_eq(@skycal.days_in_month(2026, 1), 31)
}
