
local Path = require("path")

local insert = table.insert
local format = string.format

---set in preprocess
local args

---@class Any

---@generic T
---@param obj T
---@return T
local function deepcopy(obj)
  local lookup_table = {}
  local function _copy(sub_obj)
    if type(sub_obj) ~= "table" then
      return sub_obj
    -- don't copy factorio rich objects
    elseif sub_obj.__self then
      return sub_obj
    elseif lookup_table[sub_obj] then
      return lookup_table[sub_obj]
    end
    local new_table = {}
    lookup_table[sub_obj] = new_table
    for index, value in pairs(sub_obj) do ---@type Any
      new_table[_copy(index)] = _copy(value)
    end
    return setmetatable(new_table, getmetatable(sub_obj))
  end
  return _copy(obj)
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

---`$s(foo)` gets turned into `"foo"`. Meant for "macro" parameters, but might be useful otherwise as well\
---`e` stands for `expression` or `escape`
---@param chunk string
---@return string
local function expression_as_string(chunk)
  return chunk:gsub("$e(%b())", function(m) return format("%q", m:sub(2, -2)) end)
end

---`$foo` gets turned into `"foo"`. Meant for "macro" parameters, but might be useful otherwise as well
---@param chunk string
---@return string
local function identifier_as_string(chunk)
  return chunk:gsub("$([a-zA-Z_][a-zA-Z0-9_]*)", function(m) return '"'..m..'"' end)
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
    insert(pieces, format("_put(%q)", string.sub(chunk, s, term - 1)))
    if load("return "..executed) then
      insert(pieces, format("_put(%s or '')", executed))
    else
      insert(pieces, executed:sub(2, -2))
    end
    -- table.insert(pieces, string.format("%q..(%s or '')..",
    --   string.sub(chunk, s, term - 1), executed))
    s = e
  end
  insert(pieces, format("_put(%q)", string.sub(chunk, s)))
end

---@param chunk string
---@param newline string
---@return string
local function parse_hash_lines(chunk, newline)
  local pieces = {"local main = function() "}
  local s = 1
  while true do
    ---@typelist integer, integer, string
    local ss, e, lua = string.find(chunk, "^%s*#+([^\n]*\n?)", s)
    if not e then
      ---@typelist integer, integer, string
      ss, e, lua = string.find(chunk, "\n%s*#+([^\n]*\n?)", s)
      parse_dollar_paren(pieces, string.sub(chunk, s, ss))
      insert(pieces, newline)
      if not e then break end
    end
    insert(pieces, lua)
    insert(pieces, newline)
    s = e + 1
  end
  insert(pieces, " end return function(_put) _ENV._put = _put main() end")
  return table.concat(pieces)
end

-- `prep` sandbox global
local prep = {
  Path = Path,
  args = nil,
  ret = nil,
  require = nil,
  package = nil,
  current_file_path = nil, -- set in main.lua
}

-- sandbox `_ENV`
local prep_env = {
  _VERSION = _VERSION,
  coroutine = coroutine,
  -- arg = arg,
  assert = assert,
  collectgarbage = collectgarbage,
  debug = debug,
  dofile = dofile,
  error = error,
  getmetatable = getmetatable,
  ipairs = ipairs,
  load = load,
  loadfile = loadfile,
  math = math,
  next = next,
  os = os,
  -- package = package,
  pairs = pairs,
  pcall = pcall,
  print = print,
  rawequal = rawequal,
  rawget = rawget,
  rawlen = rawlen,
  rawset = rawset,
  -- require = require,
  select = select,
  setmetatable = setmetatable,
  string = string,
  table = table,
  tonumber = tonumber,
  tostring = tostring,
  type = type,
  utf8 = utf8,
  warn = warn,
  xpcall = xpcall,
}
prep_env = deepcopy(prep_env)
prep_env.prep = prep
prep_env._G = prep_env

---@param chunk string
---@param _args Args
---@param name? string @ Default: `nil`
---@param newline? string @ Default: `"\n"`
---@return function(string: _put) return string
local function preprocess(chunk, _args, name, newline)
  args = _args
  prep.args = args
  chunk = ignored_by_language_server(chunk)
  chunk = ignored_by_preprocessor(chunk)
  chunk = expression_as_string(chunk)
  chunk = identifier_as_string(chunk)
  chunk = preprocess_lambda_expressions(chunk)
  chunk = trim_type_constructors(chunk)
  chunk = parse_hash_lines(chunk)
  return assert(load(chunk, name, "t", prep_env))()
end

---@param src string
---@param _args Args
---@param newline? string @ Default: `"\n"`
---@return string
local function preprocess_in_memory(src, _args, newline)
  local parts = {}
  ---@param s string
  local function put(s)
    table.insert(parts, s)
  end
  preprocess(src, _args, nil, newline)(put)
  return table.concat(parts)
end

local current_return_value

---@param result Any
function prep.ret(result)
  current_return_value = result
end

local prep_package = {
  loaded = {},
}
prep.package = prep_package

---@param module string
function prep.require(module)
  if not module:find("/") then
    module = module:gsub("%.", "/")
  end
  if prep_package.loaded[module] then
    return prep_package.loaded[module]
  end
  local module_dir_path = args.source_dir_path / module ---@type Path
  local filename = module_dir_path.entries[#module_dir_path.entries]
  module_dir_path = module_dir_path:sub(1, -2)
  for _, extension in ipairs(args.source_extensions) do
    local module_path = module_dir_path / (filename..extension) ---@type Path
    if module_path:exists() then
      local module_file = io.open(module_path:str(), "r")
      local module_code = module_file:read("a")
      module_file:close()
      local _put = prep_env._put ---@type fun(part: string)
      preprocess(module_code, args, "=(Module '"..module.."')")(function() end)
      prep_env._put = _put
      local result = current_return_value or true
      current_return_value = nil
      prep_package.loaded[module] = result
      return result
    end
  end
  error("Unable to locate module '"..module.."'.")
end
prep_env.require = prep.require

return {
  preprocess = preprocess,
  preprocess_in_memory = preprocess_in_memory,
  prep_env = prep_env,
}

-- fix semantics