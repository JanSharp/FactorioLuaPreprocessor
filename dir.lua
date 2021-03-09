
require("path")

-- for non windows use 'ls -a "'..dir..'"' or something like that

---get all dirs in the given dir
---@param dir Path @ absolute path
---@return Path[]
local function get_dirs(dir)
  local i, t = 0, {}
  local pfile = io.popen('dir "'..dir:str()..'" /b /ad')
  for filename in pfile:lines() do
    i = i + 1
    t[i] = dir / filename
  end
  pfile:close()
  return t
end

---get all files in the given dir
---@param dir Path @ absolute path
---@return Path[]
local function get_files(dir)
  local i, t = 0, {}
  local pfile = io.popen('dir "'..dir:str()..'" /b /a-d')
  for filename in pfile:lines() do
    i = i + 1
    t[i] = dir / filename
  end
  pfile:close()
  return t
end

---get all files in the given dir, including files in sub dirs
---@param dir Path @ absolute path
---@return Path[]
local function get_files_deep(dir)
  local t = {}
  for _, sub_dir in ipairs(get_dirs(dir)) do
    for _, path in ipairs(get_files_deep(sub_dir)) do
      t[#t+1] = path
    end
  end
  for _, path in ipairs(get_files(dir)) do
    t[#t+1] = path
  end
  return t
end

return {
  get_dirs = get_dirs,
  get_files = get_files,
  get_files_deep = get_files_deep,
}
