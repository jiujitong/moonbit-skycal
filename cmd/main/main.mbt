// skycal CLI — prints sun and moon events for a given place and date.
//
// Usage:
//   moon run cmd/main -- [lat lon tz year month day]
// With no arguments it prints a worked example for Beijing.

// Minimal numeric parsers for CLI input (sign, digits, one decimal point).

///|
fn parse_int(s : String) -> Int32 {
  let n = s.length()
  let mut i = 0
  let mut neg = false
  if i < n && (s[i].to_int() == 45 || s[i].to_int() == 43) {
    neg = s[i].to_int() == 45
    i = i + 1
  }
  let mut v = 0
  while i < n {
    let c = s[i].to_int()
    if c < 48 || c > 57 {
      break
    }
    v = v * 10 + (c - 48)
    i = i + 1
  }
  if neg {
    -v
  } else {
    v
  }
}

///|
fn parse_double(s : String) -> Double {
  let parts : Array[StringView] = s.split(".").collect()
  let int_part = parse_int(parts[0].to_owned()).to_double()
  if parts.length() == 1 {
    return int_part
  }
  let frac_str = parts[1].to_owned()
  let frac = parse_int(frac_str).to_double()
  let mut denom = 1.0
  for _ in 0..<frac_str.length() {
    denom = denom * 10.0
  }
  let sign : Double = if int_part < 0.0 { -1.0 } else { 1.0 }
  int_part + sign * frac / denom
}

///|
fn parse_args(
  args : Array[String],
) -> (Double, Double, Double, Int32, Int32, Int32) {
  // Defaults: Beijing, 2026-06-21 (summer solstice)
  let mut lat = 39.9042
  let mut lon = 116.4074
  let mut tz = 8.0
  let mut y = 2026
  let mut m = 6
  let mut d = 21
  // argv may include the program name as its first element (e.g. under
  // moon run with the JS backend) — skip any leading non-numeric entries.
  let mut start = 0
  for i in 0..<args.length() {
    let s = args[i]
    if s.length() > 0 {
      let c = s[0].to_int()
      if (c >= 48 && c <= 57) || c == 43 || c == 45 {
        start = i
        break
      }
    }
  }
  if args.length() - start >= 6 {
    lat = parse_double(args[start])
    lon = parse_double(args[start + 1])
    tz = parse_double(args[start + 2])
    y = parse_int(args[start + 3])
    m = parse_int(args[start + 4])
    d = parse_int(args[start + 5])
  }
  (lat, lon, tz, y, m, d)
}

///|
fn main {
  let args = @env.args()
  let (lat, lon, tz, y, m, d) = parse_args(args)
  let pos = @skycal.make_geo(lat, lon)
  let sb = StringBuilder()
  sb.write_string("=== skycal — ")
  sb.write_string(@skycal.format_lat(lat))
  sb.write_string(" ")
  sb.write_string(@skycal.format_lon(lon))
  sb.write_string(", ")
  sb.write_string(y.to_string() + "-" + @skycal.pad2(m) + "-" + @skycal.pad2(d))
  sb.write_string(" (UTC+")
  sb.write_string(tz.to_string())
  sb.write_string(") ===\n")
  // Sun events
  match @skycal.sun_times(y, m, d, pos) {
    Some(times) => {
      sb.write_string("sunrise     ")
      sb.write_string(@skycal.jd_to_local_string(times.get_sunrise(), tz))
      sb.write_string("\nsolar noon  ")
      sb.write_string(@skycal.jd_to_local_string(times.get_solar_noon(), tz))
      sb.write_string("\nsunset      ")
      sb.write_string(@skycal.jd_to_local_string(times.get_sunset(), tz))
      sb.write_string("\ndaylight    ")
      sb.write_string(@skycal.format_minutes(times.daylight_minutes()))
      sb.write_string("\n")
    }
    None =>
      sb.write_string(
        "polar day or night: the sun never crosses the horizon today\n",
      )
  }
  // Golden / blue hours
  match @skycal.golden_hours(y, m, d, pos) {
    Some(g) => {
      sb.write_string("golden am   ")
      sb.write_string(@skycal.jd_to_local_string(g.get_morning_start(), tz))
      sb.write_string(" → ")
      sb.write_string(@skycal.jd_to_local_string(g.get_morning_end(), tz))
      sb.write_string("\ngolden pm   ")
      sb.write_string(@skycal.jd_to_local_string(g.get_evening_start(), tz))
      sb.write_string(" → ")
      sb.write_string(@skycal.jd_to_local_string(g.get_evening_end(), tz))
      sb.write_string("\n")
    }
    None => sb.write_string("golden hour: n/a (polar conditions)\n")
  }
  // Moon
  let noon_local = @skycal.julian_date(y, m, d, 12, 0, 0)
  let moon = @skycal.moon_phase(noon_local)
  sb.write_string("moon        ")
  sb.write_string(moon.get_phase().name())
  sb.write_string(" (age ")
  sb.write_string(moon.get_age_days().to_string())
  sb.write_string(" d, ")
  let illum_pct = (moon.get_illumination() * 100.0).round().to_int()
  sb.write_string(illum_pct.to_string())
  sb.write_string("% illuminated)\n")
  println(sb.to_string())
}
