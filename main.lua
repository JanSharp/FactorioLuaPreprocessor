
local preprocessor = require("preprocessor")
local preprocess_in_memory = preprocessor.preprocess_in_memory
local args_service = require("args_service")
local path = require("path")
local dir = require("dir")

local args = args_service.get_args(arg)

---preprocesses all .luapp files in the given dir
---@param mod_dir string
local function preprocess_mod(mod_dir)
  for _, source_path in ipairs(dir.get_files_deep(mod_dir)) do
    if path.trim_last_part(source_path) ~= args.target_dir
      and args.source_extensions[path.get_extension(source_path)]
    then
      print("  "..source_path)
      local source_file = io.open(source_path, "r")
      local source_code = source_file:read("a")
      source_file:close()

      local target_code = preprocess_in_memory(source_code)

      local target_path = path.combine(
        args.target_dir,
        path.get_filename(source_path)..args.target_extension
      )

      local write_file = true
      local target_file = io.open(target_path, "r")
      if target_file then
        write_file = target_file:read("a") ~= target_code
        target_file:close()
      end

      if write_file then
        print("  "..target_path)
        target_file = io.open(target_path, "w")
        target_file:write(target_code)
        target_file:close()
      end
    end
  end
end

preprocess_mod(args.source_dir)
