local M = {}
local menuBarAppearance = require("menu_bar_appearance")
local menuBarGeometry = require("menu_bar_geometry")
local menuBarVisibility = require("menu_bar_visibility")

local canvasHeight = 38
local edgeMargin = 8
local notchRightOffset = 2
local iconTextGap = 2
local groupGap = 6
local refreshInterval = 5
local outlookRefreshInterval = 5 * 60
local cpuSamplePeriod = 0.4
local darkForeground = { red = 0.08, green = 0.08, blue = 0.1, alpha = 1 }
local lightForeground = { red = 1, green = 1, blue = 1, alpha = 1 }
local foreground = darkForeground

local function indicatorIcons(name)
  return {
    dark = hs.image.imageFromPath(hs.configdir .. "/assets/" .. name .. ".svg"),
    light = hs.image.imageFromPath(hs.configdir .. "/assets/" .. name .. "-light.svg"),
  }
end

-- CPU and RAM reserve room for percentages. Slack reserves two badge digits;
-- Outlook is hidden until it has a badge.
local groups = {
  { id = "cpu", icons = indicatorIcons("cpu"), iconSize = 18, minText = "00%" },
  { id = "memory", icons = indicatorIcons("memory"), iconSize = 17, minText = "00%" },
  { id = "slack", icons = indicatorIcons("slack"), iconSize = 17, minText = "00", reserveText = true },
  { id = "outlook", icons = indicatorIcons("outlook"), iconSize = 17, minText = "00", hideWithoutText = true },
}

local function notchRightArea()
  return menuBarGeometry.area(1, "right")
end

local function indicatorFrame(screen)
  local screenFrame = screen:fullFrame()
  local menuBarHeight = screen:frame().y - screenFrame.y
  local safeArea = notchRightArea()
  local safeLeft

  if safeArea then
    safeLeft = safeArea.x
  else
    safeLeft = screenFrame.x + math.floor(screenFrame.w / 2)
  end

  return {
    x = math.floor(safeLeft + edgeMargin + (safeArea and notchRightOffset or 0)),
    y = screenFrame.y + math.floor((menuBarHeight - canvasHeight) / 2),
    w = 1, -- placeholder; render() sizes the canvas to fit its content
    h = canvasHeight,
  }
end

M.canvases = {}
M.cpuPercent = 0
M.memoryPercent = 0
M.slackBadge = nil
M.outlookBadge = nil
M.running = false
M.indicatorsVisible = true
M.repairTasks = {}
M.repairTimers = {}
M.badgeTasks = {}

local layoutScript = os.getenv("HOME") .. "/.local/bin/aerospace-master-layout.sh"

-- Restoring a minimized or hidden app re-enters the tiling tree without
-- firing on-window-detected, and macOS animates un-minimized windows up from
-- the Dock. Requesting repairs immediately lets the tree correction land
-- while that animation is still playing, so the window arrives already tiled
-- instead of appearing as a column and snapping afterwards.
local function scheduleLayoutRepair()
  for _, delay in ipairs({ 0.1, 0.45 }) do
    local timer
    timer = hs.timer.doAfter(delay, function()
      M.repairTimers[timer] = nil
      if not M.running then
        return
      end

      local task
      task = hs.task.new(layoutScript, function()
        M.repairTasks[task] = nil
      end, { "--repair-visible" })
      M.repairTasks[task] = true
      if not task:start() then
        M.repairTasks[task] = nil
      end
    end)
    M.repairTimers[timer] = true
  end
end

local function launchTarget(appName)
  hs.application.launchOrFocus(appName)
  scheduleLayoutRepair()
end

-- Dock badge label via lsappinfo. done(nil) = app not running,
-- done("") = running with no badge, otherwise the badge text ("3", "\u{2022}", ...).
local function fetchBadge(key, appName, done)
  local existingTask = M.badgeTasks[key]
  if existingTask and existingTask:isRunning() then
    return
  end

  local task
  task = hs.task.new("/usr/bin/lsappinfo", function(exitCode, stdout)
    if M.badgeTasks[key] == task then
      M.badgeTasks[key] = nil
    end
    if not M.running then
      return
    end
    if exitCode ~= 0 or type(stdout) ~= "string" or stdout:find("StatusLabel", 1, true) == nil then
      done(nil)
      return
    end
    done(stdout:match('"label"="([^"]*)"') or stdout:match('"label"=([%d]+)') or "")
  end, { "info", "-only", "StatusLabel", appName })
  M.badgeTasks[key] = task
  if not task:start() then
    M.badgeTasks[key] = nil
  end
