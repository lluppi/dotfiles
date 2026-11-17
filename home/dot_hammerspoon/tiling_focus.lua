local M = {}

local aerospace = "/opt/homebrew/bin/aerospace"
local safetyInterval = 5
local trailingDelay = 0.25
local bindingFallbackDelays = { 0.4, 1.2 }
local focusDelay = 0.05
local windowUnderPointerProperty = hs.eventtap.event.properties.mouseEventWindowUnderMousePointer

M.running = false
M.tiledWindowIds = {}
M.floatingWindowIds = {}
M.raiseTimers = {}
M.bindingTimers = {}
M.refreshPending = false
M.hasManagedWindowSnapshot = false
M.unknownRequested = {}
M.refreshCounts = {}
M.safetyCorrections = 0
M.pendingSafety = false

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

local function startRefresh(reason)
  local isSafety = reason == "safety"

  if M.refreshTask and M.refreshTask:isRunning() then
    M.refreshPending = true
    M.pendingReason = reason
    if isSafety then
      M.pendingSafety = true
    end
    return
  end

  local runIsSafety = isSafety or M.pendingSafety
  M.pendingSafety = false

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
      local previousTiledWindowIds = M.tiledWindowIds
      M.tiledWindowIds = tiledWindowIds
      M.floatingWindowIds = floatingWindowIds
      M.lastRefreshReason = reason
      M.lastRefreshAt = hs.timer.secondsSinceEpoch()

      if M.hasManagedWindowSnapshot then
        for windowId in pairs(floatingWindowIds) do
          if not previousFloatingWindowIds[windowId] then
            scheduleFloatingFocus(windowId)
          end
        end

        if runIsSafety then
          local corrected = 0
          for windowId in pairs(floatingWindowIds) do
            if not previousFloatingWindowIds[windowId] then
              corrected = corrected + 1
            end
          end
          for windowId in pairs(tiledWindowIds) do
            if not previousTiledWindowIds[windowId] then
              corrected = corrected + 1
            end
          end
          if corrected > 0 then
            M.safetyCorrections = M.safetyCorrections + corrected
            hs.printf("tiling focus: safety poll corrected %d ids", corrected)
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
      local pendingReason = M.pendingReason or reason
      M.pendingReason = nil
      startRefresh(pendingReason)
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

function M.requestRefresh(reason)
  reason = reason or "unspecified"
  M.refreshCounts[reason] = (M.refreshCounts[reason] or 0) + 1
  startRefresh(reason)
end

local function noteUnknownWindow(windowId)
  if windowId and not M.tiledWindowIds[windowId] and not M.floatingWindowIds[windowId]
    and not M.unknownRequested[windowId] then
    M.unknownRequested[windowId] = true
    M.requestRefresh("unknown-hover")
  end
end

local function focusTiledWindow(windowId)
  local focusedWindow = hs.window.focusedWindow()
  if focusedWindow then
    noteUnknownWindow(focusedWindow:id())
  end

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
  if M.focusTimer and not M.focusTimer:running() then
    M.focusTimer:start()
  end
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
    lastRefreshReason = M.lastRefreshReason,
    lastRefreshAt = M.lastRefreshAt,
    refreshCounts = M.refreshCounts,
    safetyCorrections = M.safetyCorrections,
    subscriptionRunning = M.subscription and M.subscription:isRunning() or false,
    focusedWindowIsTiled = focusedWindowId and M.tiledWindowIds[focusedWindowId] or false,
  }
end

local function clearUnknownRequested()
  M.unknownRequested = {}
end

local function handleEvent(event)
  local name = event._event
  clearUnknownRequested()
  if name == "window-detected" then
    M.requestRefresh("window-detected")
    if M.trailingTimer then
      M.trailingTimer:stop()
    end
    M.trailingTimer = hs.timer.doAfter(trailingDelay, function()
      M.trailingTimer = nil
      M.requestRefresh("window-detected-trailing")
    end)
  elseif name == "focus-changed" or name == "focused-workspace-changed" or name == "focused-monitor-changed" then
    M.requestRefresh(name)
  elseif name == "binding-triggered" then
    -- Backstop for the float toggle (cmd-f / cmd-alt-space): it changes layout
    -- without a focus event, and its direct `hs -c` notify can fail. The exact
    -- binding string is unconfirmed, so every binding refreshes; bindings fire
    -- at human speed, so this costs a couple of queries per keypress.
    for _, timer in ipairs(M.bindingTimers) do
      timer:stop()
    end
    M.bindingTimers = {}
    for _, delay in ipairs(bindingFallbackDelays) do
      table.insert(M.bindingTimers, hs.timer.doAfter(delay, function()
        M.requestRefresh("binding-fallback")
      end))
    end
  end
end

function M.start()
  if M.running then
    return M
  end

  M.running = true
  M.focusTimer = hs.timer.new(focusDelay, function()
    M.focusTimer:stop()
    local pendingWindowId = M.pendingWindowId
    M.pendingWindowId = nil
    if pendingWindowId then
      focusTiledWindow(pendingWindowId)
    end
  end)
  M.mouseTap = hs.eventtap.new({ hs.eventtap.event.types.mouseMoved }, function(event)
    local windowId = event:getProperty(windowUnderPointerProperty)
    noteUnknownWindow(windowId)
    if not windowId or not M.tiledWindowIds[windowId] then
      -- Not a tile: nothing to focus. Drop any armed target so a pending timer
      -- cannot focus the previous tile after the pointer left it.
      M.pendingWindowId = nil
      return false
    end
    scheduleFocus(windowId)
    return false
  end):start()
  M.subscription = require("aerospace_events").new({
    "window-detected",
    "focus-changed",
    "focused-workspace-changed",
    "focused-monitor-changed",
    "binding-triggered",
  }, handleEvent, {
    onStart = function()
      M.requestRefresh("subscribe-start")
    end,
  }):start()
  M.safetyTimer = hs.timer.doEvery(safetyInterval, function()
    clearUnknownRequested()
    M.requestRefresh("safety")
  end)
  M.requestRefresh("start")
  return M
end

function M.stop()
  M.running = false
  for _, timer in pairs({ safety = M.safetyTimer, focus = M.focusTimer, trailing = M.trailingTimer }) do
    timer:stop()
  end
  M.safetyTimer = nil
  M.focusTimer = nil
  M.trailingTimer = nil
  for _, timer in ipairs(M.bindingTimers) do
    timer:stop()
  end
  M.bindingTimers = {}
  if M.subscription then
    M.subscription:stop()
    M.subscription = nil
  end
  M.unknownRequested = {}
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
  M.pendingReason = nil
  M.pendingSafety = false
  return M
end

return M
