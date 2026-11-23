///|
// Solar term tests. Physical anchors: equinoxes/solstices and the
// self-consistency of the crossing (longitude at the solved instant must
// match the target within a fraction of a degree ≈ seconds of time).

fn approx5(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() < tol
}

///|
test "solar term dates land near Gregorian expectations" {
  // 2026: spring equinox ≈ Mar 20, summer solstice ≈ Jun 21,
  // winter solstice ≈ Dec 21-22
  let terms = @skycal.solar_terms(2026)
  assert_eq(terms.length(), 24)
  let eq = terms[0]
  let (y, m, d, _, _, _) = @skycal.jd_to_datetime(eq.get_jd())
  assert_eq(y, 2026)
  assert_eq(m, 3)
  assert_true(d >= 19 && d <= 21)
  let solstice = terms[6]
  let (y2, m2, d2, _, _, _) = @skycal.jd_to_datetime(solstice.get_jd())
  assert_eq(y2, 2026)
  assert_eq(m2, 6)
  assert_true(d2 >= 20 && d2 <= 22)
  let winter = terms[18]
  let (_, m3, d3, _, _, _) = @skycal.jd_to_datetime(winter.get_jd())
  assert_eq(m3, 12)
  assert_true(d3 >= 21 && d3 <= 23)
}

///|
test "longitude self-consistency at every term" {
  // At the solved instant the sun's apparent longitude must equal k*15°
  // to within 0.01° (≈ 15 seconds of time). Compare through wrap_deg so
  // that 360° ≡ 0°.
  let terms = @skycal.solar_terms(2026)
  for t in terms {
    let expected = t.get_index().to_double() * 15.0
    let diff = @skycal.wrap_deg(
      @skycal.solar_apparent_longitude(t.get_jd()) - expected,
    )
    assert_true(approx5(diff, 0.0, 0.01))
  }
}

///|
test "adjacent terms are ~15.2 days apart" {
  // Sort by time first: terms with k=19..23 fall in Jan/Feb/Mar, so the
  // longitude-index order is not the calendar order
  let terms = @skycal.solar_terms(2026)
  let by_time = terms.copy()
  by_time.sort_by(fn(a, b) { if a.get_jd() < b.get_jd() { -1 } else { 1 } })
  for i in 0..<23 {
    let gap = (by_time[i + 1].get_jd() - by_time[i].get_jd()) * 1440.0
    // Between 13 and 17 days depending on the season (Kepler's second law)
    assert_true(gap > 13.0 * 1440.0 - 60.0 && gap < 17.0 * 1440.0 + 60.0)
  }
}

///|
test "equinox/solstice gaps reflect Kepler" {
  // March equinox → June solstice should be longer than Sep equinox →
  // Dec solstice (Earth near aphelion in July)
  let terms = @skycal.solar_terms(2026)
  let spring_to_summer = terms[6].get_jd() - terms[0].get_jd()
  let autumn_to_winter = terms[18].get_jd() - terms[12].get_jd()
  assert_true(spring_to_summer > autumn_to_winter)
}

///|
test "term names" {
  assert_eq(@skycal.solar_term_name(0), "春分")
  assert_eq(@skycal.solar_term_name(6), "夏至")
  assert_eq(@skycal.solar_term_name(18), "冬至")
  assert_eq(@skycal.solar_term_name(21), "立春")
}

///|
test "determinism of solar terms" {
  let a = @skycal.solar_terms(2027)
  let b = @skycal.solar_terms(2027)
  assert_eq(a[0].get_jd(), b[0].get_jd())
  assert_eq(a[18].get_jd(), b[18].get_jd())
}
