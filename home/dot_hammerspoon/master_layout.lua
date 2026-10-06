local M = {}

local aerospace = "/opt/homebrew/bin/aerospace"
local layoutScript = os.getenv("HOME") .. "/.local/bin/aerospace-master-layout.sh"
local retileDelay = 0.15
local windowHomeLimit = 256

M.running = false
M.retilePending = false
M.retryCount = 0
M.placementQueue = {}
M.windowHomes = {}
M.windowHomeSeenAt = {}

local function pruneWindowHomes()
  local homes = {}
  for windowId in pairs(M.windowHomes) do
    table.insert(homes, {
      id = windowId,
      seenAt = M.windowHomeSeenAt[windowId] or 0,
    })
  end
  if #homes <= windowHomeLimit then
    return
  end

  table.sort(homes, function(left, right)
    return left.seenAt < right.seenAt
  end)
  for index = 1, #homes - windowHomeLimit do
    local windowId = homes[index].id
    M.windowHomes[windowId] = nil
    M.windowHomeSeenAt[windowId] = nil
  end
end

local function scheduleRetile()
  if not M.running then
    return
  end

  if M.retileTimer then
    M.retileTimer:stop()
  end

  M.retileTimer = hs.timer.doAfter(retileDelay, function()
    M.retileTimer = nil
    M.retile()
  end)
end

function M.retile()
  if not M.running then
    return
  end

  if M.retileTask and M.retileTask:isRunning() then
    M.retilePending = true
    return
  end

  M.retileTask = hs.task.new(layoutScript, function(exitCode, _, stderr)
    M.retileTask = nil
    if not M.running then
      return
    end

    if exitCode == 0 then
      M.retryCount = 0
    elseif M.retryCount < 3 then
      M.retryCount = M.retryCount + 1
      M.retilePending = true
      hs.printf("master layout retry %d: %s", M.retryCount, stderr)
    else
      M.retryCount = 0
      hs.printf("master layout failed: %s", stderr)
    end

    if M.retilePending then
      M.retilePending = false
      scheduleRetile()
    end
  end, { "--all" })

  if not M.retileTask:start() then
    M.retileTask = nil
  end
end

-- AeroSpace's synchronous config callbacks fix window positions before the
-- first tiled render. This async pass settles master width and repairs the
-- rare shapes the sync fast paths cannot express.
local function runNextPlacement()
  if not M.running then
    return
  end

  if M.placementTask and M.placementTask:isRunning() then
    return
  end

  local job = table.remove(M.placementQueue, 1)
  if not job then
    return
  end

  M.placementTask = hs.task.new(layoutScript, function(exitCode, _, stderr)
    M.placementTask = nil
    if not M.running then
      return
    end
    if exitCode ~= 0 then
      hs.printf("master layout placement failed: %s", stderr)
    end
    runNextPlacement()
  end, job)

  if not M.placementTask:start() then
    M.placementTask = nil
  end
end

local function queuePlacement(windowId)
  table.insert(M.placementQueue, { "--window-id", tostring(windowId) })
  runNextPlacement()
end

local function queueRestore(windowId)
  local job = { "--restore-window", tostring(windowId) }
  local home = M.windowHomes[windowId]
  if home then
    table.insert(job, tostring(home))
  end
  table.insert(M.placementQueue, job)
  runNextPlacement()
end

-- Universal safety net. Windows can re-enter the tiling tree through paths
-- that never fire on-window-detected (app unhide, un-minimize, launchers
-- focusing hidden apps). Any such change alters the tree fingerprint; the
-- repair script then fixes only workspaces whose shape is actually wrong.
local function runRepair()
  if not M.running then
    return
  end

  if M.repairTask and M.repairTask:isRunning() then
    M.repairPending = true
    return
  end

  M.repairTask = hs.task.new(layoutScript, function(exitCode, _, stderr)
    M.repairTask = nil
    if not M.running then
      return
    end
    if exitCode ~= 0 then
      hs.printf("master layout repair failed: %s", stderr)
    end
    if M.repairPending then
      M.repairPending = false
      runRepair()
    end
  end, { "--repair-visible" })

  if not M.repairTask:start() then
    M.repairTask = nil
  end
end

