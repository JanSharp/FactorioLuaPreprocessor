
---combine all path parts using / (slashes)
---@vararg string[]
---@return string
local function combine(...)
  return table.concat({...}, "/")
end

---get the last part of the path which can be the filename or the last directory
---@param path string
---@return string
local function get_last_part(path)
  return string.match(path, "/([^/]*)$") or path
end

---trims the last part of the path which can be a filename or a directory
---@param path string
---@return string
local function trim_last_part(path)
  return string.match(path, "(.-)/?[^/]*$")
end

---get the extension of the path
---@param path string
---@return string
local function get_extension(path)
  return string.match(get_last_part(path), "(%.[^.]*)$") or ""
end

---get the filename of the path
---@param path string
---@return string
local function get_filename(path)
  return string.match(get_last_part(path), "(.-)%.?[^.]*$")
end

return {
  combine = combine,
  trim_last_part = trim_last_part,
  get_last_part = get_last_part,
  get_extension = get_extension,
  get_filename = get_filename,
}