end

-- Keep the app icon visible, but omit the badge text when there are no unreads.
local function badgeDisplay(label)
  if label == nil or label == "" or label == "0" then
    return nil, foreground
  end
  return label, foreground
end

local function currentValues()
  local slackText, slackColor = badgeDisplay(M.slackBadge)
  local outlookText, outlookColor = badgeDisplay(M.outlookBadge)

  return {
    cpu = { text = string.format("%d%%", M.cpuPercent), color = foreground },
    memory = { text = string.format("%d%%", M.memoryPercent), color = foreground },
    slack = { text = slackText, color = slackColor },
    outlook = { text = outlookText, color = outlookColor },
  }
end

-- Lay one canvas out left-to-right, sizing each value to its measured text
-- width so groups keep a constant visual gap regardless of text length.
local function layout(entry, values)
  local canvas = entry.canvas
  local x = 0
  local groupStarts = {}

  for i, group in ipairs(groups) do
    local value = values[group.id]
    local indexes = entry.groups[group.id]
    local visible = not group.hideWithoutText or value.text ~= nil

    if not visible then
      canvas:elementAttribute(indexes.icon, "action", "skip")
      canvas:elementAttribute(indexes.value, "action", "skip")
    else
      groupStarts[i] = x
      canvas:elementAttribute(indexes.icon, "action", "strokeAndFill")
      canvas:elementAttribute(indexes.icon, "image", group.icons[foreground == lightForeground and "light" or "dark"])
      canvas:elementAttribute(indexes.icon, "frame", {
        x = x,
        y = (canvasHeight - group.iconSize) / 2,
        w = group.iconSize,
        h = group.iconSize,
      })
      x = x + group.iconSize

      if value.text == nil then
        canvas:elementAttribute(indexes.value, "action", "skip")
        if group.reserveText then
          local minWidth = math.ceil(canvas:minimumTextSize(indexes.value, group.minText).w) + 1
          x = x + iconTextGap + minWidth
        end
      else
        canvas:elementAttribute(indexes.value, "action", "strokeAndFill")
        local valueX = x + iconTextGap
        canvas:elementAttribute(indexes.value, "text", value.text)
        canvas:elementAttribute(indexes.value, "textColor", value.color)
        local textWidth = math.ceil(canvas:minimumTextSize(indexes.value, value.text).w) + 1
        if group.minText then
          local minWidth = math.ceil(canvas:minimumTextSize(indexes.value, group.minText).w) + 1
          textWidth = math.max(textWidth, minWidth)
        end
        canvas:elementAttribute(indexes.value, "frame", {
          x = valueX,
          y = 11,
          w = textWidth,
          h = canvasHeight - 11,
        })
        x = valueX + textWidth
      end

      x = x + groupGap
    end
  end

  local totalWidth = math.max(0, x - groupGap)
  local halfGap = math.floor(groupGap / 2)
  local slackStart = groupStarts[3]
  local outlookStart = groupStarts[4]
  local regions = {
    activityMonitor = { from = 0, to = slackStart - halfGap },
    slack = { from = slackStart - halfGap, to = outlookStart and outlookStart - halfGap or totalWidth },
    outlook = outlookStart
        and { from = outlookStart - halfGap, to = totalWidth }
      or { from = totalWidth, to = totalWidth },
  }
  for id, region in pairs(regions) do
    canvas:elementAttribute(entry.regions[id], "frame", {
      x = region.from,
      y = 0,
      w = math.max(0, region.to - region.from),
      h = canvasHeight,
    })
  end

  canvas:size({ w = totalWidth, h = canvasHeight })
  entry.frame.w = totalWidth
end

local function render()
  local values = currentValues()
  for _, entry in ipairs(M.canvases) do
    layout(entry, values)
  end
end

