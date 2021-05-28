
---`$foo` gets turned into `"foo"`. Meant for "macro" parameters, but might be useful otherwise as well
---@param chunk string
---@return string
local function identifier_as_string(chunk)
  return chunk:gsub("$([a-zA-Z_][a-zA-Z0-9_]*)", function(m) return '"'..m..'"' end)
end

---@param chunk string
---@return string
local function ignored_by_language_server(chunk)
  -- p stands for "only preprocessor"
  return chunk:gsub("%$p(%b())", function(match)
    return match:sub(2, -2)
  end)
end

---@param chunk string
---@return string
local function ignored_by_preprocessor(chunk)
  -- l stands for "only language server"
  return chunk:gsub("%$l(%b())", "")
end

---@param chunk string
---@return string
local function preprocess_pragma_once(chunk)
  local preprocessor = preprocessor
  ---@type number
  local s, f = chunk:match("()#pragma once()")
  if s then
    local runtime_global = "__"..preprocessor.args.project_id.."__preprocessor_runtime_data"
    local relative_path = preprocessor.current_file_path:sub(#preprocessor.args.source_dir_path + 1)
    local module_expression = runtime_global..".modules[\""..relative_path:str().."\"]"
    chunk = ([[
%s
do
  local data = %s
  if data then
    local cached_result = data.modules["%s"]
    if cached_result ~= nil then
      return cached_result
    end
  else
    if __DebugAdapter then
      __DebugAdapter.defineGlobal("%s")
    end
    %s = {modules = {}}
  end
end
local main_chunk = function(...)
%s
end
local result = main_chunk(...)
if result == nil then
  result = true
end
%s = result
return result
]])
      :format(chunk:sub(1, s - 1),
        runtime_global, relative_path:str(), runtime_global, runtime_global,
        chunk:sub(f),
        module_expression)
  end
  return chunk
end

---support function notations similar to C# lambda expressions
---() => (true) -- the expression has to be in parethesis
---e => (e.field)
---(one, two) => {
---  print("one: "..one..", two: "..two..";")
---  return one + two
---}
---@param chunk string
---@return string
local function preprocess_lambda_expressions(chunk)
  chunk = chunk:gsub("([a-zA-Z_][a-zA-Z0-9_]*)%s*=>%s*(%b())", function(param, body)
    return " function("..param..") return "..body:sub(2, -2)..";end "
  end)
  chunk = chunk:gsub("([a-zA-Z_][a-zA-Z0-9_]*)%s*=>%s*(%b{})", function(param, body)
    return " function("..param..")"..body:sub(2, -2)..";end "
  end)
  chunk = chunk:gsub("(%([^())]*%))%s*=>%s*(%b())", function(params, body)
    return " function"..params.." return "..body:sub(2, -2)..";end "
  end)
  chunk = chunk:gsub("(%([^())]*%))%s*=>%s*(%b{})", function(params, body)
    return " function"..params..body:sub(2, -2)..";end "
  end)
  return chunk
end

---@param chunk string
---@return string
local function trim_type_constructors(chunk)
  ---@param m string
  return chunk:gsub("new%s+[^%s({}),]+%s*([({])", function(m)
    return m
  end)
end

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
    local ss, e, lua = string.find(chunk, "^%s*#+([^\n]*\n?)", s)
    if not e then
      ---@typelist integer, integer, string
      ss, e, lua = string.find(chunk, "\n%s*#+([^\n]*\n?)", s)
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
  chunk = identifier_as_string(chunk)
  chunk = ignored_by_language_server(chunk)
  chunk = ignored_by_preprocessor(chunk)
  chunk = preprocess_pragma_once(chunk)
  chunk = preprocess_lambda_expressions(chunk)
  chunk = trim_type_constructors(chunk)
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

-- fix semantics