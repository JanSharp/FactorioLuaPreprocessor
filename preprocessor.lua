
---@param pieces string[]
---@param chunk string
local function parse_dollar_paren(pieces, chunk)
  local s = 1
  ---@typelist integer, string, integer
  for term, executed, e in string.gmatch(chunk, "()$(%b())()") do
    table.insert(pieces, string.format("%q..(%s or '')..",
      string.sub(chunk, s, term - 1), executed))
    s = e
  end
  table.insert(pieces, string.format("%q", string.sub(chunk, s)))
end

---@param chunk string
---@return string
local function parse_hash_lines(chunk)
  local pieces = {"return function(_put) "}
  local s = 1
  while true do
    ---@typelist integer, integer, string
    local ss, e, lua = string.find(chunk, "^#+([^\n]*\n?)", s)
    if not e then
      ---@typelist integer, integer, string
      ss, e, lua = string.find(chunk, "\n#+([^\n]*\n?)", s)
      table.insert(pieces, "_put(")
      parse_dollar_paren(pieces, string.sub(chunk, s, ss))
      table.insert(pieces, ")")
      if not e then break end
    end
    table.insert(pieces, lua)
    s = e + 1
  end
  table.insert(pieces, " end")
  return table.concat(pieces)
end

---@param chunk string
---@param name? string
---@return function(string: _put) return string
local function preprocess(chunk, name)
  return assert(load(parse_hash_lines(chunk), name))()
end

---@param src string
---@return string
local function preprocess_in_memory(src)
  local parts = {}
  ---@param s string
  local function put(s)
    table.insert(parts, s)
    table.insert(parts, "\n")
  end
  preprocess(src)(put)
  parts[#parts] = nil -- remove last newline
  return table.concat(parts)
end

return {
  preprocess = preprocess,
  preprocess_in_memory = preprocess_in_memory,
}
