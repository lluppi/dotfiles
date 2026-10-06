local M = {}
local menuBarAppearance = require("menu_bar_appearance")

local aerospace = "/opt/homebrew/bin/aerospace"
local aerospaceQuery = aerospace
  .. " list-windows --all --json --format '%{window-id} %{app-name} %{app-pid} %{window-title} %{workspace} %{workspace-is-visible}'"
local triangleWidth = 16
local triangleHeight = 28
local indicatorGap = 4
local minDropdownWidth = 220
local rowHeight = 34
local sectionHeight = 25
local separatorHeight = 9
local dropdownPadding = 6
local darkForeground = { red = 0.08, green = 0.08, blue = 0.1, alpha = 1 }
local lightForeground = { red = 1, green = 1, blue = 1, alpha = 1 }
local foreground = darkForeground
local dropdownColors = {
  background = { red = 0.1, green = 0.1, blue = 0.13, alpha = 0.97 },
  border = { white = 1, alpha = 0.16 },
  text = { white = 0.95, alpha = 1 },
  section = { white = 0.72, alpha = 1 },
  separator = { white = 1, alpha = 0.13 },
  hover = { red = 0.26, green = 0.28, blue = 0.38, alpha = 0.9 },
  kill = { red = 1, green = 0.38, blue = 0.38, alpha = 1 },
}

M.running = false
M.count = 0
M.canvases = {}
M.delayedTimers = {}
M.transientTasks = {}

local function schedule(delay, callback)
  local timer
  timer = hs.timer.doAfter(delay, function()
    M.delayedTimers[timer] = nil
    if M.running then
      callback()
    end
  end)
  M.delayedTimers[timer] = true
  return timer
end

local function startTransientTask(executable, arguments, callback)
  local task
  task = hs.task.new(executable, function(...)
    M.transientTasks[task] = nil
    if M.running then
      callback(...)
    end
  end, arguments)
  M.transientTasks[task] = true
  if not task:start() then
    M.transientTasks[task] = nil
  end
end

local function allWindowItems()
  local entries = {}
  local byWindowId = {}
  local managedPids = {}
  local output, queryOK = hs.execute(aerospaceQuery)

  if queryOK then
    local decodeOK, aerospaceWindows = pcall(hs.json.decode, output)
    if decodeOK and type(aerospaceWindows) == "table" then
      for _, window in ipairs(aerospaceWindows) do
        local id = window["window-id"]
        local entry = {
          kind = "window",
          id = id,
          pid = window["app-pid"],
          appName = window["app-name"] or "Unknown application",
          title = window["window-title"] or "",
          workspace = window.workspace,
          workspaceVisible = window["workspace-is-visible"] == true,
        }
        table.insert(entries, entry)
        byWindowId[id] = entry
        managedPids[entry.pid] = true
      end
    end
  else
    hs.printf("window location query failed: %s", output)
  end

  -- A regular GUI process with no AeroSpace windows is the other kind of
  -- "minimised" item exposed by App Exposé: the app is alive, but it has no
  -- window on any workspace. Separate app instances (notably Ghostty) retain
  -- separate PIDs so each stale process can be quit independently.
  for _, application in ipairs(hs.application.runningApplications()) do
    local pid = application:pid()
    if application:kind() == 1
        and application:bundleID() ~= "com.apple.finder"
        and not managedPids[pid] then
      table.insert(entries, {
        kind = "application",
        minimized = true,
        pid = pid,
        appName = application:name() or "Unknown application",
        application = application,
      })
    end
  end

  -- Native macOS-minimised windows may no longer appear in AeroSpace's tree.
  for _, window in ipairs(hs.window.minimizedWindows()) do
    local id = window:id()
    local entry = id and byWindowId[id] or nil
    if entry then
      entry.minimized = true
      entry.window = window
    else
      local application = window:application()
      table.insert(entries, {
        kind = "window",
        minimized = true,
        id = id,
        appName = application and application:name() or "Unknown application",
        title = window:title() or "",
        window = window,
      })
    end
  end

  return entries
end

local function windowLabel(entry)
  if entry.kind == "application" then
    return string.format("%s — instance %d", entry.appName, entry.pid)
  end

  local title = entry.title
  if not title or title == "" then
    title = "Untitled window"
  end
  return entry.appName .. " — " .. title
end

