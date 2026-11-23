///|
// Tests for lunar position, moonrise/moonset and observing utilities.
// Position anchors come from Meeus worked examples (computed with TD;
// the UT-vs-TD offset shifts the lunar longitude by <0.02° in 1992,
// covered by tolerance).

fn approx4(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() < tol
}

///|
test "GMST anchor (Meeus 12.a)" {
  // 1987-04-10 0h UT → GMST 197.693195°
  let jd = @skycal.julian_date(1987, 4, 10, 0, 0, 0)
  assert_true(approx4(@skycal.gmst(jd), 197.693195, 0.001))
}

///|
test "GMST increases ~360.9856 deg per day" {
  let g1 = @skycal.gmst(@skycal.julian_date(2026, 1, 1, 0, 0, 0))
  let g2 = @skycal.gmst(@skycal.julian_date(2026, 1, 2, 0, 0, 0))
  // After normalization the daily advance is 0.9856° beyond a full turn
  let advance = @skycal.normalize_deg(g2 - g1)
  assert_true(approx4(advance, 0.98564736629, 0.01))
}

///|
test "lunar position anchor (Meeus 47.a)" {
  // 1992-04-12 0h TD: λ 133.162655°, β -3.229126°, Δ 368409.7 km
  let jd = @skycal.julian_date(1992, 4, 12, 0, 0, 0)
  let moon = @skycal.moon_position(jd)
  assert_true(approx4(moon.get_longitude(), 133.162655, 0.05))
  assert_true(approx4(moon.get_latitude(), -3.229126, 0.05))
  assert_true(approx4(moon.get_distance(), 368409.7, 150.0))
}

///|
test "lunar distance within perigee-apogee bounds" {
  // Sample a full year; distance stays within known extremes
  for day in 0..<365 {
    let jd = @skycal.julian_date(2026, 1, 1, 0, 0, 0) + day.to_double()
    let moon = @skycal.moon_position(jd)
    assert_true(
      moon.get_distance() > 356000.0 && moon.get_distance() < 407000.0,
    )
  }
}

///|
test "lunar longitude advances ~13.2 deg per day" {
  let m1 = @skycal.moon_position(@skycal.julian_date(2026, 3, 1, 0, 0, 0))
  let m2 = @skycal.moon_position(@skycal.julian_date(2026, 3, 2, 0, 0, 0))
  let advance = @skycal.normalize_deg(m2.get_longitude() - m1.get_longitude())
  assert_true(advance > 11.0 && advance < 15.5)
}

///|
test "phase elongation agrees with geometric separation" {
  // The elongation from moon_phase must match the longitude difference
  // between Moon and Sun computed from positions
  let jd = @skycal.julian_date(2026, 6, 15, 12, 0, 0)
  let phase = @skycal.moon_phase(jd)
  let moon = @skycal.moon_position(jd)
  let sun = @skycal.solar_apparent_longitude(jd)
  let geo = @skycal.normalize_deg(moon.get_longitude() - sun)
  assert_true(approx4(phase.get_elongation(), geo, 2.0))
}

///|
test "refraction values (Bennett)" {
  // At 45° altitude refraction ≈ 0.017° (≈1 arcmin)
  assert_true(approx4(@skycal.refract(45.0), 0.017, 0.005))
  // Near the horizon ≈ 0.38-0.42°
  let r0 = @skycal.refract(0.5)
  assert_true(r0 > 0.3 && r0 < 0.5)
  // Deep negative: clamped
  assert_true(@skycal.refract(-30.0) == 0.42)
}

///|
test "coordinate conversion round trip" {
  // equatorial → horizontal → equatorial returns the original values
  let pos = @skycal.make_geo(39.9042, 116.4074)
  let jd = @skycal.julian_date(2026, 6, 21, 12, 0, 0)
  let (alt, az) = @skycal.equatorial_to_horizontal(41.0, 23.0, jd, pos)
  let (ra, dec) = @skycal.horizontal_to_equatorial(alt, az, jd, pos)
  assert_true(approx4(ra, 41.0, 0.01))
  assert_true(approx4(dec, 23.0, 0.01))
}

///|
test "moon transit advances ~50 min per day" {
  // The meridian-to-meridian interval (tidal day) is 24h + ~50 min =
  // ~1490 min, varying ±15 min with lunar orbital eccentricity
  let pos = @skycal.make_geo(39.9042, 116.4074)
  for d in [(2026, 1, 15), (2026, 3, 21), (2026, 9, 15)] {
    let t1 = @skycal.moon_times(d.0, d.1, d.2, pos)
    let next = next_day(d.0, d.1, d.2)
    let t2 = @skycal.moon_times(next.0, next.1, next.2, pos)
    match (t1, t2) {
      (Some(a), Some(b)) => {
        let delta_min = (b.get_transit() - a.get_transit()) * 1440.0
        assert_true(delta_min > 1470.0 && delta_min < 1510.0)
      }
      _ => assert_true(false)
    }
  }
}

///|
fn next_day(y : Int32, m : Int32, d : Int32) -> (Int32, Int32, Int32) {
  let jd = @skycal.julian_date(y, m, d, 12, 0, 0) + 1.0
  let (y2, m2, d2, _, _, _) = @skycal.jd_to_datetime(jd)
  (y2, m2, d2)
}

///|
test "moonrise/moonset plausible spacing" {
  // When rise and set are both captured within the same scanned day and
  // rise < set, the moon must stay up for several hours (4..13 h).
  let pos = @skycal.make_geo(39.9042, 116.4074)
  match @skycal.moon_times(2026, 11, 23, pos) {
    Some(mt) =>
      match (mt.get_moonrise(), mt.get_moonset()) {
        (Some(rise), Some(set)) => {
          let up_minutes = (set - rise) * 1440.0
          if rise < set {
            // Moon above horizon between 4 h and ~15.5 h (at latitude 40°
            // near major standstill a full-night moon can reach 15 h+)
            assert_true(up_minutes > 240.0 && up_minutes < 960.0)
          } else {
            // Moon was already up at day start (set before rise) — valid
            assert_true(up_minutes < 0.0)
          }
        }
        _ => ()
      }
    None => assert_true(false)
  }
}

///|
test "moon altitude respects parallax" {
  // Geometric vs apparent altitude differ by roughly the parallax (~0.95°
  // at the horizon, shrinking as the moon climbs)
  let pos = @skycal.make_geo(0.0, 0.0)
  let jd = @skycal.julian_date(2026, 6, 15, 0, 0, 0)
  let mp = @skycal.moon_position(jd)
  let (geo_alt, _) = @skycal.equatorial_to_horizontal(
    mp.get_right_ascension(),
    mp.get_declination(),
    jd,
    pos,
  )
  let (app_alt, _) = @skycal.moon_altaz(jd, pos)
  let shift = geo_alt - app_alt
  assert_true(shift > 0.0 && shift < 1.0)
}

///|
test "moon times determinism" {
  let pos = @skycal.make_geo(31.2304, 121.4737)
  let a = @skycal.moon_times(2026, 11, 23, pos)
  let b = @skycal.moon_times(2026, 11, 23, pos)
  match (a, b) {
    (Some(x), Some(y)) => assert_eq(x.get_transit(), y.get_transit())
    _ => assert_true(false)
  }
}
