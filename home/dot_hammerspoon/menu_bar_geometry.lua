local M = {}

local geometryScript = hs.configdir .. "/menu_bar_geometry.js"
local areas = nil

local function loadAreas()
  local output, ok = hs.execute("/usr/bin/osascript -l JavaScript " .. geometryScript)
  if not ok or type(output) ~= "string" or output == "" then
    return {}
  end

  local decodedOk, decoded = pcall(hs.json.decode, output)
  if not decodedOk or type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

function M.area(appKitIndex, side)
  areas = areas or loadAreas()
  local screen = areas[appKitIndex]
  local area = screen and screen[side] or nil
  if type(area) ~= "table" or (area.w or 0) <= 0 then
    return nil
  end
  return area
end

function M.invalidate()
  areas = nil
end

return M
