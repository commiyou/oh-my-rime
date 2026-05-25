local function day_start(t)
  return os.time({
    year = tonumber(os.date("%Y", t)),
    month = tonumber(os.date("%m", t)),
    day = tonumber(os.date("%d", t)),
    hour = 12,
    min = 0,
    sec = 0,
  })
end

local function add_days(t, days)
  return day_start(t) + days * 86400
end

local function date_candidates(t)
  local year = tonumber(os.date("%Y", t))
  local month = tonumber(os.date("%m", t))
  local day = tonumber(os.date("%d", t))
  return {
    string.format("%d年%d月%d日", year, month, day),
    os.date("%Y%m%d", t),
    os.date("%Y-%m-%d", t),
    os.date("%m/%d", t),
  }
end

local function week_start(t)
  local noon = day_start(t)
  local wday = tonumber(os.date("%w", noon))
  local delta = (wday == 0) and 6 or (wday - 1)
  return noon - delta * 86400
end

local function week_range(t)
  local start_t = week_start(t)
  local end_t = start_t + 6 * 86400
  return os.date("%Y-%m-%d", start_t) .. " ~ " .. os.date("%Y-%m-%d", end_t)
end

local function month_days(year, month)
  return tonumber(os.date("%d", os.time({ year = year, month = month + 1, day = 0 })))
end

local function month_range(t)
  local year = tonumber(os.date("%Y", t))
  local month = tonumber(os.date("%m", t))
  local last = month_days(year, month)
  return string.format("%04d-%02d-01 ~ %04d-%02d-%02d", year, month, year, month, last)
end

local weekday_cn = {
  [0] = "星期日",
  [1] = "星期一",
  [2] = "星期二",
  [3] = "星期三",
  [4] = "星期四",
  [5] = "星期五",
  [6] = "星期六",
}

local weekday_short = {
  [0] = "周日",
  [1] = "周一",
  [2] = "周二",
  [3] = "周三",
  [4] = "周四",
  [5] = "周五",
  [6] = "周六",
}

local function emit(input, seg, values, tag)
  for _, value in ipairs(values) do
    local cand = Candidate("quick_text", seg.start, seg._end, value, tag)
    cand.quality = 1000000
    yield(cand)
  end
end

local function translator(input, seg, env)
  local now = os.time()

  local fixed_codes = {
    w = { "我", "固定" },
    ok = { "OK", "固定" },
  }

  if fixed_codes[input] then
    local spec = fixed_codes[input]
    emit(input, seg, { spec[1] }, spec[2])
    return
  end

  local date_codes = {
    rq = { 0, "日期" },
    jt = { 0, "今天" },
    zt = { -1, "昨天" },
    mt = { 1, "明天" },
    qt = { -2, "前天" },
    ht = { 2, "后天" },
  }

  if date_codes[input] then
    local spec = date_codes[input]
    emit(input, seg, date_candidates(add_days(now, spec[1])), spec[2])
    return
  end

  if input == "sj" or input == "xj" then
    emit(input, seg, {
      os.date("%H:%M", now),
      os.date("%H:%M:%S", now),
      os.date("%H点%M分", now),
    }, "时间")
    return
  end

  if input == "dt" then
    local year = tonumber(os.date("%Y", now))
    local month = tonumber(os.date("%m", now))
    local day = tonumber(os.date("%d", now))
    emit(input, seg, {
      os.date("%Y-%m-%d %H:%M", now),
      os.date("%Y-%m-%d %H:%M:%S", now),
      os.date("%Y%m%d_%H%M", now),
      string.format("%d年%d月%d日 %s", year, month, day, os.date("%H:%M", now)),
    }, "日期时间")
    return
  end

  if input == "ts" then
    emit(input, seg, {
      tostring(now),
      tostring(now * 1000),
    }, "时间戳")
    return
  end

  if input == "xq" then
    local w = tonumber(os.date("%w", now))
    emit(input, seg, {
      weekday_cn[w],
      weekday_short[w],
      os.date("%A", now),
    }, "星期")
    return
  end

  if input == "by" then
    local year = tonumber(os.date("%Y", now))
    local month = tonumber(os.date("%m", now))
    emit(input, seg, {
      string.format("%d年%d月", year, month),
      os.date("%Y%m", now),
      month_range(now),
    }, "本月")
    return
  end

  if input == "bn" then
    emit(input, seg, {
      os.date("%Y年", now),
      os.date("%Y", now),
    }, "今年")
    return
  end

  local week_codes = {
    bz = { 0, "本周" },
    sz = { -7, "上周" },
    xz = { 7, "下周" },
  }

  if week_codes[input] then
    local spec = week_codes[input]
    local t = add_days(now, spec[1])
    emit(input, seg, {
      week_range(t),
      os.date("%Y年第%W周", t),
    }, spec[2])
    return
  end
end

return translator
