
local preprocessor = require("preprocessor")
local preprocess_in_memory = preprocessor.preprocess_in_memory
local args_service = require("args_service")
require("path")
local dir = require("dir")

local args = args_service.get_args(arg)

---preprocesses all .luapp files in the given dir
---@param mod_dir_path Path
local function preprocess_mod(mod_dir_path)
  for _, source_path in ipairs(dir.get_files_deep(mod_dir_path)) do
    if source_path:sub(1, -2) ~= args.target_dir_path
      and args.source_extensions[source_path:extension()]
    then
      local source_file = io.open(source_path:str(), "r")
      local source_code = source_file:read("a")
      source_file:close()

      local target_code = preprocess_in_memory(source_code)

      local sub_dir = source_path:sub(#args.source_dir_path + 1, -2)
      local target_dir_path = args.target_dir_path / sub_dir
      local target_path = target_dir_path / (source_path:filename()..args.target_extension)

      local write_file = true
      local target_file = io.open(target_path:str(), "r")
      if target_file then
        write_file = target_file:read("a") ~= target_code
        target_file:close()
      end

      if write_file then
        target_file = io.open(target_path:str(), "w")
        target_file:write(target_code)
        target_file:close()
      end
    end
  end
end

preprocess_mod(args.source_dir_path)