local function buildCanvas(screen)
  local frame = indicatorFrame(screen)
  local elements = {}
  local groupIndexes = {}

  for _, group in ipairs(groups) do
    table.insert(elements, {
      type = "image",
      image = group.icons.dark,
      frame = { x = 0, y = 0, w = group.iconSize, h = group.iconSize },
      imageAlpha = 1,
      imageScaling = "shrinkToFit",
    })
    local iconIndex = #elements
    table.insert(elements, {
      type = "text",
      text = "",
      frame = { x = 0, y = 11, w = 1, h = canvasHeight - 11 },
      textAlignment = "left",
      textColor = foreground,
      textSize = 12,
      textLineBreak = "clip",
    })
    groupIndexes[group.id] = { icon = iconIndex, value = #elements }
  end

  local regionIndexes = {}
  for _, id in ipairs({ "activityMonitor", "slack", "outlook" }) do
    table.insert(elements, {
      id = id,
      type = "rectangle",
      action = "fill",
      frame = { x = 0, y = 0, w = 1, h = canvasHeight },
      fillColor = { alpha = 0.001 },
      trackMouseByBounds = true,
      trackMouseDown = true,
      trackMouseUp = true,
    })
    regionIndexes[id] = #elements
  end

  local clickTargets = {
    activityMonitor = "Activity Monitor",
    slack = "Slack",
    outlook = "Microsoft Outlook",
  }

  local indicator = hs.canvas.new(frame)
  indicator:replaceElements(elements)
  indicator:mouseCallback(function(_, message, id)
    if message == "mouseUp" and clickTargets[id] then
      launchTarget(clickTargets[id])
    end
  end)
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
    groups = groupIndexes,
    regions = regionIndexes,
    frame = frame,
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
  local screen = hs.screen.primaryScreen()
  if screen then
    table.insert(M.canvases, buildCanvas(screen))
  end
  render()
end

local function memoryUsagePercent()
  local stats = hs.host.vmStat()
  local usedPages = stats.anonymousPages + stats.pagesWiredDown + stats.pagesUsedByVMCompressor
  local usedBytes = usedPages * stats.pageSize
  return math.max(0, math.min(100, math.floor((usedBytes / stats.memSize) * 100 + 0.5)))
end

local function refreshSlackBadge()
  fetchBadge("slack", "Slack", function(label)
    if M.slackBadge ~= label then
      M.slackBadge = label
      render()
    end
  end)
end

local function refreshOutlookBadge()
  fetchBadge("outlook", "Microsoft Outlook", function(label)
    if M.outlookBadge ~= label then
      M.outlookBadge = label
      render()
    end
  end)
end

local function refresh()
  refreshSlackBadge()

  if M.cpuSample then
    return
  end

  M.memoryPercent = memoryUsagePercent()
  M.cpuSample = hs.host.cpuUsage(cpuSamplePeriod, function(stats)
    M.cpuSample = nil
    if not M.running then
      return
    end

    M.cpuPercent = math.max(0, math.min(100, math.floor(stats.overall.active + 0.5)))
    render()
  end)
end

function M.snapshot()
  local frames = {}
  for _, entry in ipairs(M.canvases) do
    table.insert(frames, entry.frame)
  end

  return {
    cpu = M.cpuPercent,
    memory = M.memoryPercent,
    slack = M.slackBadge,
    outlook = M.outlookBadge,
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
    foreground = useLightForeground and lightForeground or darkForeground
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
  rebuildCanvases()
  M.screenWatcher = hs.screen.watcher.new(function()
    menuBarGeometry.invalidate()
    rebuildCanvases()
  end):start()
  M.refreshTimer = hs.timer.doEvery(refreshInterval, refresh)
  M.outlookRefreshTimer = hs.timer.doEvery(outlookRefreshInterval, refreshOutlookBadge)
  refresh()
  refreshOutlookBadge()
  return M
end

function M.stop()
  M.running = false

  if M.appearanceListener then
    menuBarAppearance.unsubscribe(M.appearanceListener)
    M.appearanceListener = nil
  end
  if M.visibilityListener then
    menuBarVisibility.unsubscribe(M.visibilityListener)
    M.visibilityListener = nil
  end

  if M.cpuSample then
    M.cpuSample:stop()
    M.cpuSample = nil
  end
  if M.refreshTimer then
    M.refreshTimer:stop()
    M.refreshTimer = nil
  end
  if M.outlookRefreshTimer then
    M.outlookRefreshTimer:stop()
    M.outlookRefreshTimer = nil
  end
  if M.screenWatcher then
    M.screenWatcher:stop()
    M.screenWatcher = nil
  end
  for timer in pairs(M.repairTimers) do
    timer:stop()
    M.repairTimers[timer] = nil
  end
  for key, task in pairs(M.badgeTasks) do
    if task:isRunning() then
      task:terminate()
    end
    M.badgeTasks[key] = nil
  end
  for task in pairs(M.repairTasks) do
    if task:isRunning() then
      task:terminate()
    end
    M.repairTasks[task] = nil
  end
  for _, entry in ipairs(M.canvases) do
    entry.canvas:delete()
  end
  M.canvases = {}
  return M
end

return M
