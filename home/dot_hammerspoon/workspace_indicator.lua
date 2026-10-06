local M = {}
local menuBarAppearance = require("menu_bar_appearance")
local menuBarGeometry = require("menu_bar_geometry")
local menuBarVisibility = require("menu_bar_visibility")

local aerospace = "/opt/homebrew/bin/aerospace"
local topologyScript = os.getenv("HOME") .. "/.local/bin/aerospace-workspace-topology.sh"
local defaultWorkspaces = { "1", "2", "3", "4" }
local cellWidth = 22
local canvasHeight = 28
local edgeMargin = 8
local fallbackPollInterval = 30

local function hexColor(hex, alpha)
  local value = hex:gsub("#", "")
  return {
    red = tonumber(value:sub(1, 2), 16) / 255,
    green = tonumber(value:sub(3, 4), 16) / 255,
    blue = tonumber(value:sub(5, 6), 16) / 255,
    alpha = alpha or 1,
  }
end

local colors = {
  foreground = hexColor("#141419"),
  occupied = hexColor("#786FA6"),
}
local darkForeground = colors.foreground
local lightForeground = hexColor("#FFFFFF")

local queryScript = [[
focused=$(/opt/homebrew/bin/aerospace list-workspaces --focused) || exit 1
printf 'focused:%s\n' "$focused"
/opt/homebrew/bin/aerospace list-workspaces --monitor all --visible \
  --format 'visible:%{monitor-appkit-nsscreen-screens-id}:%{workspace}' || exit 1
/opt/homebrew/bin/aerospace list-windows --all --format '%{workspace}' |
  /usr/bin/sort -u |
  /usr/bin/sed 's/^/occupied:/'
]]

M.canvases = {}
M.activeWorkspace = nil
M.visibleWorkspaces = {}
M.occupiedWorkspaces = {}
M.running = false
M.refreshPending = false
M.topologyPending = false
M.topologyAttempt = 0
M.indicatorsVisible = true

local function render()
  for _, entry in ipairs(M.canvases) do
    local visibleWorkspace = M.visibleWorkspaces[entry.appKitIndex]
    for _, workspace in ipairs(entry.workspaces) do
      local isActive = workspace == visibleWorkspace
      local isOccupied = M.occupiedWorkspaces[workspace] == true
      local dotIndex = entry.dotIndexes[workspace]

      if isActive then
        entry.canvas:elementAttribute(dotIndex, "action", "strokeAndFill")
        entry.canvas:elementAttribute(dotIndex, "fillColor", colors.foreground)
        entry.canvas:elementAttribute(dotIndex, "strokeColor", colors.foreground)
        entry.canvas:elementAttribute(dotIndex, "strokeWidth", 1.25)
      elseif isOccupied then
        entry.canvas:elementAttribute(dotIndex, "action", "strokeAndFill")
        entry.canvas:elementAttribute(dotIndex, "fillColor", colors.occupied)
        entry.canvas:elementAttribute(dotIndex, "strokeColor", colors.foreground)
        entry.canvas:elementAttribute(dotIndex, "strokeWidth", 1.25)
      else
        entry.canvas:elementAttribute(dotIndex, "action", "stroke")
        entry.canvas:elementAttribute(dotIndex, "strokeColor", colors.foreground)
        entry.canvas:elementAttribute(dotIndex, "strokeWidth", 1.25)
      end
    end
  end
end

local refresh

local function scheduleRefresh()
  if not M.running then
    return
  end

  if M.refreshDebounce then
    M.refreshDebounce:stop()
  end

  M.refreshDebounce = hs.timer.doAfter(0.05, function()
    M.refreshDebounce = nil
    refresh()
  end)
end

local function switchWorkspace(workspace)
  if M.switchTask and M.switchTask:isRunning() then
    M.switchTask:terminate()
  end

  local task
  task = hs.task.new(aerospace, function()
    if M.switchTask ~= task then
      return
    end
    M.switchTask = nil
    scheduleRefresh()
  end, { "workspace", workspace })
  M.switchTask = task

  if not task:start() and M.switchTask == task then
    M.switchTask = nil
  end
