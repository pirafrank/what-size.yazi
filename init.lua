
-- function to get paths of selected elements or current directory
-- of no elements are selected
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

-- Function to get total size from du output
local get_total_size = function(s)
  local lines = {}
  for line in s:gmatch("[^\n]+") do lines[#lines + 1] = line end
  local last_line = lines[#lines]
  local last_line_parts = {}
  for part in last_line:gmatch("%S+") do last_line_parts[#last_line_parts + 1] = part end
  local total_size = last_line_parts[1]
  return total_size
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
  entry = function(self, args)
    -- defaults not to use clipboard, use it only if required by the user
    local clipboard = args[1] == '--clipboard' or args[1] == '-c'
    local items = get_paths()

    local cmd = "du"
    local output, err = Command(cmd):arg("-scb"):args(items):output()
    if not output then
      ya.err("Failed to run diff, error: " .. err)
    else
      local total_size = get_total_size(output.stdout)
      local formatted_size = format_size(tonumber(total_size))

      local notification_content = "Total size: " .. formatted_size
      if clipboard then
        ya.clipboard(formatted_size)
        notification_content = notification_content .. "\nCopied to clipboard."
      end

      ya.notify {
        title = "What size",
        content = notification_content,
        timeout = 5,
      }
    end
  end,
}
