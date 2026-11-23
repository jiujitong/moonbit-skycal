# skycal

[![CI](https://github.com/jiujitong/moonbit-skycal/actions/workflows/ci.yml/badge.svg)](https://github.com/jiujitong/moonbit-skycal/actions)

**A pure MoonBit astronomical calculations library** — Julian dates, sunrise/sunset, solar position, twilight windows and moon phases, with deterministic, fully testable algorithms.

中文说明见下方 [中文简介](#中文简介)。

## Features

- **Julian Date conversions** — Gregorian ↔ JD/MJD round trips, exact at anchor epochs (J2000.0 = 2451545.0, MJD 0 = 1858-11-17)
- **Solar position** — altitude and azimuth at any instant from any location (NOAA solar position algorithm)
- **Sunrise / sunset / solar noon** — for a calendar day and geographic position, with polar day/night reported explicitly as `None`
- **Twilight windows** — civil (-6°), nautical (-12°) and astronomical (-18°)
- **Golden & blue hours** — photography-oriented event windows (sun between -6° and +6°)
- **Moon phases** — illuminated fraction, phase angle, moon age and the conventional 8-phase enum (Meeus mean-element approach with dominant corrections)

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
```

## Accuracy

| Quantity | Accuracy | Notes |
|---|---|---|
| Solar declination / altitude | ±0.03° | NOAA low-precision equations, valid 1900-2100 |
| Sunrise / sunset | ±2 min | vs USNO published tables (see tests) |
| Equation of time | ±0.1 min | |
| Moon illumination | ~1% | Meeus dominant-term subset |
| Moon phase timing | ~1 hour | |

## Verification methodology

Tests combine four independent layers (28 tests, all deterministic):

1. **Anchor epochs** — J2000.0 and MJD 0 are exact by definition; leap-century rules are checked directly.
2. **Published reference tables** — Beijing / New York / Tokyo solstice sunrise/sunset values are compared against USNO/NOAA published data with a ±2 min tolerance (e.g. Beijing 2026-06-21: 04:46 / 12:16 / 19:46 CST, daylight 15h00m).
3. **Physical invariants** — declination bounded by ±23.44° all year, equation of time within ±16.5 min, equatorial equinox daylight ≈ 12 h, rise < noon < set, polar day/night reported as `None`, illumination within [0, 1].
4. **Determinism** — repeated evaluations are bit-identical; no randomness anywhere.

## Scope (explicitly NOT supported)

- Planetary / stellar positions (VSOP87-class ephemerides) — out of scope
- Solar/lunar eclipse prediction — out of scope
- Chinese traditional calendar (农历/八字) — see `justinwongcn/tyme4mb` on mooncakes.io
- High-precision (arcsecond) ephemerides — this library targets application-level accuracy (±2 min / ±0.03°)
- Timezones are left to the caller: all results are UTC Julian Dates; use `jd_to_local_string` for display. For |UTC offset| ≥ 12h, day boundaries may shift by one day.

## Reference sources

- Solar equations: *General Solar Position Calculations*, NOAA Global Monitoring Division (public domain), and the NOAA Solar Calculator methodology
- Lunar phase: Jean Meeus, *Astronomical Algorithms*, 2nd ed., chapters 47-49 (mean elements + dominant periodic corrections)
- All MoonBit code in this repository is written from scratch; no third-party code is included. The algorithms above are standard published science.

## Development

```bash
moon check --deny-warn   # zero warnings policy
moon test                # 28 deterministic tests
moon fmt && moon info    # format + refresh interface
moon run cmd/main        # CLI demo
```

## License

MIT — see [LICENSE](LICENSE).

## 中文简介

**skycal** 是一个纯 MoonBit 的天文历法计算库：儒略日转换、日出日落、太阳位置（高度角/方位角）、民用/航海/天文晨昏蒙影、摄影黄金时刻、月相（照度、月龄、八相）。全部数值确定性、可复现，28 个测试与 USNO/NOAA 公开数据交叉验证（±2 分钟）。

适用场景：摄影计划、太阳能面板朝向、农业物联网（嵌入式设备按纬度计算日照）、日程应用、潮汐感知。安装 `moon add jiujitong/skycal`，示例：

```moonbit
let pos = @skycal.make_geo(39.9042, 116.4074) // 北京
match @skycal.sun_times(2026, 6, 21, pos) {
  Some(t) => println(@skycal.jd_to_local_string(t.get_sunrise(), 8.0)) // 2026-06-21 04:46
  None => println("polar day or night")
}
```

明确不做：行星/恒星位置、日月食、农历八字（请用 tyme4mb）、角秒级星历。参考来源：NOAA 太阳位置计算文档、Meeus《Astronomical Algorithms》。所有 MoonBit 代码为本仓库原创。