local function entryWindow(entry)
  return entry.window or (entry.id and hs.window.get(entry.id)) or nil
end

local function focusNewestApplicationWindow(application)
  schedule(0.2, function()
    local window = application:mainWindow() or application:allWindows()[1]
    if window then
      window:focus()
    end
  end)
end

local function restoreWindow(entry)
  if entry.kind == "application" then
    local application = entry.application
    application:activate(true)

    -- Windowless app processes need a reopen/new-window event, not activation
    -- alone. Creating the window while the current AeroSpace workspace is
    -- visible places it there; focus it once the app has finished creating it.
    if application:selectMenuItem({ "File", "New Window" })
        or application:selectMenuItem("New Window") then
      focusNewestApplicationWindow(application)
      return
    end

    local bundleID = application:bundleID()
    if bundleID then
      startTransientTask("/usr/bin/open", { "-b", bundleID }, function()
        focusNewestApplicationWindow(application)
      end)
    end
    return
  end

  local window = entryWindow(entry)
  if window and window:isMinimized() then
    window:unminimize()
  end

  if entry.workspace then
    startTransientTask(aerospace, { "workspace", entry.workspace }, function()
      local restoredWindow = entryWindow(entry)
      if restoredWindow then
        restoredWindow:focus()
      end
    end)
  elseif window then
    window:focus()
  end
end

local function closeWindow(entry)
  local window = entryWindow(entry)
  if not window or not window:close() then
    hs.alert.show("Could not close “" .. windowLabel(entry) .. "”")
  end
end

local function compareEntries(left, right)
  if left.appName == right.appName then
    if left.title == right.title then
      return (left.pid or 0) < (right.pid or 0)
    end
    return (left.title or "") < (right.title or "")
  end
  return left.appName < right.appName
end

local function groupedRows()
  local items = allWindowItems()
  M.count = #items

  if #items == 0 then
    return {
      { kind = "section", title = "No windows or minimised applications" },
    }
  end

  local workspaceGroups = {}
  local minimizedItems = {}
  for _, item in ipairs(items) do
    if item.minimized or not item.workspace then
      table.insert(minimizedItems, item)
    else
      local group = workspaceGroups[item.workspace]
      if not group then
        group = { entries = {}, visible = false }
        workspaceGroups[item.workspace] = group
      end
      table.insert(group.entries, item)
      group.visible = group.visible or item.workspaceVisible
    end
  end

  local workspaces = {}
  for workspace in pairs(workspaceGroups) do
    table.insert(workspaces, workspace)
  end
  table.sort(workspaces, function(left, right)
    local leftNumber = tonumber(left)
    local rightNumber = tonumber(right)
    if leftNumber and rightNumber then
      return leftNumber < rightNumber
    end
    return left < right
  end)
  table.sort(minimizedItems, compareEntries)

  local rows = {}
  local hasSection = false
  local function appendSection(title, entries)
    if hasSection then
      table.insert(rows, { kind = "separator" })
    end
    hasSection = true
    table.insert(rows, { kind = "section", title = title })
    table.sort(entries, compareEntries)
    for _, entry in ipairs(entries) do
      table.insert(rows, { kind = "item", entry = entry })
    end
  end

  for _, workspace in ipairs(workspaces) do
    local group = workspaceGroups[workspace]
    local title = "Workspace " .. workspace
    if group.visible then
      title = title .. " — visible"
    end
    appendSection(title, group.entries)
  end

  if #minimizedItems > 0 then
    appendSection("Minimised / no workspace", minimizedItems)
  end

  return rows
end

local function killEntry(entry)
  if entry.kind == "application" then
    entry.application:kill9()
  else
    closeWindow(entry)
  end
end

local function hideDropdown()
  if M.menuCanvas then
    M.menuCanvas:delete()
    M.menuCanvas = nil
  end
  M.menuFrame = nil
  M.dropdownEntries = nil
  M.menuElements = nil
  M.itemFrames = nil
  M.hoveredRow = nil
end

local function pointInFrame(point, frame)
  return frame
    and point.x >= frame.x
    and point.x < frame.x + frame.w
    and point.y >= frame.y
    and point.y < frame.y + frame.h
end

