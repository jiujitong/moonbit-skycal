///|
// Observing basics: sidereal time, coordinate conversions and atmospheric
// refraction. Shared by solar, lunar and planetary position code.

///|
// Greenwich Mean Sidereal Time in degrees at instant jd (Meeus 12.4).
pub fn gmst(jd : Double) -> Double {
  let t = julian_centuries(jd)
  normalize_deg(
    280.46061837 +
    360.98564736629 * (jd - 2451545.0) +
    0.000387933 * t * t -
    t * t * t / 38710000.0,
  )
}

// Local sidereal time in degrees for east longitude lon (degrees).

///|
pub fn local_sidereal_time(jd : Double, lon : Double) -> Double {
  normalize_deg(gmst(jd) + lon)
}

// Converts equatorial (RA, dec) to horizontal (altitude, azimuth) at instant
// jd from pos. Geometric values: no refraction, no parallax. Azimuth is
// measured from true north, clockwise (0 = N, 90 = E, 180 = S).

///|
pub fn equatorial_to_horizontal(
  ra : Double,
  dec : Double,
  jd : Double,
  pos : GeoPos,
) -> (Double, Double) {
  let ha = wrap_deg(local_sidereal_time(jd, pos.lon) - ra)
  let sin_alt = sin_deg(pos.lat) * sin_deg(dec) +
    cos_deg(pos.lat) * cos_deg(dec) * cos_deg(ha)
  let alt = asin_deg(clamp(sin_alt, -1.0, 1.0))
  let cos_az = (sin_deg(dec) - sin_deg(alt) * sin_deg(pos.lat)) /
    (cos_deg(alt) * cos_deg(pos.lat))
  let mut az = acos_deg(clamp(cos_az, -1.0, 1.0))
  if ha > 0.0 {
    az = 360.0 - az
  }
  (alt, az)
}

// Inverse: converts horizontal (altitude, azimuth) to equatorial (RA, dec)
// at instant jd from pos. Useful for pointing checks and star lookup.

///|
pub fn horizontal_to_equatorial(
  alt : Double,
  az : Double,
  jd : Double,
  pos : GeoPos,
) -> (Double, Double) {
  let ha0 = wrap_deg(local_sidereal_time(jd, pos.lon))
  // Standard formulas:
  // sin(dec) = sin(lat) sin(alt) + cos(lat) cos(alt) cos(az)
  let sin_dec = sin_deg(pos.lat) * sin_deg(alt) +
    cos_deg(pos.lat) * cos_deg(alt) * cos_deg(az)
  let dec = asin_deg(clamp(sin_dec, -1.0, 1.0))
  // cos(H) = (sin(alt) - sin(lat) sin(dec)) / (cos(lat) cos(dec))
  let eps = 1.0 / 1000000000000.0
  let cos_h = (sin_deg(alt) - sin_deg(pos.lat) * sin_deg(dec)) /
    (cos_deg(pos.lat) * cos_deg(dec)).max(eps)
  let mut h = acos_deg(clamp(cos_h, -1.0, 1.0))
  // Hour angle sign: sin(HA) = -sin(az) cos(alt) / cos(dec). When negative
  // the object is east of meridian... no: sin(HA) < 0 means HA in (180, 360),
  // i.e. the object has NOT yet passed the meridian (east side). acos returns
  // [0, 180]; flip into (180, 360) when sin(HA) < 0.
  let sin_h_signed = -sin_deg(az) * cos_deg(alt) / cos_deg(dec).max(eps)
  if sin_h_signed < 0.0 {
    h = 360.0 - h
  }
  let ra = normalize_deg(ha0 - wrap_deg(h))
  (ra, dec)
}

///|
// Bennett (1982) atmospheric refraction, degrees, for geometric altitude h
// in degrees. Valid h > -5°; below that refraction is clamped to ~0.42°.
pub fn refract(geometric_alt : Double) -> Double {
  if geometric_alt < -5.0 {
    return 0.42
  }
  let h = geometric_alt
  let r_arcmin = 1.02 / tan_deg(h + 10.3 / (h + 5.11))
  let r = r_arcmin / 60.0
  if r < 0.0 {
    0.0
  } else {
    r
  }
}

///|
fn clamp(x : Double, lo : Double, hi : Double) -> Double {
  if x < lo {
    lo
  } else if x > hi {
    hi
  } else {
    x
  }
}
