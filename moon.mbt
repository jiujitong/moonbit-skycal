///|
// Lunar phase calculation. Simplified Meeus approach: the mean elongation of
// the Moon from the Sun with the dominant periodic corrections (subset of
// Meeus, Astronomical Algorithms, Table 47.A). Accuracy: illumination within
// ~1% and phase timing within ~1 hour, sufficient for applications like
// photography planning, tide awareness and calendars.

// Mean synodic month in days (1980-2100 mean value).
pub const SYNODIC_MONTH : Double = 29.530588853

// Reference new moon: 2000-01-06 18:14 UTC (Meeus), JD 2451550.26.

///|
const REFERENCE_NEW_MOON : Double = 2451550.26

// Eight conventional phase names.

///|
pub enum Phase {
  NewMoon
  WaxingCrescent
  FirstQuarter
  WaxingGibbous
  FullMoon
  WaningGibbous
  LastQuarter
  WaningCrescent
}

///|
pub fn Phase::name(self : Phase) -> String {
  match self {
    NewMoon => "New Moon"
    WaxingCrescent => "Waxing Crescent"
    FirstQuarter => "First Quarter"
    WaxingGibbous => "Waxing Gibbous"
    FullMoon => "Full Moon"
    WaningGibbous => "Waning Gibbous"
    LastQuarter => "Last Quarter"
    WaningCrescent => "Waning Crescent"
  }
}

///|
// Lunar phase state at a given instant.
pub struct MoonPhase {
  // Apparent elongation of Moon from Sun, degrees [0, 360). 0 = new,
  // 180 = full.
  elongation : Double
  // Phase angle at the Moon, degrees. 180 = new, 0 = full.
  phase_angle : Double
  // Illuminated fraction of the disk [0, 1].
  illumination : Double
  // Age of the moon in days since the last (approximate) new moon.
  age_days : Double
  phase : Phase
}

///|
pub fn MoonPhase::get_elongation(self : MoonPhase) -> Double {
  self.elongation
}

///|
pub fn MoonPhase::get_phase_angle(self : MoonPhase) -> Double {
  self.phase_angle
}

///|
pub fn MoonPhase::get_illumination(self : MoonPhase) -> Double {
  self.illumination
}

///|
pub fn MoonPhase::get_age_days(self : MoonPhase) -> Double {
  self.age_days
}

///|
pub fn MoonPhase::get_phase(self : MoonPhase) -> Phase {
  self.phase
}

// Computes the apparent elongation of the Moon from the Sun at instant jd
// (UTC), in degrees [0, 360), using mean elements plus the dominant
// corrections from Meeus Table 47.A.

///|
fn moon_sun_elongation(jd : Double) -> Double {
  let t = julian_centuries(jd)
  // Mean elongation of the Moon (D), degrees
  let d = 297.8501921 + 445267.1114034 * t - 0.0018819 * t * t
  // Mean anomaly of the Sun (Ms)
  let ms = 357.5291092 + 35999.0502909 * t
  // Mean anomaly of the Moon (Mm)
  let mm = 134.9633964 + 477198.8675055 * t + 0.0087414 * t * t
  // Mean argument of latitude of the Moon (F)
  let f = 93.2720950 + 483202.0175233 * t - 0.0036539 * t * t
  // Apparent elongation with dominant periodic terms
  let apparent = d +
    6.289 * sin_deg(mm) -
    2.100 * sin_deg(ms) -
    1.274 * sin_deg(2.0 * d - mm) -
    0.658 * sin_deg(2.0 * d) -
    0.214 * sin_deg(2.0 * mm) -
    0.110 * sin_deg(f)
  normalize_deg(apparent)
}

// Derives the 8-phase enum from the elongation (22.5° wide sectors).

///|
fn phase_from_elongation(elongation : Double) -> Phase {
  let e = normalize_deg(elongation)
  if e < 22.5 || e >= 337.5 {
    NewMoon
  } else if e < 67.5 {
    WaxingCrescent
  } else if e < 112.5 {
    FirstQuarter
  } else if e < 157.5 {
    WaxingGibbous
  } else if e < 202.5 {
    FullMoon
  } else if e < 247.5 {
    WaningGibbous
  } else if e < 292.5 {
    LastQuarter
  } else {
    WaningCrescent
  }
}

///|
// Computes the lunar phase at instant `jd` (UTC).
pub fn moon_phase(jd : Double) -> MoonPhase {
  let elongation = moon_sun_elongation(jd)
  // Phase angle at the Moon: 180° when new, 0° when full
  let phase_angle = 180.0 - wrap_deg(elongation)
  // Illuminated fraction (Meeus ch. 48)
  let illumination = (1.0 + cos_deg(phase_angle)) / 2.0
  // Age within the current synodic cycle
  let age_days = elongation / 360.0 * SYNODIC_MONTH
  MoonPhase::{
    elongation,
    phase_angle,
    illumination,
    age_days,
    phase: phase_from_elongation(elongation),
  }
}

///|
// Approximate Julian Date of the k-th new moon relative to the reference
// epoch 2000-01-06 (k may be negative for past new moons). Uses the mean
// synodic period with two long-term corrections; accuracy ~ hours.
pub fn new_moon_jd(k : Int32) -> Double {
  let kc = k.to_double()
  REFERENCE_NEW_MOON + SYNODIC_MONTH * kc + 0.000185 * kc * kc
}