end

local function notchLeftArea(appKitIndex)
  return menuBarGeometry.area(appKitIndex, "left")
end

local function pickerFrame(screen, appKitIndex, canvasWidth)
  local screenFrame = screen:fullFrame()
  local menuBarHeight = screen:frame().y - screenFrame.y
  local safeArea = notchLeftArea(appKitIndex)
  local safeRight

  if safeArea then
    safeRight = safeArea.x + safeArea.w
  else
    safeRight = screenFrame.x + math.floor(screenFrame.w / 2)
  end

  return {
    x = math.floor(safeRight - edgeMargin - canvasWidth),
    y = screenFrame.y + math.max(0, math.floor((menuBarHeight - canvasHeight) / 2)),
    w = canvasWidth,
    h = canvasHeight,
  }
end

local function workspaceLayout()
  local command = aerospace
    .. " list-monitors --format '%{monitor-appkit-nsscreen-screens-id}|%{monitor-id}|%{monitor-is-main}'"
  local output, ok = hs.execute(command)
  if not ok then
    hs.printf("workspace indicator layout query failed")
    return {}
  end

  local layout = {}
  for line in output:gmatch("[^\r\n]+") do
    local appKitIndex, monitorId, isMain = line:match("^(%d+)|(%d+)|(%a+)$")
    appKitIndex = tonumber(appKitIndex)
    if appKitIndex then
      local firstWorkspace = isMain == "true" and 1 or 5
      local workspaces = {}
      for offset = 0, 3 do
        table.insert(workspaces, tostring(firstWorkspace + offset))
      end
      layout[appKitIndex] = {
        monitorId = tonumber(monitorId),
        workspaces = workspaces,
      }
    end
  end
  return layout
end

local function buildCanvas(screen, appKitIndex, layout)
  local workspaces = layout and layout.workspaces or defaultWorkspaces
  local canvasWidth = cellWidth * #workspaces
  local frame = pickerFrame(screen, appKitIndex, canvasWidth)
  local elements = {}
  local dotIndexes = {}

  for index, workspace in ipairs(workspaces) do
    local cellX = (index - 1) * cellWidth

    table.insert(elements, {
      type = "circle",
      action = "stroke",
      center = { x = cellX + cellWidth / 2, y = canvasHeight / 2 },
      radius = 4,
      strokeColor = colors.foreground,
      strokeWidth = 1.25,
      antialias = true,
    })
    dotIndexes[workspace] = #elements
  end

  local indicator = hs.canvas.new(frame)
  indicator:replaceElements(elements)
  indicator:level("status")
  indicator:behavior({
    "canJoinAllSpaces",
    "stationary",
    "ignoresCycle",
  })
  indicator:clickActivating(false)
  if M.indicatorsVisible then
    indicator:show()
  end

  return {
    canvas = indicator,
    dotIndexes = dotIndexes,
    frame = frame,
    appKitIndex = appKitIndex,
    monitorId = layout and layout.monitorId or nil,
    workspaces = workspaces,
  }
end

local function rebuildCanvases()
  if not M.running then
    return
  end

  for _, entry in ipairs(M.canvases) do
    entry.canvas:delete()
  end

  M.canvases = {}
  local layout = workspaceLayout()
  for appKitIndex, screen in ipairs(hs.screen.allScreens()) do
    table.insert(M.canvases, buildCanvas(screen, appKitIndex, layout[appKitIndex]))
  end
  render()
end

local topologySettleDelay = 0.5
local topologyRetryDelay = 1
local topologyMaxAttempts = 6
local topologyDriftPollInterval = 15

