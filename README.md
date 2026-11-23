# skycal

[![CI](https://github.com/jiujitong/moonbit-skycal/actions/workflows/ci.yml/badge.svg)](https://github.com/jiujitong/moonbit-skycal/actions)
[![mooncakes](https://img.shields.io/badge/mooncakes-jiujitong%2Fskycal_0.1.0-blue)](https://mooncakes.io/docs/jiujitong/skycal)

**A pure MoonBit astronomy & calendar library** — Julian dates, sunrise/sunset, solar & lunar positions, twilight windows, moon phases, 24 solar terms, planetary positions and calendar conversions, with deterministic, fully testable algorithms.

中文说明见下方 [中文简介](#中文简介)。

## Features

- **Julian Date conversions** — Gregorian ↔ JD/MJD round trips, exact at anchor epochs (J2000.0 = 2451545.0, MJD 0 = 1858-11-17)
- **Solar position** — altitude and azimuth at any instant from any location (NOAA solar position algorithm)
- **Sunrise / sunset / solar noon** — for a calendar day and geographic position, with polar day/night reported explicitly as `None`; an iterative variant targets ±0.5 min
- **Twilight windows** — civil (-6°), nautical (-12°) and astronomical (-18°)
- **Golden & blue hours** — photography-oriented event windows (sun between -6° and +6°)
- **Annual daylight statistics** — total daylight hours, longest/shortest day, polar day/night day counts, monthly daylight table
- **Moon phases** — illuminated fraction, phase angle, moon age and the conventional 8-phase enum (Meeus truncated series)
- **Moon position & rise/set** — ecliptic longitude/latitude/distance, topocentric altitude/azimuth with parallax + refraction, moonrise/moonset/transit times
- **Sidereal time & coordinate transforms** — GMST, local sidereal time, equatorial ↔ horizontal conversions, Bennett atmospheric refraction
- **24 solar terms (节气)** — solved by bisection on the sun's apparent longitude, ±1 min typical
- **Planetary positions** — Mercury / Venus / Mars / Jupiter / Saturn geocentric RA/dec/distance (JPL mean elements, 1800-2050)
- **Calendar conversions** — Julian calendar ↔ JD, Julian Day Number, Unix timestamps

## Installation

```bash
moon add jiujitong/skycal
```

## Usage

```moonbit
// Sunrise/sunset for Beijing on the 2026 summer solstice
let pos = @skycal.make_geo(39.9042, 116.4074)
match @skycal.sun_times(2026, 6, 21, pos) {
  Some(times) => {
    println(@skycal.jd_to_local_string(times.get_sunrise(), 8.0)) // 2026-06-21 04:46
    println(@skycal.format_minutes(times.daylight_minutes()))     // 15h 00m
  }
  None => println("polar day or night")
}

// Moon phase right now
let moon = @skycal.moon_phase(@skycal.julian_date(2026, 11, 23, 12, 0, 0))
println(moon.get_phase().name())       // e.g. "Waxing Gibbous"
println(moon.get_illumination())       // 0..1

// Moonrise / moonset / transit (10-min scan + interpolation)
match @skycal.moon_times(2026, 11, 23, pos) {
  Some(mt) => println(@skycal.jd_to_local_string(mt.get_transit(), 8.0))
  None => ()
}

// 24 solar terms for a year
for term in @skycal.solar_terms(2026) {
  println(term.get_index())  // 0 = 春分 (March equinox), 23 = 惊蛰
}

// Planetary position (Jupiter tonight)
let jup = @skycal.planet_altaz(@skycal.jupiter(), jd, pos)
println(jup.0)  // altitude, degrees

// Golden hour (photography): sun between -6° and +6°
match @skycal.golden_hours(2026, 6, 21, pos) {
  Some(g) => println(@skycal.jd_to_local_string(g.get_evening_start(), 8.0))
  None => ()
}
```

All instants are represented as Julian Dates (`Double`, UTC). Use `jd_to_datetime` / `jd_to_local_string` to convert to calendar values. See the generated interface in `pkg.generated.mbti` for the full API.

### CLI demo

```bash
moon run cmd/main                                # worked example (Beijing, 2026-06-21)
moon run cmd/main -- 35.6762 139.6503 9 2026 12 21   # Tokyo winter solstice
moon run cmd/main -- moon 2026 11 23             # moon phase + moonrise/transit/moonset
moon run cmd/main -- moon 31.23 121.47 8 2026 12 21   # moon detail for Shanghai
moon run cmd/main -- terms 2026                  # 24 solar terms table (chronological)
```

## Accuracy

| Quantity | Accuracy | Notes |
|---|---|---|
| Solar declination / altitude | ±0.03° | NOAA low-precision equations, valid 1900-2100 |
| Sunrise / sunset | ±2 min | vs USNO published tables (see tests) |
| Sunrise / sunset (precise) | ±0.5 min | iterative variant, event-time solar parameters |
| Equation of time | ±0.1 min | |
| Moon illumination | ~1% | Meeus truncated series |
| Moon phase timing | ~1 hour | |
| Moon ecliptic position | ~0.3° / ~0.01° / ~500 km | longitude / latitude / distance (Meeus dominant terms) |
| Moonrise / moonset | ±5 min | 10-min scan + linear interpolation |
| 24 solar terms | ±1 min | apparent-longitude bisection |
| Planet geocentric position | ~0.5° | JPL mean elements + light-time, 1800-2050 |
| GMST | ~0.1 s | Meeus 12.4 polynomial |

## Verification methodology

Tests combine four independent layers (65 tests, all deterministic):

1. **Anchor epochs** — J2000.0 and MJD 0 are exact by definition; leap-century rules are checked directly.
2. **Published reference tables** — Beijing / New York / Tokyo solstice sunrise/sunset values are compared against USNO/NOAA published data with a ±2 min tolerance (e.g. Beijing 2026-06-21: 04:46 / 12:16 / 19:46 CST, daylight 15h00m).
3. **Physical invariants** — declination bounded by ±23.44° all year, equation of time within ±16.5 min, equatorial equinox daylight ≈ 12 h, rise < noon < set, polar day/night reported as `None`, illumination within [0, 1].
4. **Determinism** — repeated evaluations are bit-identical; no randomness anywhere.

## Scope (explicitly NOT supported)

- High-precision (arcsecond) ephemerides (VSOP87-class) — planetary positions here use JPL mean orbital elements (~0.5° accuracy, valid 1800-2050)
- Solar/lunar eclipse prediction — out of scope
- Chinese traditional calendar (农历/八字) — see `justinwongcn/tyme4mb` on mooncakes.io
- Asteroid / comet tracking — out of scope
- Timezones are left to the caller: all results are UTC Julian Dates; use `jd_to_local_string` for display. For |UTC offset| ≥ 12h, day boundaries may shift by one day.

## Reference sources

- Solar equations: *General Solar Position Calculations*, NOAA Global Monitoring Division (public domain), and the NOAA Solar Calculator methodology
- Lunar phase: Jean Meeus, *Astronomical Algorithms*, 2nd ed., chapters 47-49 (mean elements + dominant periodic corrections)
- All MoonBit code in this repository is written from scratch; no third-party code is included. The algorithms above are standard published science.

## Development

```bash
moon check --deny-warn   # zero warnings policy
moon test                # 65 deterministic tests
moon fmt && moon info    # format + refresh interface
moon run cmd/main        # CLI demo
```

## License

MIT — see [LICENSE](LICENSE).

## 中文简介

**skycal** 是一个纯 MoonBit 的天文历法计算库：儒略日转换、日出日落（含 ±0.5 分钟高精度迭代法）、太阳/月亮位置（高度角/方位角，含视差与大气折射）、民用/航海/天文晨昏蒙影、摄影黄金时刻、月相（照度、月龄、八相）、月出月落月中天、恒星时与坐标转换、24 节气（黄经二分求解）、五大行星地心位置（JPL 平均轨道要素）、儒略历/JDN/Unix 时间戳转换、年日照统计（总时长/最长最短日/极昼极夜天数）。全部数值确定性、可复现，65 个测试与 USNO/NOAA 公开数据交叉验证（±2 分钟）。

适用场景：摄影计划（黄金时刻）、太阳能面板选址、农业物联网（嵌入式设备按纬度计算日照）、观星计划（恒星时/月亮/行星）、日程应用、潮汐感知。安装 `moon add jiujitong/skycal`，示例：

```moonbit
let pos = @skycal.make_geo(39.9042, 116.4074) // 北京
match @skycal.sun_times(2026, 6, 21, pos) {
  Some(t) => println(@skycal.jd_to_local_string(t.get_sunrise(), 8.0)) // 2026-06-21 04:46
  None => println("polar day or night")
}
```

明确不做：角秒级星历（VSOP87）、日月食、农历八字（请用 tyme4mb）、小行星彗星。参考来源：NOAA 太阳位置计算文档、Meeus《Astronomical Algorithms》、JPL 平均轨道要素表。所有 MoonBit 代码为本仓库原创。
