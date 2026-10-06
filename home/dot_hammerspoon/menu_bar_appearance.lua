local M = {}

local listeners = {}
local usesLightForeground = nil

-- Use the system interface style rather than probing a temporary NSStatusItem.
-- Repeatedly creating status items through JXA leaks their macOS scene objects;
-- over a long session that can grow Hammerspoon until the OS jetsams it.
local function detectLightForeground()
  return hs.host.interfaceStyle() == "Dark"
end

local function refresh()
  local detected = detectLightForeground()
  if detected == usesLightForeground then
    return
  end

  usesLightForeground = detected
  for listener in pairs(listeners) do
    local ok, err = pcall(listener, usesLightForeground)
    if not ok then
      hs.printf("menu bar appearance listener failed: %s", err)
    end
  end
end

function M.subscribe(listener)
  listeners[listener] = true

  if usesLightForeground == nil then
    refresh()
  else
    listener(usesLightForeground)
  end

  if not M.appearanceWatcher then
    M.appearanceWatcher = hs.distributednotifications.new(
      refresh,
      "AppleInterfaceThemeChangedNotification"
    ):start()
  end
end

function M.unsubscribe(listener)
  listeners[listener] = nil

  if next(listeners) == nil then
    if M.appearanceWatcher then
      M.appearanceWatcher:stop()
      M.appearanceWatcher = nil
    end
    usesLightForeground = nil
  end
end

return M
