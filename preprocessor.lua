
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

---@param chunk string
---@return string
local function interpolate_strings(chunk)
  local last_finish = 0
  local result = {}
  ---@typelist string, number
  for opener, start in chunk:gmatch("$([\"'%[])()") do
    if start > last_finish then

      local closer
      result[#result+1] = chunk:sub(last_finish, start - 3)
      if opener == "[" then
        local eq_chain = chunk:match("^(=*)%[", start)
        if not eq_chain then
          last_finish = start - 2
          goto continue
        end
        start = start + eq_chain:len() + 1
        opener = "["..eq_chain.."["
        closer = "]"..eq_chain.."]"
        ---@typelist string, number
        last_finish = chunk:match("%]"..eq_chain.."%]()", start)
      else
        closer = opener
        ---@typelist string, string, string, number
        for backslashes, finish in chunk:gmatch("(\\*)"..opener.."()", start) do
          last_finish = finish
          if (backslashes:len() % 2) == 0 then
            break
          end
        end
      end

      result[#result+1] = opener
      local interpolation_start_index = #result + 1
      local last_pos_in_str = start
      ---@typelist string, number
      for curly, current_pos in chunk:gmatch("({+)()", start) do
        if current_pos > last_finish then
          break
        end
        if current_pos > last_pos_in_str then
          if (curly:len() % 2) == 1 then
            result[#result+1] = chunk:sub(last_pos_in_str, current_pos - 2)
            result[#result+1] = closer
            result[#result+1] = "..("
            local closing_curly, interpolation_finish = nil, current_pos
            repeat
              ---@typelist string, number
              closing_curly, interpolation_finish = chunk:match("(}+)()", interpolation_finish)
            until (closing_curly:len() % 2) == 1 or interpolation_finish > last_finish
            if interpolation_finish > last_finish then
              -- a { without it's closing }!
              -- this is invalid, but it will get silently ignored
              -- it basically just removes the $ and leaves the string as is
              for i = interpolation_start_index, #result do
                result[i] = nil
              end
              break
            end
            result[#result+1] = chunk:sub(current_pos, interpolation_finish - 2)
            result[#result+1] = ").."
            result[#result+1] = opener
            last_pos_in_str = interpolation_finish
          end
        end
      end
      result[#result+1] = chunk:sub(last_pos_in_str, last_finish - closer:len() - 1)
      result[#result+1] = closer
      -- TODO: detect and remove concats of empty strings because that's a waste
      -- but man that's a poin
    end
    ::continue::
  end
  result[#result+1] = chunk:sub(last_finish)
  return table.concat(result)
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
  chunk = interpolate_strings(chunk)
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
