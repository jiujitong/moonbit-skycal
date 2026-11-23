///|
// Solar algorithm tests: physical invariants, known geometry and the
// cross-checkable Beijing / New York summer solstice values (compare with
// USNO or NOAA published tables; ±2 minutes tolerance).

fn approx(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() < tol
}

///|
test "declination at solstices and equinoxes" {
  // Summer solstice 2026-06-21: declination ≈ +23.44°
  let pos_jun = @skycal.sun_position(
    @skycal.julian_date(2026, 6, 21, 12, 0, 0),
    @skycal.make_geo(0.0, 0.0),
  )
  assert_true(approx(pos_jun.get_declination(), 23.44, 0.1))
  // Winter solstice 2026-12-21: declination ≈ -23.44°
  let pos_dec = @skycal.sun_position(
    @skycal.julian_date(2026, 12, 21, 12, 0, 0),
    @skycal.make_geo(0.0, 0.0),
  )
  assert_true(approx(pos_dec.get_declination(), -23.44, 0.1))
  // Equinox 2026-03-20: declination ≈ 0
  let pos_mar = @skycal.sun_position(
    @skycal.julian_date(2026, 3, 20, 12, 0, 0),
    @skycal.make_geo(0.0, 0.0),
  )
  assert_true(approx(pos_mar.get_declination(), 0.0, 0.2))
}

///|
test "sun altitude at Beijing solar noon, summer solstice" {
  // Beijing lat 39.90°, sun declination 23.44° → noon altitude ≈ 73.5°
  let pos = @skycal.make_geo(39.9042, 116.4074)
  let p = @skycal.sun_position(@skycal.julian_date(2026, 6, 21, 4, 16, 0), pos)
  assert_true(approx(p.get_altitude(), 73.5, 1.0))
  // Sun culminates due south in the northern hemisphere: azimuth ≈ 180°
  assert_true(approx(p.get_azimuth(), 180.0, 3.0))
}

///|
test "Beijing summer solstice 2026 matches published tables" {
  // USNO/NOAA reference: sunrise 04:46, solar noon 12:16, sunset 19:46 CST
  let pos = @skycal.make_geo(39.9042, 116.4074)
  match @skycal.sun_times(2026, 6, 21, pos) {
    Some(times) => {
      let rise_ref = @skycal.julian_date(2026, 6, 20, 20, 46, 0) // 04:46 CST = 20:46 UTC
      let noon_ref = @skycal.julian_date(2026, 6, 21, 4, 16, 0) // 12:16 CST = 04:16 UTC
      let set_ref = @skycal.julian_date(2026, 6, 21, 11, 46, 0) // 19:46 CST = 11:46 UTC
      let tol = 2.0 / 1440.0 // ±2 minutes
      assert_true(approx(times.get_sunrise(), rise_ref, tol))
      assert_true(approx(times.get_solar_noon(), noon_ref, tol))
      assert_true(approx(times.get_sunset(), set_ref, tol))
    }
    None => assert_true(false)
  }
}

///|
test "rise < noon < set across seasons and hemispheres" {
  let beijing = @skycal.make_geo(39.9042, 116.4074)
  let ny = @skycal.make_geo(40.7128, -74.0060)
  let dates = [(1, 1), (3, 20), (6, 21), (9, 23), (12, 21)]
  for d in dates {
    let month = d.0
    let day = d.1
    match @skycal.sun_times(2026, month, day, beijing) {
      Some(t) =>
        assert_true(
          t.get_sunrise() < t.get_solar_noon() &&
          t.get_solar_noon() < t.get_sunset(),
        )
      None => assert_true(false)
    }
    match @skycal.sun_times(2026, month, day, ny) {
      Some(t) =>
        assert_true(
          t.get_sunrise() < t.get_solar_noon() &&
          t.get_solar_noon() < t.get_sunset(),
        )
      None => assert_true(false)
    }
  }
}

///|
test "daylight duration at key latitudes" {
  let beijing = @skycal.make_geo(39.9042, 116.4074)
  // Beijing summer solstice daylight ≈ 15h00m (USNO: 15h01m)
  match @skycal.sun_times(2026, 6, 21, beijing) {
    Some(t) => assert_true(approx(t.daylight_minutes(), 900.0, 10.0))
    None => assert_true(false)
  }
  // Beijing winter solstice daylight ≈ 9h19m
  match @skycal.sun_times(2026, 12, 21, beijing) {
    Some(t) => assert_true(approx(t.daylight_minutes(), 559.0, 10.0))
    None => assert_true(false)
  }
  // Equator at equinox: daylight ≈ 12h
  let quito = @skycal.make_geo(0.0, -78.47)
  match @skycal.sun_times(2026, 3, 20, quito) {
    Some(t) => assert_true(approx(t.daylight_minutes(), 720.0, 12.0))
    None => assert_true(false)
  }
}

///|
test "polar day and night return None" {
  let north = @skycal.make_geo(89.0, 0.0)
  // Polar day: sun never crosses the 90.833° zenith band
  assert_true(@skycal.sun_times(2026, 6, 21, north) is None)
  // Polar night
  assert_true(@skycal.sun_times(2026, 12, 21, north) is None)
}

///|
test "golden hours ordering and containment" {
  let beijing = @skycal.make_geo(39.9042, 116.4074)
  match
    (
      @skycal.golden_hours(2026, 6, 21, beijing),
      @skycal.civil_twilight(2026, 6, 21, beijing),
    ) {
    (Some(g), Some(tw)) => {
      assert_true(g.get_morning_start() < g.get_morning_end())
      assert_true(g.get_morning_end() < g.get_evening_start())
      assert_true(g.get_evening_start() < g.get_evening_end())
      // The +6° golden boundary lies inside the -6° twilight window
      assert_true(g.get_morning_start() >= tw.0 && g.get_evening_end() <= tw.1)
    }
    _ => assert_true(false)
  }
}

///|
test "determinism of sun_position" {
  let pos = @skycal.make_geo(31.2304, 121.4737) // Shanghai
  let jd = @skycal.julian_date(2026, 11, 23, 6, 30, 0)
  let a = @skycal.sun_position(jd, pos)
  let b = @skycal.sun_position(jd, pos)
  assert_eq(a.get_altitude(), b.get_altitude())
  assert_eq(a.get_azimuth(), b.get_azimuth())
  assert_eq(a.get_declination(), b.get_declination())
}

///|
test "sun below horizon at night" {
  // Beijing 2026-11-23 23:00 local (15:00 UTC): sun well below horizon
  let night = @skycal.sun_position(
    @skycal.julian_date(2026, 11, 23, 15, 0, 0),
    @skycal.make_geo(39.9042, 116.4074),
  )
  assert_true(night.get_altitude() < -20.0)
}