local function checkTreeFingerprint()
  if not M.running then
    return
  end

  if M.fingerprintTask and M.fingerprintTask:isRunning() then
    M.fingerprintPending = true
    return
  end

  M.fingerprintTask = hs.task.new("/bin/sh", function(exitCode, stdout)
    M.fingerprintTask = nil
    if not M.running then
      return
    end
    if exitCode == 0 then
      if M.treeFingerprint ~= nil and M.treeFingerprint ~= stdout then
        runRepair()
      end
      M.treeFingerprint = stdout
      -- Keep temporarily absent/minimized windows so a restore can return to
      -- its real workspace instead of teleporting through the current one.
      -- Bound only the oldest history rather than pruning from one snapshot.
      local seenAt = hs.timer.secondsSinceEpoch()
      for line in stdout:gmatch("[^\r\n]+") do
        local id, workspace = line:match("^(%d+)|([^|]+)|")
        -- Only configured workspaces may become restore homes. AeroSpace can
        -- briefly resurrect stale names while macOS restores displays/windows;
        -- remembering one here made every later un-minimize feed it again.
        if id and workspace and workspace:match("^[1-8]$") then
          local windowId = tonumber(id)
          M.windowHomes[windowId] = workspace
          M.windowHomeSeenAt[windowId] = seenAt
        end
      end
      pruneWindowHomes()
    end
    if M.fingerprintPending then
      M.fingerprintPending = false
      checkTreeFingerprint()
    end
  end, {
    "-c",
    aerospace .. " list-windows --all --format '%{window-id}|%{workspace}|%{window-layout}' | /usr/bin/sort",
  })

  if not M.fingerprintTask:start() then
    M.fingerprintTask = nil
  end
end

local function scheduleFingerprintCheck()
  if M.fingerprintTimer then
    M.fingerprintTimer:stop()
  end
  M.fingerprintTimer = hs.timer.doAfter(0.25, function()
    M.fingerprintTimer = nil
    checkTreeFingerprint()
  end)
end

local function startSubscription()
  if not M.running then
    return
  end
  if M.subscriptionTask and M.subscriptionTask:isRunning() then
    return
  end

  M.subscriptionTask = hs.task.new(aerospace, function()
    M.subscriptionTask = nil
    if M.running then
      M.subscriptionRestartTimer = hs.timer.doAfter(1, startSubscription)
    end
  end, function(_, stdout)
    if stdout then
      for line in stdout:gmatch("[^\r\n]+") do
        local ok, event = pcall(hs.json.decode, line)
        if ok and type(event) == "table" then
          if event._event == "window-detected" and event.windowId then
            queuePlacement(event.windowId)
          elseif event._event == "focus-changed" then
            scheduleFingerprintCheck()
          end
        end
      end
    end
    return true
  end, { "subscribe", "window-detected", "focus-changed", "--no-send-initial" })

  if not M.subscriptionTask:start() then
    M.subscriptionTask = nil
    M.subscriptionRestartTimer = hs.timer.doAfter(1, startSubscription)
  end
end

function M.snapshot()
  return {
    running = M.running,
    retileRunning = M.retileTask and M.retileTask:isRunning() or false,
    retilePending = M.retilePending,
    retryCount = M.retryCount,
    subscriptionRunning = M.subscriptionTask and M.subscriptionTask:isRunning() or false,
    placementRunning = M.placementTask and M.placementTask:isRunning() or false,
    queuedPlacements = #M.placementQueue,
    repairRunning = M.repairTask and M.repairTask:isRunning() or false,
    hasFingerprint = M.treeFingerprint ~= nil,
  }
end

function M.start()
  if M.running then
    return M
  end

  M.running = true
  -- Window positions are fixed synchronously by AeroSpace's config callbacks.
  -- Hammerspoon settles widths per new window and rebuilds everything only
  -- after a real display-topology change.
  M.screenWatcher = hs.screen.watcher.new(scheduleRetile):start()
  -- Un-minimized and un-hidden windows re-enter the tiling tree only after
  -- the macOS restore animation, long after any launcher-side timer. These
  -- events fire at exactly the right moment to re-place the window.
  M.restoreFilter = hs.window.filter.new():setDefaultFilter({})
  M.restoreFilter:subscribe({
    hs.window.filter.windowUnminimized,
    hs.window.filter.windowUnhidden,
  }, function(window)
    local id = window and window:id()
    if id then
      queueRestore(id)
    end
  end)
  startSubscription()
  checkTreeFingerprint()
  return M
end

function M.stop()
  M.running = false
  for _, timer in ipairs({ M.retileTimer, M.subscriptionRestartTimer, M.fingerprintTimer }) do
    if timer then
      timer:stop()
    end
  end
  M.retileTimer = nil
  M.subscriptionRestartTimer = nil
  M.fingerprintTimer = nil
  if M.screenWatcher then
    M.screenWatcher:stop()
    M.screenWatcher = nil
  end
  if M.restoreFilter then
    M.restoreFilter:delete()
    M.restoreFilter = nil
  end
  for _, task in ipairs({ M.retileTask, M.subscriptionTask, M.placementTask, M.fingerprintTask, M.repairTask }) do
    if task and task:isRunning() then
      task:terminate()
    end
  end
  M.retileTask = nil
  M.subscriptionTask = nil
  M.placementTask = nil
  M.fingerprintTask = nil
  M.repairTask = nil
  M.placementQueue = {}
  M.retilePending = false
  M.fingerprintPending = false
  return M
end

return M