local function setHoveredRow(index)
  if not M.menuCanvas or M.hoveredRow == index then
    return
  end

  if M.hoveredRow and M.menuElements[M.hoveredRow] then
    local previous = M.menuElements[M.hoveredRow]
    M.menuCanvas:elementAttribute(previous.background, "action", "skip")
    M.menuCanvas:elementAttribute(previous.killText, "action", "skip")
  end

  M.hoveredRow = index
  if index and M.menuElements[index] then
    local current = M.menuElements[index]
    M.menuCanvas:elementAttribute(current.background, "action", "fill")
    M.menuCanvas:elementAttribute(current.killText, "action", "fill")
  end
end

local showDropdown

local function dropdownWidthForRows(rows)
  local measuringCanvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = 1 })
  measuringCanvas:replaceElements({
    { type = "text", text = "", textSize = 13 },
    { type = "text", text = "", textSize = 12 },
  })

  local width = minDropdownWidth
  for _, row in ipairs(rows) do
    if row.kind == "item" then
      local textWidth = measuringCanvas:minimumTextSize(1, windowLabel(row.entry)).w
      width = math.max(width, math.ceil(textWidth) + 88)
    elseif row.kind == "section" then
      local textWidth = measuringCanvas:minimumTextSize(2, row.title).w
      width = math.max(width, math.ceil(textWidth) + 24)
    end
  end
  measuringCanvas:delete()

  local screenWidth = hs.screen.primaryScreen():fullFrame().w
  return math.min(width, screenWidth - 16)
end

local function dropdownFrame(width, height)
  local screen = hs.screen.primaryScreen()
  local screenFrame = screen:fullFrame()
  local anchor = M.canvases[1] and M.canvases[1].frame
    or { x = screenFrame.x + screenFrame.w / 2, y = screenFrame.y, h = triangleHeight }
  local x = math.max(screenFrame.x + 8,
    math.min(anchor.x, screenFrame.x + screenFrame.w - width - 8))
  local y = anchor.y + anchor.h
  return { x = x, y = y, w = width, h = height }
end

local function itemImage(entry)
  local window = entryWindow(entry)
  local application = entry.application or (window and window:application()) or nil
  local bundleID = application and application:bundleID() or nil
  local image = bundleID and hs.image.imageFromAppBundle(bundleID) or nil
  if image then
    image:setSize({ w = 18, h = 18 })
  end
  return image
end

