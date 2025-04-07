
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

-- Function to get total size from output
-- Unix use `du`, Windows use PowerShell
local function get_total_size(items)
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
    -- defaults not to use clipboard, use it only if required by the user
    local clipboard = job.args.clipboard == true or job.args[1] == "--clipboard" or job.args[1] == "-c"
    local items = get_paths()

    local total_size = get_total_size(items)
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
