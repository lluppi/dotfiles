local M = {}

local geometryScript = hs.configdir .. "/menu_bar_geometry.js"
local areas = nil
local stale = false
local loadedSignature = nil

-- Screen UUIDs plus full frames: the osascript result only changes with these.
local function screenSignature()
  local parts = {}
  for _, screen in ipairs(hs.screen.allScreens()) do
    local frame = screen:fullFrame()
    table.insert(parts, string.format("%s@%s,%s,%s,%s", tostring(screen:getUUID()), frame.x, frame.y, frame.w, frame.h))
  end
  return table.concat(parts, ";")
end

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
  if areas ~= nil and stale then
    stale = false
    if screenSignature() ~= loadedSignature then
      areas = nil
    end
  end
  if areas == nil then
    loadedSignature = screenSignature()
    areas = loadAreas()
  end
  local screen = areas[appKitIndex]
  local area = screen and screen[side] or nil
  if type(area) ~= "table" or (area.w or 0) <= 0 then
    return nil
  end
  return area
end

function M.invalidate()
  stale = true
end

return M