-- The monitor count is authoritative and comes from macOS. AeroSpace's own
-- monitor list can lag a display change, which made workspaces 5-8 look legal
-- on a single monitor and left stray windows in place. Passing the live screen
-- count means a reconcile pass never has to trust AeroSpace's bookkeeping.
local function topologyArgs(extra)
  local args = { "--monitors", tostring(#hs.screen.allScreens()) }
  if extra then
    args[#args + 1] = extra
  end
  return args
end

local reconcileTopology

local function scheduleReconcileTopology(delay)
  if not M.running then
    return
  end
  if M.topologyTimer then
    M.topologyTimer:stop()
  end
  -- Screen notifications arrive in bursts. Cancelling the pending timer makes
  -- the last notification win, and the delay lets AeroSpace observe the
  -- display change before the monitor count is read.
  M.topologyTimer = hs.timer.doAfter(delay or topologySettleDelay, function()
    M.topologyTimer = nil
    reconcileTopology()
  end)
end

local function finishTopologyPass()
  if M.running then
    rebuildCanvases()
    scheduleRefresh()
  end
end

local function retryTopology(message)
  if M.topologyAttempt >= topologyMaxAttempts then
    M.topologyAttempt = 0
    hs.printf("%s still failing after %d attempts", message, topologyMaxAttempts)
    return
  end
  M.topologyAttempt = M.topologyAttempt + 1
  scheduleReconcileTopology(topologyRetryDelay)
end

-- Read-only verification of the live topology. After a trigger it re-runs the
-- pass while drift remains, so a burst that produced no action converges fast.
-- The periodic poll uses the same check but keeps a single attempt of its own,
-- so a stubborn topology cannot spam the retry ladder every 15 seconds.
local function verifyTopology(fromPoll)
  if not M.running then
    return
  end
  if M.driftTask and M.driftTask:isRunning() then
    if not fromPoll then
      M.topologyPending = true
    end
    return
  end

  local task
  task = hs.task.new(topologyScript, function(exitCode, _, stderr)
    if M.driftTask ~= task then
      return
    end
    M.driftTask = nil
    if not M.running then
      return
    end

    if exitCode == 0 then
      M.topologyAttempt = 0
    elseif exitCode == 1 then
      if fromPoll then
        M.topologyAttempt = 0
        hs.printf("workspace topology drift detected; reconciling")
        scheduleReconcileTopology(0)
      else
        retryTopology("workspace topology reconciliation")
      end
    else
      M.topologyAttempt = 0
      hs.printf("workspace topology check failed: %s", stderr)
    end

    if M.topologyPending then
      M.topologyPending = false
      scheduleReconcileTopology(0)
    end
  end, topologyArgs("--check"))
  M.driftTask = task

  if not task:start() and M.driftTask == task then
    M.driftTask = nil
  end
end

reconcileTopology = function()
  if not M.running then
    return
  end
  if M.topologyTimer then
    M.topologyTimer:stop()
    M.topologyTimer = nil
  end
  -- Never drop a trigger while a pass is in flight; queue the next pass
  -- instead of returning, so a burst of screen notifications cannot swallow
  -- the only trigger that arrives.
  if M.topologyTask and M.topologyTask:isRunning() then
    M.topologyPending = true
    return
  end

  local task
  task = hs.task.new(topologyScript, function(exitCode, _, stderr)
    if M.topologyTask ~= task then
      return
    end
    M.topologyTask = nil
    if not M.running then
      return
    end

    if exitCode == 0 then
      verifyTopology()
    else
      hs.printf("workspace topology reconciliation failed: %s", stderr)
      retryTopology("workspace topology reconciliation")
    end

    finishTopologyPass()

    if M.topologyPending then
      M.topologyPending = false
      scheduleReconcileTopology(0)
    end
  end, topologyArgs())
  M.topologyTask = task

  if not task:start() and M.topologyTask == task then
    M.topologyTask = nil
    retryTopology("workspace topology reconciliation")
    finishTopologyPass()
  end
end

local function workspaceAtPoint(point)
  if not M.indicatorsVisible then
    return nil
  end

  for _, entry in ipairs(M.canvases) do
    local frame = entry.frame
    local inside = point.x >= frame.x
      and point.x < frame.x + frame.w
      and point.y >= frame.y
      and point.y < frame.y + frame.h

    if inside then
      local index = math.floor((point.x - frame.x) / cellWidth) + 1
      return entry.workspaces[index]
    end
  end
  return nil
end

local function handlePickerMouseEvent(event)
  local eventType = event:getType()
  local workspace = workspaceAtPoint(event:location())

  if eventType == hs.eventtap.event.types.leftMouseDown then
    if workspace then
      M.pressedWorkspace = workspace
      return true
    end
  elseif M.pressedWorkspace then
    if eventType == hs.eventtap.event.types.leftMouseUp then
      local pressedWorkspace = M.pressedWorkspace
      M.pressedWorkspace = nil
      if workspace == pressedWorkspace then
        switchWorkspace(pressedWorkspace)
      end
    end
    return true
  end

  return false
end

local function parseWorkspaceState(output)
  local activeWorkspace = nil
  local visibleWorkspaces = {}
  local occupiedWorkspaces = {}

  for line in output:gmatch("[^\r\n]+") do
    local appKitIndex, visibleWorkspace = line:match("^visible:(%d+):(.*)$")
    local kind, workspace = line:match("^(%a+):(.*)$")
    if appKitIndex then
      visibleWorkspaces[tonumber(appKitIndex)] = visibleWorkspace
    elseif kind == "focused" then
      activeWorkspace = workspace
    elseif kind == "occupied" then
      occupiedWorkspaces[workspace] = true
    end
  end

  return activeWorkspace, visibleWorkspaces, occupiedWorkspaces
end

refresh = function()
  if not M.running then
    return
  end

  if M.refreshTask and M.refreshTask:isRunning() then
    M.refreshPending = true
    return
  end

  local task
  task = hs.task.new("/bin/sh", function(exitCode, stdout, stderr)
    if M.refreshTask ~= task then
      return
    end
    M.refreshTask = nil
    if not M.running then
      return
    end

    if exitCode == 0 then
      M.activeWorkspace, M.visibleWorkspaces, M.occupiedWorkspaces = parseWorkspaceState(stdout)
      render()
    else
      hs.printf("workspace indicator refresh failed: %s", stderr)
    end

    if M.running and M.refreshPending then
      M.refreshPending = false
      scheduleRefresh()
    end
  end, { "-c", queryScript })
  M.refreshTask = task

  if not task:start() and M.refreshTask == task then
    M.refreshTask = nil
  end
end

local function startSubscription()
  if not M.running then
    return
  end
  if M.subscriptionTask and M.subscriptionTask:isRunning() then
    return
  end

  local task
  task = hs.task.new(aerospace, function()
    if M.subscriptionTask ~= task then
      return
    end
    M.subscriptionTask = nil
    if M.running then
      M.subscriptionRestartTimer = hs.timer.doAfter(1, startSubscription)
    end
  end, function(_, stdout)
    if M.running and M.subscriptionTask == task and stdout and stdout ~= "" then
      scheduleRefresh()
    end
    return true
  end, { "subscribe", "--all", "--no-send-initial" })
  M.subscriptionTask = task

  if not task:start() and M.subscriptionTask == task then
    M.subscriptionTask = nil
    M.subscriptionRestartTimer = hs.timer.doAfter(1, startSubscription)
  end
end

function M.snapshot()
  local occupied = {}
  local states = {}
  local frames = {}
  local visible = {}
  local seen = {}

  for _, entry in ipairs(M.canvases) do
    local visibleWorkspace = M.visibleWorkspaces[entry.appKitIndex]
    visible[entry.appKitIndex] = visibleWorkspace
    for _, workspace in ipairs(entry.workspaces) do
      if not seen[workspace] then
        seen[workspace] = true
        if M.occupiedWorkspaces[workspace] then
          table.insert(occupied, workspace)
        end

        if workspace == visibleWorkspace then
          states[workspace] = "active"
        elseif M.occupiedWorkspaces[workspace] then
          states[workspace] = "occupied"
        else
          states[workspace] = "empty"
        end
      end
    end
    table.insert(frames, entry.frame)
  end

  return {
    active = M.activeWorkspace,
    visible = visible,
    occupied = occupied,
    states = states,
    canvases = #M.canvases,
    indicatorsVisible = M.indicatorsVisible,
    frames = frames,
  }
end

function M.start()
  if M.running then
    return M
  end

  M.running = true
  M.appearanceListener = function(useLightForeground)
    colors.foreground = useLightForeground and lightForeground or darkForeground
    render()
  end
  menuBarAppearance.subscribe(M.appearanceListener)
  M.visibilityListener = function(isVisible)
    M.indicatorsVisible = isVisible
    for _, entry in ipairs(M.canvases) do
      if isVisible then
        entry.canvas:show()
      else
        entry.canvas:hide()
      end
    end
  end
  menuBarVisibility.subscribe(M.visibilityListener)
  -- Build frames immediately so the adjacent dropdown indicator never falls
  -- back to the menu-bar centre while topology reconciliation is still running.
  rebuildCanvases()
  reconcileTopology()
  M.screenWatcher = hs.screen.watcher.new(function()
    menuBarGeometry.invalidate()
    rebuildCanvases()
    scheduleReconcileTopology()
  end):start()
  -- Safety net that does not depend on any watcher firing. If a display change
  -- never reaches hs.screen.watcher, drift would otherwise persist until the
  -- next unrelated trigger. The check is read-only and cheap.
  M.driftPollTimer = hs.timer.doEvery(topologyDriftPollInterval, function()
    verifyTopology(true)
  end)
  M.clickTap = hs.eventtap.new({
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.leftMouseUp,
    hs.eventtap.event.types.leftMouseDragged,
  }, handlePickerMouseEvent):start()
  -- AeroSpace events drive normal updates. This is only a recovery path for a
  -- missed event or a restarted subscription.
  M.pollTimer = hs.timer.doEvery(fallbackPollInterval, refresh)
  refresh()
  startSubscription()
  return M
end

function M.stop()
  M.running = false
  M.refreshPending = false

  if M.appearanceListener then
    menuBarAppearance.unsubscribe(M.appearanceListener)
    M.appearanceListener = nil
  end
  if M.visibilityListener then
    menuBarVisibility.unsubscribe(M.visibilityListener)
    M.visibilityListener = nil
  end
  M.pressedWorkspace = nil

  for _, timer in ipairs({
    M.pollTimer,
    M.refreshDebounce,
    M.subscriptionRestartTimer,
    M.topologyTimer,
    M.driftPollTimer,
  }) do
    if timer then
      timer:stop()
    end
  end
  M.pollTimer = nil
  M.refreshDebounce = nil
  M.subscriptionRestartTimer = nil
  M.topologyTimer = nil
  M.driftPollTimer = nil

  if M.screenWatcher then
    M.screenWatcher:stop()
    M.screenWatcher = nil
  end
  if M.clickTap then
    M.clickTap:stop()
    M.clickTap = nil
  end

  for _, task in ipairs({ M.switchTask, M.refreshTask, M.subscriptionTask, M.topologyTask, M.driftTask }) do
    if task and task:isRunning() then
      task:terminate()
    end
  end
  M.switchTask = nil
  M.refreshTask = nil
  M.subscriptionTask = nil
  M.topologyTask = nil
  M.driftTask = nil
  M.topologyPending = false
  M.topologyAttempt = 0

  for _, entry in ipairs(M.canvases) do
    entry.canvas:delete()
  end
  M.canvases = {}
  return M
end

return M
