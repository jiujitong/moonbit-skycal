///|
// Lunar phase tests, anchored on Meeus reference values and physical
// invariants.

fn approx3(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() < tol
}

///|
test "new moon anchor (Meeus): 2000-01-06 18:14 UTC" {
  // JD 2451550.26 is the reference new moon used by the algorithm
  let moon = @skycal.moon_phase(2451550.26)
  assert_true(moon.get_phase() is @skycal.NewMoon)
  assert_true(
    moon.get_age_days() < 1.0 ||
    moon.get_age_days() > @skycal.SYNODIC_MONTH - 1.0,
  )
  assert_true(moon.get_illumination() < 0.05)
}

///|
test "full moon at mid-cycle" {
  // 2000-01-21 23:22 UTC full moon (Meeus): age ≈ 15.2 days, illumination ≈ 1
  let moon = @skycal.moon_phase(@skycal.julian_date(2000, 1, 21, 23, 22, 0))
  assert_true(moon.get_phase() is @skycal.FullMoon)
  assert_true(moon.get_illumination() > 0.95)
  assert_true(approx3(moon.get_age_days(), 15.2, 1.5))
}

///|
test "first quarter illumination" {
  // Quarter cycle after the reference new moon: ~50% illuminated, waxing
  let q = @skycal.moon_phase(2451550.26 + @skycal.SYNODIC_MONTH / 4.0)
  assert_true(q.get_phase() is @skycal.FirstQuarter)
  assert_true(q.get_illumination() > 0.35 && q.get_illumination() < 0.65)
}

///|
test "last quarter illumination" {
  let q = @skycal.moon_phase(2451550.26 + @skycal.SYNODIC_MONTH * 3.0 / 4.0)
  assert_true(q.get_phase() is @skycal.LastQuarter)
  assert_true(q.get_illumination() > 0.35 && q.get_illumination() < 0.65)
}

///|
test "illumination and age bounds" {
  // Daily samples across ~3 years stay within physical bounds
  for day in 0..<1000 {
    let jd = @skycal.julian_date(2026, 1, 1, 0, 0, 0) + day.to_double()
    let moon = @skycal.moon_phase(jd)
    assert_true(
      moon.get_illumination() >= 0.0 && moon.get_illumination() <= 1.0,
    )
    assert_true(
      moon.get_age_days() >= 0.0 && moon.get_age_days() <= @skycal.SYNODIC_MONTH,
    )
  }
}

///|
test "phase enum agrees with illumination" {
  // Half a cycle after new: full moon with near-total illumination
  let full = @skycal.moon_phase(2451550.26 + @skycal.SYNODIC_MONTH / 2.0)
  assert_true(full.get_phase() is @skycal.FullMoon)
  assert_true(full.get_illumination() > 0.95)
  // One full cycle later: new moon again
  let new = @skycal.moon_phase(2451550.26 + @skycal.SYNODIC_MONTH)
  assert_true(new.get_phase() is @skycal.NewMoon)
  assert_true(new.get_illumination() < 0.05)
}

///|
test "phase names" {
  let new = @skycal.moon_phase(2451550.26)
  assert_eq(new.get_phase().name(), "New Moon")
  let full = @skycal.moon_phase(2451550.26 + @skycal.SYNODIC_MONTH / 2.0)
  assert_eq(full.get_phase().name(), "Full Moon")
  let lq = @skycal.moon_phase(2451550.26 + @skycal.SYNODIC_MONTH * 3.0 / 4.0)
  assert_eq(lq.get_phase().name(), "Last Quarter")
}

///|
test "new_moon_jd cycle regression" {
  // Every predicted new moon evaluates back to (approximately) NewMoon
  for k in 0..<25 {
    let jd = @skycal.new_moon_jd(k)
    let moon = @skycal.moon_phase(jd)
    assert_true(
      moon.get_phase() is @skycal.NewMoon ||
      approx3(moon.get_age_days(), 0.0, 0.6) ||
      approx3(moon.get_age_days(), @skycal.SYNODIC_MONTH, 0.6),
    )
  }
}

///|
test "moon phase determinism" {
  let jd = @skycal.julian_date(2026, 11, 23, 12, 0, 0)
  let a = @skycal.moon_phase(jd)
  let b = @skycal.moon_phase(jd)
  assert_eq(a.get_illumination(), b.get_illumination())
  assert_eq(a.get_age_days(), b.get_age_days())
}
