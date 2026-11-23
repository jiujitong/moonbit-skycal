// skycal CLI — prints sun and moon events for a given place and date.
//
// Usage:
//   moon run cmd/main -- [lat lon tz year month day]    sun events + moon phase
//   moon run cmd/main -- moon  [lat lon tz] year month day    moon phase + moonrise/moonset/transit
//   moon run cmd/main -- terms [year [tz]]              24 solar terms table
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
// Collects numeric arguments (sign, digits, decimal point) for subcommands.
fn numeric_args(args : Array[String], from : Int32) -> Array[String] {
  let out : Array[String] = Array(capacity=6)
  for i in from..<args.length() {
    let s = args[i]
    if s.length() > 0 {
      let c = s[0].to_int()
      if (c >= 48 && c <= 57) || (c == 45 && s.length() > 1) {
        out.push(s)
      }
    }
  }
  out
}

// 24 solar terms table for one year, in chronological order.

///|
fn print_terms(args : Array[String]) -> Unit {
  let nums = numeric_args(args, 0)
  let y : Int32 = if nums.length() > 0 { parse_int(nums[0]) } else { 2026 }
  let tz : Double = if nums.length() > 1 { parse_double(nums[1]) } else { 8.0 }
  let sb = StringBuilder()
  sb.write_string("=== 24 solar terms (节气) — ")
  sb.write_string(y.to_string())
  sb.write_string(" (UTC+")
  sb.write_string(tz.to_string())
  sb.write_string(") ===\n")
  // solar_terms returns terms in longitude order; sort chronologically
  let sorted : Array[@skycal.SolarTerm] = Array(capacity=24)
  for t in @skycal.solar_terms(y) {
    sorted.push(t)
  }
  sorted.sort_by(fn(a, b) {
    if a.get_jd() < b.get_jd() {
      -1
    } else if a.get_jd() > b.get_jd() {
      1
    } else {
      0
    }
  })
  let mut n = 1
  for t in sorted {
    sb.write_string(if n < 10 { " " } else { "" })
    sb.write_string(n.to_string())
    sb.write_string("  ")
    sb.write_string(@skycal.solar_term_name(t.get_index()))
    sb.write_string("   ")
    sb.write_string(@skycal.jd_to_local_string(t.get_jd(), tz))
    sb.write_string("\n")
    n = n + 1
  }
  println(sb.to_string())
}

// Moon detail: phase, illumination, age plus moonrise/transit/moonset.

///|
fn print_moon(args : Array[String]) -> Unit {
  let nums = numeric_args(args, 0)
  let mut lat = 39.9042
  let mut lon = 116.4074
  let mut tz = 8.0
  let mut y = 2026
  let mut m = 11
  let mut d = 23
  if nums.length() >= 6 {
    lat = parse_double(nums[0])
    lon = parse_double(nums[1])
    tz = parse_double(nums[2])
    y = parse_int(nums[3])
    m = parse_int(nums[4])
    d = parse_int(nums[5])
  } else if nums.length() >= 3 {
    y = parse_int(nums[0])
    m = parse_int(nums[1])
    d = parse_int(nums[2])
  }
  let pos = @skycal.make_geo(lat, lon)
  let sb = StringBuilder()
  sb.write_string("=== moon — ")
  sb.write_string(@skycal.format_lat(lat))
  sb.write_string(" ")
  sb.write_string(@skycal.format_lon(lon))
  sb.write_string(", ")
  sb.write_string(y.to_string() + "-" + @skycal.pad2(m) + "-" + @skycal.pad2(d))
  sb.write_string(" (UTC+")
  sb.write_string(tz.to_string())
  sb.write_string(") ===\n")
  let moon = @skycal.moon_phase(@skycal.julian_date(y, m, d, 12, 0, 0))
  sb.write_string("phase       ")
  sb.write_string(moon.get_phase().name())
  sb.write_string("\nillum       ")
  let illum_pct = (moon.get_illumination() * 100.0).round().to_int()
  sb.write_string(illum_pct.to_string())
  sb.write_string("%\nage         ")
  let age1 = (moon.get_age_days() * 10.0).round() / 10.0
  sb.write_string(age1.to_string())
  sb.write_string(" days\n")
  match @skycal.moon_times(y, m, d, pos) {
    Some(mt) => {
      sb.write_string("moonrise    ")
      sb.write_string(
        match mt.get_moonrise() {
          Some(jd) => @skycal.jd_to_local_string(jd, tz)
          None => "n/a"
        },
      )
      sb.write_string("\ntransit     ")
      sb.write_string(@skycal.jd_to_local_string(mt.get_transit(), tz))
      sb.write_string("\nmoonset     ")
      sb.write_string(
        match mt.get_moonset() {
          Some(jd) => @skycal.jd_to_local_string(jd, tz)
          None => "n/a"
        },
      )
      sb.write_string("\n")
    }
    None => sb.write_string("moon times: n/a\n")
  }
  println(sb.to_string())
}

///|
fn main {
  let args = @env.args()
  // Subcommand dispatch: "terms" or "moon"; anything else keeps the
  // original sun-events behavior (non-numeric tokens are skipped anyway).
  let mut mode = "events"
  for i in 0..<args.length() {
    if args[i] == "terms" {
      mode = "terms"
    } else if args[i] == "moon" {
      mode = "moon"
    }
  }
  if mode == "terms" {
    print_terms(args)
    return
  }
  if mode == "moon" {
    print_moon(args)
    return
  }
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
