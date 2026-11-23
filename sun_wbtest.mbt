///|
// Whitebox tests: internal solar parameter checks that need access to
// private functions.

fn approx2(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() < tol
}

///|
test "equation of time range across the year" {
  // EoT is bounded by about ±16.5 minutes; peaks in early November and
  // dips in mid-February (NOAA reference values: ≈ +16.4 / -14.2 min).
  let mut max_eot = -1000.0
  let mut min_eot = 1000.0
  for day in 0..<365 {
    let jd = julian_date(2026, 1, 1, 12, 0, 0) + day.to_double()
    let eot = solar_params(jd).equation_of_time
    if eot > max_eot {
      max_eot = eot
    }
    if eot < min_eot {
      min_eot = eot
    }
  }
  assert_true(max_eot < 17.0 && max_eot > 15.5)
  assert_true(min_eot > -16.5 && min_eot < -13.0)
}

///|
test "declination bounds across the year" {
  // Declination stays within ±23.44° (axial tilt) all year
  let mut max_decl = -100.0
  let mut min_decl = 100.0
  for day in 0..<365 {
    let jd = julian_date(2026, 1, 1, 0, 0, 0) + day.to_double()
    let d = solar_params(jd).declination
    if d > max_decl {
      max_decl = d
    }
    if d < min_decl {
      min_decl = d
    }
  }
  assert_true(max_decl > 23.0 && max_decl < 23.6)
  assert_true(min_decl < -23.0 && min_decl > -23.6)
}

///|
test "right ascension increases monotonically over the year" {
  // The sun's right ascension advances ~360° per tropical year
  let ra_start = solar_params(julian_date(2026, 1, 1, 0, 0, 0)).right_ascension
  let ra_end = solar_params(julian_date(2027, 1, 1, 0, 0, 0)).right_ascension
  let advance = normalize_deg(ra_end - ra_start)
  assert_true(approx2(advance, 360.0, 1.5))
}
