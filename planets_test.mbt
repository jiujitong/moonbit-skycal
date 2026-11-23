///|
// Planetary position tests. No single-instant published anchors are used;
// instead the tests rely on hard physical invariants that are robust to the
// ~0.5° accuracy of the JPL mean elements.

///|
test "geocentric distance ranges over five years" {
  // Geocentric distance bounds (inner planets dip below 1 AU at inferior
  // conjunction; outer planets approach 1 AU less their heliocentric range)
  let jd0 = @skycal.julian_date(2026, 1, 1, 0, 0, 0)
  for day in 0..<365 {
    let jd = jd0 + day.to_double() * 5.0 // 5-year sample at 5-day steps
    let mercury = @skycal.planet_position(@skycal.mercury(), jd)
    assert_true(mercury.get_distance() > 0.4 && mercury.get_distance() < 1.55)
    let venus = @skycal.planet_position(@skycal.venus(), jd)
    assert_true(venus.get_distance() > 0.24 && venus.get_distance() < 1.75)
    let mars = @skycal.planet_position(@skycal.mars(), jd)
    assert_true(mars.get_distance() > 0.3 && mars.get_distance() < 2.7)
    let jupiter = @skycal.planet_position(@skycal.jupiter(), jd)
    assert_true(jupiter.get_distance() > 3.9 && jupiter.get_distance() < 6.5)
    let saturn = @skycal.planet_position(@skycal.saturn(), jd)
    assert_true(saturn.get_distance() > 7.9 && saturn.get_distance() < 11.1)
  }
}

///|
test "venus elongation never exceeds ~48 degrees" {
  // Venus never strays more than about 47° from the Sun in the sky
  let mut max_elong = 0.0
  for day in 0..<73 {
    let jd = @skycal.julian_date(2026, 1, 1, 0, 0, 0) + day.to_double() * 5.0
    let venus = @skycal.planet_position(@skycal.venus(), jd)
    let sun = @skycal.solar_apparent_longitude(jd)
    let elong = @skycal.wrap_deg(venus.get_longitude() - sun).abs()
    if elong > max_elong {
      max_elong = elong
    }
  }
  assert_true(max_elong > 40.0 && max_elong < 48.5)
}

///|
test "saturn moves ~12 deg per year along the ecliptic" {
  let s2026 = @skycal.planet_position(
    @skycal.saturn(),
    @skycal.julian_date(2026, 1, 1, 0, 0, 0),
  )
  let s2027 = @skycal.planet_position(
    @skycal.saturn(),
    @skycal.julian_date(2027, 1, 1, 0, 0, 0),
  )
  let advance = @skycal.normalize_deg(
    s2027.get_longitude() - s2026.get_longitude(),
  )
  // Saturn: 360° / 29.5 yr ≈ 12.2°/yr
  assert_true(advance > 10.0 && advance < 14.5)
}

///|
test "jupiter drifts ~34 deg per year along the ecliptic" {
  // Geocentric longitude advances as oppositions shift later each year
  // (~34 days) → ~34°/yr; measured 35.1° for 2026→2027
  let j2026 = @skycal.planet_position(
    @skycal.jupiter(),
    @skycal.julian_date(2026, 1, 1, 0, 0, 0),
  )
  let j2027 = @skycal.planet_position(
    @skycal.jupiter(),
    @skycal.julian_date(2027, 1, 1, 0, 0, 0),
  )
  let advance = @skycal.normalize_deg(
    j2027.get_longitude() - j2026.get_longitude(),
  )
  assert_true(advance > 25.0 && advance < 45.0)
}

///|
test "declination bounded by ecliptic inclination" {
  // Planets never stray more than ~8° from the ecliptic (Mercury 7°)
  let jd = @skycal.julian_date(2026, 6, 15, 0, 0, 0)
  let saturn = @skycal.planet_position(@skycal.saturn(), jd)
  // Saturn's orbital inclination is 2.5°, so |dec| must be far from 90°
  assert_true(
    saturn.get_declination() < 30.0 && saturn.get_declination() > -30.0,
  )
}

///|
test "planet position determinism" {
  let a = @skycal.planet_position(
    @skycal.mars(),
    @skycal.julian_date(2026, 5, 5, 0, 0, 0),
  )
  let b = @skycal.planet_position(
    @skycal.mars(),
    @skycal.julian_date(2026, 5, 5, 0, 0, 0),
  )
  assert_eq(a.get_right_ascension(), b.get_right_ascension())
  assert_eq(a.get_declination(), b.get_declination())
}

///|
test "planet altaz is computable at any site" {
  let pos = @skycal.make_geo(39.9042, 116.4074)
  let (alt, az) = @skycal.planet_altaz(
    @skycal.jupiter(),
    @skycal.julian_date(2026, 11, 23, 12, 0, 0),
    pos,
  )
  assert_true(alt > -90.0 && alt < 90.0 && az >= 0.0 && az < 360.0)
  ignore(alt)
  ignore(az)
}
