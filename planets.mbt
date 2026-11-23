///|
// Planetary positions: Mercury, Venus, Mars, Jupiter and Saturn, using the
// Keplerian mean elements published by JPL (SSD, "Approximate Positions of
// the Planets", Table 1, valid 1800-2050 AD with ~0.5° typical accuracy).
//
// Pipeline: mean elements → Kepler equation → heliocentric ecliptic
// coordinates → subtract Earth → geocentric equatorial RA/dec.

///|
// Planets supported by the low-precision ephemeris.
pub enum Planet {
  Mercury
  Venus
  Mars
  Jupiter
  Saturn
}

// Value constructors (Planet variants are read-only outside the package).
pub fn mercury() -> Planet {
  Mercury
}

pub fn venus() -> Planet {
  Venus
}

pub fn mars() -> Planet {
  Mars
}

pub fn jupiter() -> Planet {
  Jupiter
}

pub fn saturn() -> Planet {
  Saturn
}

// Mean elements at J2000: (a AU, e, I deg, L deg, long.peri deg, long.node
// deg) and their per-century rates. JPL Table 1 (1800-2050).
priv struct PlanetElements {
  a : Double
  adot : Double
  e : Double
  edot : Double
  i : Double
  idot : Double
  l : Double
  ldot : Double
  peri : Double
  peridot : Double
  node : Double
  nodedot : Double
}

fn planet_elements(p : Planet) -> PlanetElements {
  match p {
    Mercury =>
      PlanetElements::{
        a: 0.38709927, adot: 0.00000037, e: 0.20563593, edot: 0.00001906,
        i: 7.00497902, idot: -0.00594749, l: 252.25032350, ldot: 149472.67411175,
        peri: 77.45779628, peridot: 0.16047689, node: 48.33076593, nodedot: -0.12534081,
      }
    Venus =>
      PlanetElements::{
        a: 0.72333566, adot: 0.00000390, e: 0.00677672, edot: -0.00004107,
        i: 3.39467605, idot: -0.00078890, l: 181.97909950, ldot: 58517.81538729,
        peri: 131.60246718, peridot: 0.00268329, node: 76.67984255, nodedot: -0.27769418,
      }
    Mars =>
      PlanetElements::{
        a: 1.52371034, adot: 0.00001847, e: 0.09339410, edot: 0.00007882,
        i: 1.84969142, idot: -0.00813131, l: -4.55343205, ldot: 19140.30268499,
        peri: -23.94362959, peridot: 0.44441088, node: 49.55953891, nodedot: -0.29257343,
      }
    Jupiter =>
      PlanetElements::{
        a: 5.20288700, adot: -0.00011607, e: 0.04838624, edot: -0.00013253,
        i: 1.30439695, idot: -0.00183714, l: 34.39644051, ldot: 3034.74612775,
        peri: 14.72847983, peridot: 0.21252668, node: 100.47390909, nodedot: 0.20469106,
      }
    Saturn =>
      PlanetElements::{
        a: 9.53667594, adot: -0.00125060, e: 0.05386179, edot: -0.00050991,
        i: 2.48599187, idot: 0.00193609, l: 49.95924223, ldot: 1222.49362201,
        peri: 92.59887831, peridot: -0.41897216, node: 113.66242448, nodedot: -0.28867794,
      }
  }
}

// Earth (EM barycentre) elements for the geocentric conversion.
let earth_elements : PlanetElements = PlanetElements::{
  a: 1.00000261, adot: 0.00000562, e: 0.01671123, edot: -0.00004392,
  i: -0.00001531, idot: -0.01294668, l: 100.46457166, ldot: 35999.37244981,
  peri: 102.93768193, peridot: 0.32327363, node: 0.0, nodedot: 0.0,
}

///|
// Heliocentric ecliptic coordinates of a planet: longitude, latitude
// (degrees) and distance (AU).
priv struct Heliocentric {
  lon : Double
  lat : Double
  dist : Double
}

///|
// Solves Kepler's equation M = E - e*sin(E) (all radians) with Newton
// iterations. Converges in a few steps for planetary eccentricities.
fn solve_kepler(m_rad : Double, e : Double) -> Double {
  let mut err = 1.0
  let mut ecc_anom = m_rad + e * @math.sin(m_rad)
  for _ in 0..<12 {
    err = ecc_anom - e * @math.sin(ecc_anom) - m_rad
    ecc_anom = ecc_anom - err / (1.0 - e * @math.cos(ecc_anom))
    if err.abs() < 0.00000001 {
      break
    }
  }
  ecc_anom
}

