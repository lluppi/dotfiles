local M = {}

local aerospace = "/opt/homebrew/bin/aerospace"
local refreshInterval = 0.5
local focusDelay = 0.05
local windowUnderPointerProperty = hs.eventtap.event.properties.mouseEventWindowUnderMousePointer

M.running = false
M.tiledWindowIds = {}
M.floatingWindowIds = {}
M.raiseTimers = {}
M.refreshPending = false
M.hasManagedWindowSnapshot = false

local function scheduleFloatingFocus(windowId)
  if M.raiseTimers[windowId] then
    M.raiseTimers[windowId]:stop()
  end

  M.raiseTimers[windowId] = hs.timer.doAfter(0.05, function()
    M.raiseTimers[windowId] = nil
    if not M.floatingWindowIds[windowId] then
      return
    end

    local window = hs.window.get(windowId)
    if window then
      window:focus()
      M.lastAutoFocusedWindowId = windowId
    end
  end)
end

local function refreshManagedWindows()
  if M.refreshTask and M.refreshTask:isRunning() then
    M.refreshPending = true
    return
  end

  M.refreshTask = hs.task.new(aerospace, function(exitCode, stdout, stderr)
    M.refreshTask = nil

    if exitCode == 0 then
      local tiledWindowIds = {}
      local floatingWindowIds = {}
      for line in stdout:gmatch("[^\r\n]+") do
        local windowId, layout = line:match("^(%d+)|(.+)$")
        windowId = tonumber(windowId)
        if windowId and layout == "floating" then
          floatingWindowIds[windowId] = true
        elseif windowId and layout then
          tiledWindowIds[windowId] = true
        end
      end

      local previousFloatingWindowIds = M.floatingWindowIds
      M.tiledWindowIds = tiledWindowIds
      M.floatingWindowIds = floatingWindowIds

      if M.hasManagedWindowSnapshot then
        for windowId in pairs(floatingWindowIds) do
          if not previousFloatingWindowIds[windowId] then
            scheduleFloatingFocus(windowId)
          end
        end
      else
        M.hasManagedWindowSnapshot = true
      end
    else
      hs.printf("tiling focus refresh failed: %s", stderr)
    end

    if M.refreshPending then
      M.refreshPending = false
      refreshManagedWindows()
    end
  end, {
    "list-windows",
    "--all",
    "--format",
    "%{window-id}|%{window-layout}",
  })

  if not M.refreshTask:start() then
    M.refreshTask = nil
  end
end

local function focusTiledWindow(windowId)
  local focusedWindow = hs.window.focusedWindow()

  -- A focused floating or unmanaged utility owns focus until the user clicks
  -- elsewhere. This keeps it visible while the pointer moves across tiles.
  if not focusedWindow or not M.tiledWindowIds[focusedWindow:id()] then
    return
  end

  if not windowId or not M.tiledWindowIds[windowId] or windowId == focusedWindow:id() then
    return
  end

  -- Resolve a window only when focus will actually cross to another tile.
  -- The mouse event already carries the exact topmost window ID, avoiding a
  -- full application/window scan on every pointer movement.
  local hoveredWindow = hs.window.get(windowId)
  if hoveredWindow then
    hoveredWindow:focus()
  end
end

local function scheduleFocus(windowId)
  M.pendingWindowId = windowId
  if M.focusTimer then
    return
  end

  M.focusTimer = hs.timer.doAfter(focusDelay, function()
    local pendingWindowId = M.pendingWindowId
    M.pendingWindowId = nil
    M.focusTimer = nil
    if pendingWindowId then
      focusTiledWindow(pendingWindowId)
    end
  end)
end

function M.snapshot()
  local tiledWindowIds = {}
  local floatingWindowIds = {}
  for windowId in pairs(M.tiledWindowIds) do
    table.insert(tiledWindowIds, windowId)
  end
  for windowId in pairs(M.floatingWindowIds) do
    table.insert(floatingWindowIds, windowId)
  end
  table.sort(tiledWindowIds)
  table.sort(floatingWindowIds)

  local focusedWindow = hs.window.focusedWindow()
  local focusedWindowId = focusedWindow and focusedWindow:id() or nil

  return {
    running = M.running,
    mouseTapEnabled = M.mouseTap and M.mouseTap:isEnabled() or false,
    tiledWindowIds = tiledWindowIds,
    floatingWindowIds = floatingWindowIds,
    hasManagedWindowSnapshot = M.hasManagedWindowSnapshot,
    lastAutoFocusedWindowId = M.lastAutoFocusedWindowId,
    focusedWindowId = focusedWindowId,
    focusedWindowIsTiled = focusedWindowId and M.tiledWindowIds[focusedWindowId] or false,
  }
end

function M.start()
  if M.running then
    return M
  end

  M.running = true
  M.mouseTap = hs.eventtap.new({ hs.eventtap.event.types.mouseMoved }, function(event)
    scheduleFocus(event:getProperty(windowUnderPointerProperty))
    return false
  end):start()
  M.refreshTimer = hs.timer.doEvery(refreshInterval, refreshManagedWindows)
  refreshManagedWindows()
  return M
end

function M.stop()
  M.running = false
  for _, timer in ipairs({ M.refreshTimer, M.focusTimer }) do
    if timer then
      timer:stop()
    end
  end
  M.refreshTimer = nil
  M.focusTimer = nil
  for _, timer in pairs(M.raiseTimers) do
    timer:stop()
  end
  M.raiseTimers = {}
  M.pendingWindowId = nil
  if M.mouseTap then
    M.mouseTap:stop()
    M.mouseTap = nil
  end
  if M.refreshTask and M.refreshTask:isRunning() then
    M.refreshTask:terminate()
  end
  M.refreshTask = nil
  M.refreshPending = false
  return M
end

return M
