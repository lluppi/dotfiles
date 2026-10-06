local M = {}

local blockedBundleIDs = {
  ["com.microsoft.autoupdate2"] = true,
  ["com.microsoft.autoupdate.fba"] = true,
}

local logger = hs.logger.new("mauGuard", "info")

local function isBlocked(application)
  return application and blockedBundleIDs[application:bundleID()] == true
end

local function suppressApplication(application)
  if not isBlocked(application) then
    return
  end

  application:hide()
  for _, window in ipairs(application:allWindows()) do
    window:close()
  end

  logger.i("Terminating " .. (application:bundleID() or application:name()))
  application:kill9()
end

local function suppressWindow(window)
  local application = window and window:application()
  if not isBlocked(application) then
    return
  end

  application:hide()
  window:close()
  logger.i("Terminating AutoUpdate after window creation")
  application:kill9()
end

function M.start()
  if M.running then
    return M
  end

  M.applicationWatcher = hs.application.watcher.new(function(_, eventType, application)
    if eventType == hs.application.watcher.launching
        or eventType == hs.application.watcher.launched
        or eventType == hs.application.watcher.activated then
      suppressApplication(application)
    end
  end)

  M.windowFilter = hs.window.filter.new({
    "Microsoft AutoUpdate",
    "Microsoft Update Assistant",
  })
  M.windowFilter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowFocused,
    hs.window.filter.windowUnhidden,
  }, suppressWindow)

  M.applicationWatcher:start()
  M.running = true

  for bundleID in pairs(blockedBundleIDs) do
    suppressApplication(hs.application.get(bundleID))
  end

  return M
end

function M.stop()
  M.running = false
  if M.applicationWatcher then
    M.applicationWatcher:stop()
    M.applicationWatcher = nil
  end
  if M.windowFilter then
    M.windowFilter:delete()
    M.windowFilter = nil
  end
  return M
end

return M