// Heliocentric ecliptic position from Keplerian elements at time t
// (Julian centuries since J2000).
fn heliocentric(el : PlanetElements, t : Double) -> Heliocentric {
  let a = el.a + el.adot * t
  let e = el.e + el.edot * t
  let inc = deg2rad(el.i + el.idot * t)
  let l = wrap_deg(el.l + el.ldot * t)
  let peri = wrap_deg(el.peri + el.peridot * t)
  let node = wrap_deg(el.node + el.nodedot * t)
  // Mean anomaly (degrees) → Kepler solve (radians)
  let m = wrap_deg(l - peri)
  let ecc_anom = solve_kepler(deg2rad(m), e)
  // True anomaly and radius
  let xv = a * (@math.cos(ecc_anom) - e)
  let yv = a * (1.0 - e * e).sqrt() * @math.sin(ecc_anom)
  let v = atan2_deg(yv, xv) // degrees
  let r = (xv * xv + yv * yv).sqrt()
  // Argument of latitude (degrees), then heliocentric ecliptic coordinates
  let u = v + (peri - node)
  let lon = normalize_deg(node + atan2_deg(sin_deg(u) * cos_deg(rad2deg(inc)), cos_deg(u)))
  let lat = asin_deg(sin_deg(u) * sin_deg(rad2deg(inc)))
  Heliocentric::{ lon, lat, dist: r }
}

// Converts heliocentric ecliptic (planet, earth) to geocentric ecliptic
// longitude/latitude/distance.
fn geocentric_from_heliocentric(p : Heliocentric, earth : Heliocentric) -> Heliocentric {
  // Rotate to the same frame: rectangular ecliptic coordinates
  let px = p.dist * cos_deg(p.lat) * cos_deg(p.lon)
  let py = p.dist * cos_deg(p.lat) * sin_deg(p.lon)
  let pz = p.dist * sin_deg(p.lat)
  let ex = earth.dist * cos_deg(earth.lat) * cos_deg(earth.lon)
  let ey = earth.dist * cos_deg(earth.lat) * sin_deg(earth.lon)
  let ez = earth.dist * sin_deg(earth.lat)
  let dx = px - ex
  let dy = py - ey
  let dz = pz - ez
  let dist = (dx * dx + dy * dy + dz * dz).sqrt()
  let lon = normalize_deg(atan2_deg(dy, dx))
  let lat = atan2_deg(dz, (dx * dx + dy * dy).sqrt())
  Heliocentric::{ lon, lat, dist }
}

///|
// Geocentric equatorial position of a planet: RA, declination, distance in
// AU and ecliptic longitude. Accuracy ≈ 0.5° (JPL mean elements, 1800-2050).
pub struct PlanetPosition {
  right_ascension : Double
  declination : Double
  distance : Double
  longitude : Double
}

pub fn PlanetPosition::get_right_ascension(self : PlanetPosition) -> Double {
  self.right_ascension
}

pub fn PlanetPosition::get_declination(self : PlanetPosition) -> Double {
  self.declination
}

pub fn PlanetPosition::get_distance(self : PlanetPosition) -> Double {
  self.distance
}

pub fn PlanetPosition::get_longitude(self : PlanetPosition) -> Double {
  self.longitude
}

pub fn planet_position(p : Planet, jd : Double) -> PlanetPosition {
  let t = julian_centuries(jd)
  let helio = heliocentric(planet_elements(p), t)
  let earth = heliocentric(earth_elements, t)
  let geo = geocentric_from_heliocentric(helio, earth)
  let (ra, dec) = ecliptic_to_equatorial(geo.lon, geo.lat, jd)
  PlanetPosition::{
    right_ascension: ra,
    declination: dec,
    distance: geo.dist,
    longitude: geo.lon,
  }
}

///|
// Apparent altitude and azimuth of a planet at instant jd from pos
// (geometric; add refract() if display-level accuracy is needed).
pub fn planet_altaz(p : Planet, jd : Double, pos : GeoPos) -> (Double, Double) {
  let pp = planet_position(p, jd)
  equatorial_to_horizontal(pp.right_ascension, pp.declination, jd, pos)
}
