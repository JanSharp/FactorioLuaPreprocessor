
local preprocessor = require("preprocessor")
local preprocess_in_memory = preprocessor.preprocess_in_memory
local args_service = require("args_service")
local Path = require("path")
---@type LFS
local lfs = require("lfs")

local args = args_service.get_args(arg)

-- setup preprocessor global
---@class PreprocessorGlobal
---@field args Args
---@field current_file_path Path
local global = {
  args = args,
}
-- the debugger breaks using _ENV, possibly only for the main file, but still
_G.preprocessor = global

---does the directory contain anything
---@param dir string
---@return boolean
local function dir_contains_anything(dir)
  ---@type string
  for entry_name in lfs.dir(dir) do
    if entry_name ~= "." and entry_name ~= ".." then
      return true
    end
  end
  return false
end

--TODO: make this code more maintainable... somehow

local target_dir_paths = {}
local target_file_paths = {}

local function process_source_dir(relative_path)
  ---@type string
  for entry_name in lfs.dir((args.source_dir_path / relative_path):str()) do
    if entry_name ~= "." and entry_name ~= ".." then
      local entry_path = Path.new(entry_name)
      ---@type Path
      local source_path = args.source_dir_path / relative_path / entry_path
      if source_path:attr("mode") == "directory" then
        if source_path ~= args.target_dir_path then
          target_dir_paths[(relative_path / entry_path):str()] = true
          process_source_dir(relative_path / entry_path)
        end
      else
        if args.source_extensions[source_path:extension()] then
          ---@type Path
          local relative_target_path = (relative_path / (entry_path:filename()..args.target_extension))
          target_file_paths[relative_target_path:str()] = true
          local source_file = io.open(source_path:str(), "r")
          local source_code = source_file:read("a")
          source_file:close()
          global.current_file_path = source_path
          local target_code = preprocess_in_memory(source_code)
          local target_path = args.target_dir_path / relative_target_path
          local write_file = true
          local target_file = io.open(target_path:str(), "r")
          if target_file then
            write_file = target_file:read("a") ~= target_code
            target_file:close()
          end
          if write_file then
            if not target_path:sub(1, -2):exists() then
              lfs.mkdir(target_path:sub(1, -2):str())
            end
            target_file = io.open(target_path:str(), "w")
            target_file:write(target_code)
            target_file:close()
          end
        end
      end
    end
  end
end

local function process_target_dir(relative_path)
  ---@type string
  for entry_name in lfs.dir((args.target_dir_path / relative_path):str()) do
    if entry_name ~= "." and entry_name ~= ".." then
      local entry_path = Path.new(entry_name)
      local target_path = args.target_dir_path / relative_path / entry_path
      if target_path:attr("mode") == "directory" then
        if target_path ~= args.source_dir_path then
          if target_dir_paths[(relative_path / entry_path):str()] then
            process_target_dir(relative_path / entry_path)
          else
            process_target_dir(relative_path / entry_path)
            if not dir_contains_anything(target_path:str()) then
              lfs.rmdir(target_path:str())
            end
          end
        end
      else
        if target_path:extension() == args.target_extension then
          local relative_target_path = relative_path / entry_path ---@type Path
          if not target_file_paths[relative_target_path:str()] then
            os.remove((args.target_dir_path / relative_target_path):str())
          end
        end
      end
    end
  end
end

process_source_dir(Path.new())
if args.auto_clean_up_target_dir then
  process_target_dir(Path.new())
end
