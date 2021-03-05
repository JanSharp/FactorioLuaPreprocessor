
local args_util = require("args_util")

---@param arg string[]
---@return table<string, string|string[]>
local function get_args(arg)
  local args = args_util.parse_args(arg)

  ---@param group_name string
  local function get_original_group_name(group_name)
    return string.gsub(group_name, "_", "-")
  end

  local function rename_groups()
    local result = {}
    ---@typelist string, string[]
    for k, v in pairs(args) do
      result[string.gsub(k, "%-", "_")] = v
    end
    args = result
  end

  ---@param group_name string
  local function assert_group(group_name)
    assert(args[group_name], "Program args missing parameter group '--"
      ..get_original_group_name(group_name).."'."
    )
  end

  ---@param group_name string
  local function convert_to_map(group_name)
    local result = {}
    for _, v in ipairs(args[group_name]) do
      result[v] = true
    end
    args[group_name] = result
  end

  ---@param group_name string
  local function single(group_name)
    assert(#args[group_name] == 1, "Program args group '--"
      ..get_original_group_name(group_name).."' must contain one single value."
    )
    args[group_name] = args[group_name][1]
  end

  rename_groups()

  assert_group("source_extensions")
  assert_group("source_dir")
  assert_group("target_extension")
  assert_group("target_dir")

  convert_to_map("source_extensions")

  single("source_dir")
  single("target_extension")
  single("target_dir")

  return args
end

return {
  get_args = get_args,
}
