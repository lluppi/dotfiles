local M = {}

local listeners = {}
local visible = nil

local function menuBarIsVisible()
  local window = hs.window.focusedWindow()
  if window and window:isFullScreen() then
    return false
  end

  local screen = (window and window:screen()) or hs.screen.mainScreen()
  if not screen then
    return false
  end

  return screen:frame().y > screen:fullFrame().y
end

local function refresh()
  local detected = menuBarIsVisible()
  if detected == visible then
    return
  end

  visible = detected
  for listener in pairs(listeners) do
    local ok, err = pcall(listener, visible)
    if not ok then
      hs.printf("menu bar visibility listener failed: %s", err)
    end
  end
end

function M.subscribe(listener)
  listeners[listener] = true

  if visible == nil then
    refresh()
  else
    listener(visible)
  end

  if not M.windowFilter then
    M.windowFilter = hs.window.filter.new():setDefaultFilter({})
    M.windowFilter:subscribe({
      hs.window.filter.windowFocused,
      hs.window.filter.windowUnfocused,
      hs.window.filter.windowMoved,
      hs.window.filter.windowFullscreened,
      hs.window.filter.windowUnfullscreened,
    }, refresh)
    M.screenWatcher = hs.screen.watcher.new(refresh):start()
  end
end

function M.unsubscribe(listener)
  listeners[listener] = nil

  if next(listeners) == nil then
    if M.windowFilter then
      M.windowFilter:delete()
      M.windowFilter = nil
    end
    if M.screenWatcher then
      M.screenWatcher:stop()
      M.screenWatcher = nil
    end
    visible = nil
  end
end

return M
