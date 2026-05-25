local kAccepted = 1
local kNoop = 2

local function data_path()
  return rime_api.get_user_data_dir() .. "/english_learner.tsv"
end

local function normalize_code(s)
  if not s then
    return nil
  end
  return string.lower(s)
end

local function valid_token(s)
  return s and s:match("^[A-Za-z][A-Za-z0-9_%-%.]*$") and #s >= 2 and #s <= 40
end

local function should_learn_raw(s)
  if not valid_token(s) then
    return false
  end
  return true
end

local function read_entries()
  local entries = {}
  local file = io.open(data_path(), "r")
  if not file then
    return entries
  end

  for line in file:lines() do
    local code, text, count = line:match("^([^\t]+)\t([^\t]+)\t(%d+)$")
    if valid_token(code) and valid_token(text) then
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

local function learn_raw(input)
  local code = normalize_code(input)
  local entries = read_entries()
  entries[code] = entries[code] or {}
  entries[code][input] = (entries[code][input] or 0) + 1
  write_entries(entries)
end

local function processor(key, env)
  local repr = key:repr()
  if repr ~= "Return" and repr ~= "KP_Enter" then
    return kNoop
  end

  local context = env.engine.context
  local input = context.input
  if should_learn_raw(input) then
    env.engine:commit_text(input)
    learn_raw(input)
    context:clear()
    return kAccepted
  end

  return kNoop
end

return processor
