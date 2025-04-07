-- function to get paths of selected elements or current directory
-- if no elements are selected
local get_paths = ya.sync(function()
  local paths = {}
  -- get selected files
  for _, u in pairs(cx.active.selected) do
    paths[#paths + 1] = tostring(u)
  end
  -- if no files are selected, get current directory
  if #paths == 0 then
    if cx.active.current.cwd then
      paths[1] = tostring(cx.active.current.cwd)
    else
      ya.err("what-size would return nil paths")
    end
  end
  return paths
end)

-- Function to parse job arguments based on expected definitions
-- Parses arguments passed to the Yazi plugin via `job.args`.
-- Handles:
-- 1. Default values defined in `expected_args`.
-- 2. Named arguments parsed by Yazi (e.g., `--clipboard` becomes `job.args.clipboard = true`).
--    These take precedence.
-- 3. Positional arguments that match an expected argument name or its aliases (e.g., `clipboard` or `-c`).
--    These are treated as boolean flags (set to true) if not already set by a named argument.
--
-- `job`: The job object passed to the plugin's entry function.
-- `expected_args`: A table defining the expected arguments.
--   Format: { arg_name = { default = default_value, aliases = {"alias1", "alias2"} }, ... }
--   `aliases` is optional.
--
-- Assumes `expected_args = { clipboard = { default = false, aliases = {"-c", "clipboard"} } }`.
--
-- | Command                           | `job.args` (Yazi)         | `parsed_args` (Output) | Notes                                                                  |
-- | :-------------------------------- | :------------------------ | :--------------------- | :--------------------------------------------------------------------- |
-- | `plugin what-size -- --clipboard` | `{ clipboard=true }`      | `{ clipboard=true }`   | Yazi parses `--clipboard`. Function uses it.                           |
-- | `plugin what-size -- clipboard`   | `{ args[1]="clipboard" }` | `{ clipboard=true }`   | Yazi parses positional. Function finds alias.                            |
-- | `plugin what-size -- -c`          | `{ args[1]="-c" }`        | `{ clipboard=true }`   | Yazi parses positional. Function finds alias.                            |
-- | `plugin what-size --clipboard`    | `{ }`                     | `{ clipboard=false }`  | Yazi *fails* to parse `--clipboard` due to following `--`. Default used. |
-- | `plugin what-size -c --`          | `{ args[1]="-c" }`        | `{ clipboard=true }`   | Yazi parses positional `-c`. Function finds alias.                       |
-- | `plugin what-size clipboard`      | `{ args[1]="clipboard" }` | `{ clipboard=true }`   | Yazi parses positional `clipboard`. Function finds alias.                |
local function parse_args(job, expected_args)
  local parsed_args = {}

  ya.dbg("Parsing args:", { job_args = job.args, expected_args = expected_args })

  -- Set defaults
  for name, config in pairs(expected_args) do
    parsed_args[name] = config.default
  end

  ya.dbg("Args after defaults:", parsed_args)

  -- Check named arguments provided by Yazi (e.g., --clipboard -> job.args.clipboard = true)
  for name, config in pairs(expected_args) do
    -- Prioritize Yazi's named args parsing
    if job.args[name] ~= nil then
      ya.dbg("Found named arg:", { name = name, value = job.args[name], overriding_default = parsed_args[name] })
      parsed_args[name] = job.args[name] -- Handles --arg=value and --arg (sets to true)
    end
  end

  -- Check positional arguments for aliases or full names used as flags
  -- Handles cases like `plugin what-size -- clipboard` or `plugin what-size -- -c`
  for i, arg_val in ipairs(job.args) do
    ya.dbg("Checking positional arg:", { index = i, value = arg_val })
    for name, config in pairs(expected_args) do
      -- Check if the positional arg matches the name or an alias
      local matched = false
      if arg_val == name then
        ya.dbg("Positional arg matches name:", { name = name })
        matched = true
      elseif config.aliases then
        for _, alias in ipairs(config.aliases) do
          if arg_val == alias then
            ya.dbg("Positional arg matches alias:", { alias = alias, for_name = name })
            matched = true
            break
          end
        end
      end

      -- If matched and not already set by a named arg, set to true (treat as flag)
      if matched and job.args[name] == nil then
        ya.dbg("Setting flag from positional arg:", { name = name, value = true })
        parsed_args[name] = true
        goto next_positional -- Avoid matching the same positional arg for multiple expected args
      end
    end
    ::next_positional::
  end

  ya.dbg("Final parsed args:", parsed_args)
  return parsed_args
end

-- Function to check if dua is present in the PATH
local function is_dua_present()
  ya.dbg("Checking for dua presence...")
  -- Try running `dua --version`. If it succeeds without error, dua is likely present.
  local _, err = Command("dua"):arg("--version"):output()
  local present = err == nil
  ya.dbg("dua present:", present)
  return present
end

-- Parses the output of `dua --format bytes`
local function parse_dua_output(stdout)
  local lines = {}
  for line in stdout:gmatch("[^\n]+") do lines[#lines + 1] = line end
  local last_line = lines[#lines]
  if not last_line then
    ya.err("dua output was empty or did not contain lines.")
    return nil
  end
  local size_str = last_line:match("(%d+) b")
  if not size_str then
    ya.err("Could not parse size from dua output: " .. last_line)
    return nil
  end
  return tonumber(size_str)
end

-- Function to get total size using dua
local function get_total_size_dua(items)
  local output, err = Command("dua"):arg("--format"):arg("bytes"):args(items):output()
  if err or not output or not output.stdout then
    ya.err("Failed to run dua: " .. (err and err.message or "unknown error/no output"))
    return nil -- Indicate failure
  else
    local size = parse_dua_output(output.stdout)
    if not size then
      ya.err("Failed to parse dua output.")
      return nil -- Indicate failure
    end
    return size
  end
end

-- Function to get total size from output
-- Unix use `du`, Windows use PowerShell
local function get_total_size_platform_specific(items)
  -- Otherwise use platform-specific commands
  local is_windows = package.config:sub(1,1) == '\\'

  if is_windows then
    local total = 0
    ya.dbg("Using PowerShell for size calculation.")
    for _, path in ipairs(items) do
      path = path:gsub('"', '\\"')
      local ps_cmd = string.format(
      [[powershell -Command "& { $p = '%s'; if (Test-Path $p) { if ((Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) { (Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } else { (Get-Item $p).Length } } }"]],
      path
      )
      local pipe = io.popen(ps_cmd)
      local result = pipe:read("*a")
      -- Debug
      -- ya.notify {
      --     title = "Debug Output",
      --     content = result,
      --     timeout = 5,
      -- }
      pipe:close()
      local num = tonumber(result)
      if num then total = total + num end
    end
    return total
  else
    ya.dbg("Using `du` for size calculation.")
    local arg = ya.target_os() == "macos" and "-scA" or "-scb"
    local output, err = Command("du"):arg(arg):args(items):output()
    if not output then
      ya.err("Failed to run du: " .. err)
    end
    local lines = {}
    for line in output.stdout:gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end
    local last_line = lines[#lines]
    local size = tonumber(last_line:match("^(%d+)"))
    return ya.target_os() == "macos" and size * 512 or size
  end
end

-- Function to format file size
local function format_size(size)
  local units = { "B", "KB", "MB", "GB", "TB" }
  local unit_index = 1
  while size > 1024 and unit_index < #units do
    size = size / 1024
    unit_index = unit_index + 1
  end
  return string.format("%.2f %s", size, units[unit_index])
end

return {
  -- as per doc: https://yazi-rs.github.io/docs/plugins/overview#functional-plugin
  entry = function(_, job)
    local args = parse_args(job, {
      clipboard = { default = false, aliases = {"-c", "clipboard"} },
      dua = { default = false, aliases = {"dua"} },
      no_dua = { default = false, aliases = {"no-dua"} }
    })

    local items = get_paths()
    local total_size = nil

    local use_dua = args.dua or (not args.no_dua and is_dua_present())

    if use_dua then
      total_size = get_total_size_dua(items)
      -- If dua fails (returns nil), we intentionally fall through to platform specific
      if total_size then
        ya.dbg("DUA calculation successful.")
      else
        ya.err("DUA calculation failed, falling back to platform specific.")
        ya.notify {
          title = "What size",
          content = "dua failed, add -- no-dua",
          timeout = 4,
        }
      end
    end

    -- Use platform specific if dua is disabled, not present, or failed
    if not total_size then
      ya.dbg("Calculating size using platform-specific command.")
      total_size = get_total_size_platform_specific(items)
    end

    if not total_size then
      ya.err("Failed to get total size")
      return
    end
    
    local formatted_size = format_size(total_size)

    local notification_content = "Total size: " .. formatted_size
    if args.clipboard then
      ya.clipboard(formatted_size)
      notification_content = notification_content .. "\nCopied to clipboard."
    end

    ya.notify {
      title = "What size",
      content = notification_content,
      timeout = 4,
    }
  end,
}
