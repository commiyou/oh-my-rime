local M = {}

local function data_path()
  return rime_api.get_user_data_dir() .. "/english_learner.tsv"
end

local function normalize_code(s)
  if not s then
    return nil
  end
  return string.lower(s)
end

local function valid_code(s)
  return s and s:match("^[A-Za-z][A-Za-z0-9_%-%.]*$") and #s >= 2 and #s <= 20
end

local function should_seed(input)
  -- Avoid polluting normal pinyin such as "zhihui". Unknown English seeds are
  -- only for short abbreviations or tokens that visibly look non-pinyin.
  if input:match("[%u%d_%-%.]") then
    return true
  end
  return #input >= 2 and #input <= 4
end

local function valid_text(s)
  return s and s:match("^[A-Za-z][A-Za-z0-9_%-%.]*$") and #s >= 2 and #s <= 40
end

local function read_entries()
  local entries = {}
  local file = io.open(data_path(), "r")
  if not file then
    return entries
  end

  for line in file:lines() do
    local code, text, count = line:match("^([^\t]+)\t([^\t]+)\t(%d+)$")
    if valid_code(code) and valid_text(text) then
      code = normalize_code(code)
      entries[code] = entries[code] or {}
      entries[code][text] = tonumber(count) or 1
    end
  end

  file:close()
  return entries
end

local function write_entries(entries)
  local file = io.open(data_path(), "w")
  if not file then
    return
  end

  for code, words in pairs(entries) do
    for text, count in pairs(words) do
      file:write(code, "\t", text, "\t", tostring(count), "\n")
    end
  end

  file:close()
end

local function learn(code, text)
  if not valid_code(code) or not valid_text(text) then
    return
  end

  code = normalize_code(code)
  local entries = read_entries()
  entries[code] = entries[code] or {}
  entries[code][text] = (entries[code][text] or 0) + 1
  write_entries(entries)
end

local function sorted_words(words)
  local result = {}
  for text, count in pairs(words or {}) do
    table.insert(result, { text = text, count = count })
  end
  table.sort(result, function(a, b)
    if a.count == b.count then
      return a.text < b.text
    end
    return a.count > b.count
  end)
  return result
end

local function emit(seg, text, comment, quality)
  local cand = Candidate("english_learner", seg.start, seg._end, text, comment)
  cand.quality = quality
  yield(cand)
end

function M.init(env)
  env.notifier = env.engine.context.select_notifier:connect(function(ctx)
    local ok, cand = pcall(function()
      return ctx:get_selected_candidate()
    end)
    if ok and cand and cand.type == "english_learner" then
      learn(ctx.input, cand.text)
    end
  end)
end

function M.fini(env)
  if env.notifier then
    env.notifier:disconnect()
  end
end

function M.func(input, seg, env)
  if not valid_code(input) then
    return
  end

  local code = normalize_code(input)
  local seen = {}
  local rank = 0

  for _, item in ipairs(sorted_words(read_entries()[code])) do
    rank = rank + 1
    seen[item.text] = true
    local quality = -500 + item.count * 200 - rank
    if quality > 250 then
      quality = 250 - rank
    end
    emit(seg, item.text, "已学习 " .. tostring(item.count), quality)
  end

  if not should_seed(input) then
    return
  end

  local raw_candidates = { string.upper(input), input }
  for _, text in ipairs(raw_candidates) do
    if not seen[text] then
      seen[text] = true
      emit(seg, text, "英文候选", -1000)
    end
  end
end

return M