showDropdown = function()
  -- Keep the existing dropdown visible while its replacement is built. The
  -- new canvas is shown before the old one is removed, avoiding a flash when
  -- a killed item is refreshed out of the list.
  local previousCanvas = M.menuCanvas
  local previousFrame = M.menuFrame
  M.hoveredRow = nil

  local rows = groupedRows()
  local height = dropdownPadding * 2
  for _, row in ipairs(rows) do
    if row.kind == "item" then
      height = height + rowHeight
    elseif row.kind == "section" then
      height = height + sectionHeight
    else
      height = height + separatorHeight
    end
  end

  local width = previousFrame and previousFrame.w or dropdownWidthForRows(rows)
  local frame = dropdownFrame(width, height)
  local elements = {
    {
      type = "rectangle",
      action = "strokeAndFill",
      frame = { x = 0, y = 0, w = frame.w, h = frame.h },
      fillColor = dropdownColors.background,
      strokeColor = dropdownColors.border,
      strokeWidth = 1,
      roundedRectRadii = { xRadius = 10, yRadius = 10 },
    },
  }
  local y = dropdownPadding
  local itemIndex = 0
  local entries = {}
  local itemElements = {}
  local itemFrames = {}

  for _, row in ipairs(rows) do
    if row.kind == "section" then
      table.insert(elements, {
        type = "text",
        text = row.title,
        frame = { x = 12, y = y + 5, w = frame.w - 24, h = sectionHeight - 5 },
        textColor = dropdownColors.section,
        textSize = 12,
        textLineBreak = "truncateTail",
      })
      y = y + sectionHeight
    elseif row.kind == "separator" then
      table.insert(elements, {
        type = "rectangle",
        action = "fill",
        frame = { x = 10, y = y + 4, w = frame.w - 20, h = 1 },
        fillColor = dropdownColors.separator,
      })
      y = y + separatorHeight
    else
      itemIndex = itemIndex + 1
      entries[itemIndex] = row.entry

      table.insert(elements, {
        type = "rectangle",
        action = "skip",
        frame = { x = 5, y = y + 1, w = frame.w - 10, h = rowHeight - 2 },
        fillColor = dropdownColors.hover,
        roundedRectRadii = { xRadius = 6, yRadius = 6 },
      })
      local backgroundIndex = #elements

      local image = itemImage(row.entry)
      if image then
        table.insert(elements, {
          type = "image",
          image = image,
          frame = { x = 12, y = y + 8, w = 18, h = 18 },
          imageScaling = "shrinkToFit",
        })
      end

      table.insert(elements, {
        type = "text",
        text = windowLabel(row.entry),
        frame = { x = 40, y = y + 8, w = frame.w - 86, h = rowHeight - 8 },
        textColor = dropdownColors.text,
        textSize = 13,
        textLineBreak = "truncateTail",
      })
      table.insert(elements, {
        type = "text",
        action = "skip",
        text = "×",
        frame = { x = frame.w - 40, y = y + 3, w = 32, h = rowHeight - 3 },
        textAlignment = "center",
        textColor = dropdownColors.kill,
        textSize = 20,
      })
      local killTextIndex = #elements

      table.insert(elements, {
        id = "row:" .. itemIndex,
        type = "rectangle",
        action = "fill",
        frame = { x = 5, y = y + 1, w = frame.w - 50, h = rowHeight - 2 },
        fillColor = { alpha = 0.001 },
        trackMouseByBounds = true,
        trackMouseEnterExit = true,
        trackMouseDown = true,
        trackMouseUp = true,
      })
      table.insert(elements, {
        id = "kill:" .. itemIndex,
        type = "rectangle",
        action = "fill",
        frame = { x = frame.w - 45, y = y + 1, w = 40, h = rowHeight - 2 },
        fillColor = { alpha = 0.001 },
        trackMouseByBounds = true,
        trackMouseEnterExit = true,
        trackMouseDown = true,
        trackMouseUp = true,
      })
      itemElements[itemIndex] = {
        background = backgroundIndex,
        killText = killTextIndex,
      }
      itemFrames[itemIndex] = {
        x = frame.x + 5,
        y = frame.y + y + 1,
        w = frame.w - 10,
        h = rowHeight - 2,
      }
      y = y + rowHeight
    end
  end

  local canvas = hs.canvas.new(frame)
  canvas:replaceElements(elements)
  M.menuCanvas = canvas
  M.menuFrame = frame
  M.dropdownEntries = entries
  M.menuElements = itemElements
  M.itemFrames = itemFrames

  canvas:mouseCallback(function(_, message, id)
    local kind, rawIndex = tostring(id):match("^(%a+):(%d+)$")
    local index = tonumber(rawIndex)
    if not index then
      return
    end

    if message == "mouseEnter" then
      setHoveredRow(index)
    elseif message == "mouseExit" and M.hoveredRow == index then
      setHoveredRow(nil)
    elseif message == "mouseUp" and kind == "row" then
      local entry = M.dropdownEntries[index]
      hideDropdown()
      restoreWindow(entry)
    elseif message == "mouseUp" and kind == "kill" then
      local entry = M.dropdownEntries[index]
      killEntry(entry)
      schedule(0.2, function()
        if M.menuCanvas then
          showDropdown()
        end
      end)
    end
  end)
  canvas:level(hs.canvas.windowLevels.popUpMenu)
  canvas:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
  canvas:clickActivating(false)
  canvas:show()
  if previousCanvas then
    previousCanvas:delete()
  end

  -- Deleting the replaced canvas emits a final mouseExit asynchronously. Wait
  -- for that stale event before applying hover to the row now under the
  -- stationary pointer, otherwise it immediately clears the new highlight.
  schedule(0.05, function()
    if M.menuCanvas ~= canvas then
      return
    end

    local mousePosition = hs.mouse.absolutePosition()
    for index, itemFrame in ipairs(itemFrames) do
      if pointInFrame(mousePosition, itemFrame) then
        setHoveredRow(index)
        break
      end
    end
  end)
end

local function toggleDropdown()
  if M.menuCanvas then
    hideDropdown()
  else
    showDropdown()
  end
end

