
---@param chunk string
---@return string
local function preprocess_pragma_once(chunk)
  local preprocessor = preprocessor
  ---@typelist number, string, number
  local s, f = chunk:match("()#pragma once%s*return()")
  if s then
    local runtime_global = "__"..preprocessor.args.project_id.."__preprocessor"
    local relative_path = preprocessor.file_path:sub(#preprocessor.args.source_dir_path + 1)
    local module_expression = runtime_global..".modules[\""..relative_path:str().."\"]"
    chunk = ([[

if not %s then
  if __DebugAdapter then
    __DebugAdapter.defineGlobal("%s")
  end
  %s = {modules = {}}
end
if %s then
  return %s
end
]]):format(runtime_global, runtime_global, runtime_global,
        module_expression, module_expression)
      ..chunk:sub(1, s - 1)
      ..module_expression.." ="
      ..chunk:sub(f)
      .."\nreturn "..module_expression.."\n"
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
    return " function("..param..") return "..body:sub(2, -2)..";end\n"
  end)
  chunk = chunk:gsub("([a-zA-Z_][a-zA-Z0-9_]*)%s*=>%s*(%b{})", function(param, body)
    return " function("..param..")"..body:sub(2, -2)..";end\n"
  end)
  chunk = chunk:gsub("(%([^())]*%))%s*=>%s*(%b())", function(params, body)
    return " function"..params.." return "..body:sub(2, -2)..";end\n"
  end)
  chunk = chunk:gsub("(%([^())]*%))%s*=>%s*(%b{})", function(params, body)
    return " function"..params..body:sub(2, -2)..";end\n"
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
