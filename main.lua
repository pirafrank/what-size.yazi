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

-- Function to get total size from dua output
-- dua output format: "\u{1b}[32m1026520530 b\u{1b}[39m \u{1b}[36manythingllm-desktop\u{1b}[39m\n"
local function get_dua_total_size(stdout)
  local lines = {}
  for line in stdout:gmatch("[^\n]+") do lines[#lines + 1] = line end
  local last_line = lines[#lines]
  local size_str = last_line:match("(%d+) b")
  return tonumber(size_str)
end

-- Function to get total size from output
-- Unix use `du`, Windows use PowerShell, or dua if specified
local function get_total_size(items, use_dua)
  -- If dua is specified, use it regardless of platform
  if use_dua then
    local output, err = Command("dua"):args({"--format", "bytes"}):args(items):output()
    if not output or not output.stdout then
      ya.err("Failed to run dua: " .. (err and err.message or "unknown error"))
      return nil
    end
    return get_dua_total_size(output.stdout)
  end

  -- Otherwise use platform-specific commands
  local is_windows = package.config:sub(1,1) == '\\'

  if is_windows then
    local total = 0
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
    local cmd = "du"
    local output, err = Command(cmd):arg("-scb"):args(items):output()
    if not output then
      ya.err("Failed to run du: " .. err)
    end
    local lines = {}
    for line in output.stdout:gmatch("[^\n]+") do lines[#lines + 1] = line end
    local last_line = lines[#lines]
    local size = tonumber(last_line:match("^(%d+)"))
    return size
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
  -- as per doc: [https://yazi-rs.github.io/docs/plugins/overview#functional-plugin](https://yazi-rs.github.io/docs/plugins/overview#functional-plugin)
  entry = function(_, job)
    -- Check for arguments
    local clipboard = false
    local use_dua = false
    
    -- Parse arguments
    for _, arg in ipairs(job.args) do
      if arg == "--clipboard" or arg == "-c" or arg == "clipboard" then
        clipboard = true
      elseif arg == "--dua" or arg == "dua" then
        use_dua = true
      end
    end
    
    local items = get_paths()

    ya.dbg({
      items = items,
      job_args = job.args,
      use_dua = use_dua,
      clipboard = clipboard
    })

    local total_size = get_total_size(items, use_dua)
    
    if not total_size then
      ya.err("Failed to get total size")
      return
    end
    
    local formatted_size = format_size(total_size)

    local notification_content = "Total size: " .. formatted_size
    if clipboard then
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
