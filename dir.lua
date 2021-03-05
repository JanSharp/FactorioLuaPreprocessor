
local path = require("path")
local combine = path.combine

-- for non windows use 'ls -a "'..dir..'"' or something like that

---get all dirs in the given dir
---@param dir string @ absolute path
---@return string[]
local function get_dirs(dir)
  local i, t = 0, {}
  local pfile = io.popen('dir "'..dir..'" /b /ad')
  for filename in pfile:lines() do
    i = i + 1
    t[i] = combine(dir, filename)
  end
  pfile:close()
  return t
end

---get all files in the given dir
---@param dir string @ absolute path
---@return string[]
local function get_files(dir)
  local i, t = 0, {}
  local pfile = io.popen('dir "'..dir..'" /b /a-d')
  for filename in pfile:lines() do
    i = i + 1
    t[i] = combine(dir, filename)
  end
  pfile:close()
  return t
end

---get all files in the given dir, including files in sub dirs
---@param dir string @ absolute path
---@return string[]
local function get_files_deep(dir)
  local t = {}
  for _, sub_dir in ipairs(get_dirs(dir)) do
    for _, file in ipairs(get_files_deep(sub_dir)) do
      t[#t+1] = file
    end
  end
  for _, file in ipairs(get_files(dir)) do
    t[#t+1] = file
  end
  return t
end

return {
  get_dirs = get_dirs,
  get_files = get_files,
  get_files_deep = get_files_deep,
}
