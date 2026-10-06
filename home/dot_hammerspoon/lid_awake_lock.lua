local M = {}

local markerPath = os.getenv("HOME") .. "/.local/state/hammerspoon-lid-awake-lock"
local pmset = "/usr/bin/pmset"
local sudo = "/usr/bin/sudo"

M.running = false

local function markerExists()
  return hs.fs.attributes(markerPath) ~= nil
end

local function writeMarker()
  local marker = io.open(markerPath, "w")
  if not marker then
    return false
  end

  marker:write(os.time(), "\n")
  marker:close()
  return true
end

local function notifyFailure(message)
  hs.notify.new({
    title = "Lid-awake lock",
    informativeText = message,
  }):send()
end

local function setSleepDisabled(disabled, callback)
  local value = disabled and "1" or "0"
  M.pmsetTask = hs.task.new(sudo, function(exitCode, _, stderr)
    M.pmsetTask = nil
    callback(exitCode == 0, stderr)
  end, { "-n", pmset, "-a", "disablesleep", value })

  if not M.pmsetTask:start() then
    M.pmsetTask = nil
    callback(false, "Could not start pmset")
  end
end

local function restoreSleep()
  if not markerExists() or M.pmsetTask then
    return
  end

  setSleepDisabled(false, function(succeeded, stderr)
    if succeeded then
      os.remove(markerPath)
      return
    end

    notifyFailure("Could not re-enable sleep. Run: sudo pmset -a disablesleep 0\n" .. (stderr or ""))
  end)
end

function M.lock()
  if M.pmsetTask then
    hs.alert.show("Lid-awake lock is already changing sleep settings")
    return
  end

  if markerExists() then
    hs.caffeinate.lockScreen()
    return
  end

  setSleepDisabled(true, function(succeeded, stderr)
    if not succeeded then
      notifyFailure("Could not disable sleep. Check the sudoers rule.\n" .. (stderr or ""))
      return
    end

    if not writeMarker() then
      setSleepDisabled(false, function()
        notifyFailure("Could not save recovery state; sleep was left enabled")
      end)
      return
    end

    hs.caffeinate.lockScreen()
  end)
end

function M.start()
  if M.running then
    return M
  end

  M.running = true
  M.watcher = hs.caffeinate.watcher.new(function(event)
    if M.running and event == hs.caffeinate.watcher.screensDidUnlock then
      restoreSleep()
    end
  end)
  M.watcher:start()

  -- Recover if Hammerspoon was restarted after disabling sleep but before the
  -- unlock event. A locked session exposes CGSSessionScreenIsLocked=true.
  M.recoveryTimer = hs.timer.doAfter(1, function()
    M.recoveryTimer = nil
    if not M.running then
      return
    end
    local session = hs.caffeinate.sessionProperties() or {}
    if markerExists() and session.CGSSessionScreenIsLocked ~= true then
      restoreSleep()
    end
  end)

  return M
end

function M.stop()
  M.running = false
  if M.watcher then
    M.watcher:stop()
    M.watcher = nil
  end
  if M.recoveryTimer then
    M.recoveryTimer:stop()
    M.recoveryTimer = nil
  end
  -- An in-flight pmset transition must finish so its marker/rollback callback
  -- cannot leave system sleep disabled without recovery state.
  return M
end

return M