local function indicatorFrame(screen)
  if workspaceIndicator and workspaceIndicator.snapshot then
    local snapshot = workspaceIndicator.snapshot()
    local workspaceFrame = snapshot.frames and snapshot.frames[1]
    if workspaceFrame then
      return {
        x = workspaceFrame.x - indicatorGap - triangleWidth,
        y = workspaceFrame.y,
        w = triangleWidth,
        h = workspaceFrame.h,
      }
    end
  end

  local screenFrame = screen:fullFrame()
  local menuBarHeight = screen:frame().y - screenFrame.y
  return {
    x = screenFrame.x + math.floor((screenFrame.w - triangleWidth) / 2),
    y = screenFrame.y + math.max(0, math.floor((menuBarHeight - triangleHeight) / 2)),
    w = triangleWidth,
    h = triangleHeight,
  }
end

local function buildCanvas(screen)
  local frame = indicatorFrame(screen)
  local canvas = hs.canvas.new(frame)
  canvas:replaceElements({
    {
      type = "segments",
      action = "fill",
      closed = true,
      coordinates = {
        { x = 4, y = 11 },
        { x = 12, y = 11 },
        { x = 8, y = 17 },
      },
      fillColor = foreground,
      antialias = true,
    },
    {
      id = "trigger",
      type = "rectangle",
      action = "fill",
      frame = { x = 0, y = 0, w = triangleWidth, h = frame.h },
      fillColor = { alpha = 0.001 },
      trackMouseByBounds = true,
      trackMouseDown = true,
      trackMouseUp = true,
    },
  })
  canvas:mouseCallback(function(_, message, id)
    if message == "mouseUp" and id == "trigger" then
      toggleDropdown()
    end
  end)
  canvas:level("status")
  canvas:behavior({
    "canJoinAllSpaces",
    "stationary",
    "ignoresCycle",
  })
  canvas:clickActivating(false)
  canvas:show()

  return {
    canvas = canvas,
    frame = frame,
  }
end

local function rebuildCanvases()
  if not M.running then
    return
  end

  hideDropdown()
  for _, entry in ipairs(M.canvases) do
    entry.canvas:delete()
  end

  M.canvases = {}
  local screen = hs.screen.primaryScreen()
  if screen then
    table.insert(M.canvases, buildCanvas(screen))
  end
end

function M.snapshot()
  local frames = {}
  for _, entry in ipairs(M.canvases) do
    table.insert(frames, entry.frame)
  end

  return {
    count = M.count,
    running = M.running,
    canvases = #M.canvases,
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
    for _, entry in ipairs(M.canvases) do
      entry.canvas:elementAttribute(1, "fillColor", foreground)
    end
  end
  menuBarAppearance.subscribe(M.appearanceListener)
  rebuildCanvases()
  M.screenWatcher = hs.screen.watcher.new(function()
    if M.rebuildTimer then
      M.rebuildTimer:stop()
      M.delayedTimers[M.rebuildTimer] = nil
    end
    M.rebuildTimer = schedule(0.1, function()
      M.rebuildTimer = nil
      rebuildCanvases()
    end)
  end):start()
  M.outsideClickTap = hs.eventtap.new({
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
  }, function(event)
    if not M.menuCanvas then
      return false
    end

    local point = event:location()
    if pointInFrame(point, M.menuFrame) then
      return false
    end
    for _, entry in ipairs(M.canvases) do
      if pointInFrame(point, entry.frame) then
        return false
      end
    end
    hideDropdown()
    return false
  end):start()
  M.escapeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if M.menuCanvas and event:getKeyCode() == hs.keycodes.map.escape then
      hideDropdown()
      return true
    end
    return false
  end):start()
  return M
end

function M.stop()
  M.running = false
  hideDropdown()

  if M.appearanceListener then
    menuBarAppearance.unsubscribe(M.appearanceListener)
    M.appearanceListener = nil
  end

  if M.outsideClickTap then
    M.outsideClickTap:stop()
    M.outsideClickTap = nil
  end
  if M.escapeTap then
    M.escapeTap:stop()
    M.escapeTap = nil
  end
  if M.screenWatcher then
    M.screenWatcher:stop()
    M.screenWatcher = nil
  end
  for timer in pairs(M.delayedTimers) do
    timer:stop()
    M.delayedTimers[timer] = nil
  end
  M.rebuildTimer = nil
  for task in pairs(M.transientTasks) do
    if task:isRunning() then
      task:terminate()
    end
    M.transientTasks[task] = nil
  end
  for _, entry in ipairs(M.canvases) do
    entry.canvas:delete()
  end
  M.canvases = {}
  return M
end

return M
