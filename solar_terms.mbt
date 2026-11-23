///|
// 24 solar terms (节气): the instants when the Sun's apparent ecliptic
// longitude crosses multiples of 15°. Solved by bisection against
// solar_apparent_longitude — no huge lookup tables, works for any year.
// Accuracy: < 1 minute for the crossing instant (bisection to 1e-5 day).

pub const SOLAR_TERM_COUNT : Int32 = 24

// Step of one solar term in ecliptic longitude.

///|
pub const SOLAR_TERM_DEG : Double = 15.0

// Approximate (month, day) of each term in the Gregorian calendar, used as
// bisection seeds. Index k corresponds to apparent longitude k*15°
// (k=0 is the March equinox). Minor terms (小寒/大寒/立春/雨水/惊蛰) fall
// in January / February / early March of the same calendar year.

///|
let term_approx_date : Array[(Int32, Int32)] = [
  // k=0 春分  k=1 清明  k=2 谷雨  k=3 立夏  k=4 小满  k=5 芒种  k=6 夏至  k=7 小暑
  (3, 21),
  (4, 5),
  (4, 20),
  (5, 6),
  (5, 21),
  (6, 6),
  (6, 21),
  (7, 7),
  // k=8 大暑  k=9 立秋  k=10 处暑 k=11 白露 k=12 秋分 k=13 寒露 k=14 霜降 k=15 立冬
  (7, 23),
  (8, 8),
  (8, 23),
  (9, 8),
  (9, 23),
  (10, 8),
  (10, 23),
  (11, 7),
  // k=16 小雪 k=17 大雪 k=18 冬至 k=19 小寒 k=20 大寒 k=21 立春 k=22 雨水 k=23 惊蛰
  (11, 22),
  (12, 7),
  (12, 22),
  (1, 6),
  (1, 20),
  (2, 4),
  (2, 19),
  (3, 6),
]

// Chinese name of the term with index k (0 = 春分).

///|
pub fn solar_term_name(k : Int32) -> String {
  let names = [
    "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑",
    "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬",
    "小雪", "大雪", "冬至", "小寒", "大寒", "立春", "雨水", "惊蛰",
  ]
  names[k]
}

///|
// A solar term: index k (longitude k*15°) and the instant as a Julian Date.
pub struct SolarTerm {
  index : Int32
  jd : Double
}

///|
pub fn SolarTerm::get_index(self : SolarTerm) -> Int32 {
  self.index
}

///|
pub fn SolarTerm::get_jd(self : SolarTerm) -> Double {
  self.jd
}

///|
pub fn SolarTerm::name(self : SolarTerm) -> String {
  solar_term_name(self.index)
}

///|
// Computes all 24 solar terms of the given Gregorian year, ordered by
// longitude index k (小寒/大寒/立春/雨水/惊蛰 are in Jan/Feb/Mar of that
// year; the rest run Mar-Dec).
pub fn solar_terms(year : Int32) -> Array[SolarTerm] {
  let out : Array[SolarTerm] = Array(capacity=SOLAR_TERM_COUNT)
  for k in 0..<SOLAR_TERM_COUNT {
    let seed = term_approx_date[k]
    let jd = julian_date(year, seed.0, seed.1, 0, 0, 0)
    let exact = solve_solar_term(
      jd - 1.5,
      jd + 1.5,
      k.to_double() * SOLAR_TERM_DEG,
    )
    out.push(SolarTerm::{ index: k, jd: exact, })
  }
  out
}

// Bisection: find jd in [lo, hi] where solar_apparent_longitude(jd)
// crosses target (mod 360). The ±1.5-day window around the seed keeps the
// wrapped difference inside (-4.5°, 4.5°), so it cannot wrap around.

///|
fn solve_solar_term(lo : Double, hi : Double, target : Double) -> Double {
  let mut a = lo
  let mut b = hi
  let mut fa = wrap_deg(solar_apparent_longitude(a) - target)
  // The sun advances ~0.99°/day, so the crossing exists in the window
  for _ in 0..<30 {
    let mid = (a + b) / 2.0
    let fm = wrap_deg(solar_apparent_longitude(mid) - target)
    if fa < 0.0 && fm >= 0.0 {
      b = mid
    } else {
      a = mid
      fa = fm
    }
  }
  (a + b) / 2.0
}
