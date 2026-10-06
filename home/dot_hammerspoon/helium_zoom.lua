local M = {}

local heliumBundleID = "net.imput.helium"
local eventTypes = hs.eventtap.event.types
local eventProperties = hs.eventtap.event.properties
local continuousScrollThreshold = 8

local continuousScrollTotal = 0
local lastScrollAt = 0
local heliumIsFrontmost = false

local function resetScrollState()
  continuousScrollTotal = 0
  lastScrollAt = 0
end

local function updateFrontmostApplication(application)
  heliumIsFrontmost = application ~= nil
    and application:bundleID() == heliumBundleID
  resetScrollState()
end

local function verticalDelta(event, isContinuous)
  local properties = isContinuous and {
    eventProperties.scrollWheelEventPointDeltaAxis1,
    eventProperties.scrollWheelEventFixedPtDeltaAxis1,
    eventProperties.scrollWheelEventDeltaAxis1,
  } or {
    eventProperties.scrollWheelEventDeltaAxis1,
    eventProperties.scrollWheelEventPointDeltaAxis1,
    eventProperties.scrollWheelEventFixedPtDeltaAxis1,
  }

  for _, property in ipairs(properties) do
    local delta = event:getProperty(property) or 0
    if delta ~= 0 then
      return delta
    end
  end

  return 0
end

local function zoom(direction)
  local key = direction > 0 and "=" or "-"
  hs.eventtap.keyStroke({ "cmd" }, key, 0)
end

local function handleScroll(event)
  local flags = event:getFlags()

  if not heliumIsFrontmost or not flags.ctrl then
    resetScrollState()
    return false
  end

  local isContinuous =
    (event:getProperty(eventProperties.scrollWheelEventIsContinuous) or 0) ~= 0
  local delta = verticalDelta(event, isContinuous)

  -- Consume every Ctrl-wheel event in Helium, including zero-delta phase events,
  -- so none leak through as ordinary page scrolling.
  if delta == 0 then
    return true
  end

  if not isContinuous then
    zoom(delta)
    return true
  end

  local now = hs.timer.secondsSinceEpoch()
  if now - lastScrollAt > 0.4 then
    continuousScrollTotal = 0
  end
  lastScrollAt = now
  continuousScrollTotal = continuousScrollTotal + delta

  if math.abs(continuousScrollTotal) >= continuousScrollThreshold then
    zoom(continuousScrollTotal)
    continuousScrollTotal = 0
  end

  return true
end

function M.start()
  if M.running then
    return M
  end

  M.running = true
  updateFrontmostApplication(hs.application.frontmostApplication())
  M.applicationWatcher = hs.application.watcher.new(function(_, eventType, application)
    if eventType == hs.application.watcher.activated then
      updateFrontmostApplication(application)
    end
  end):start()
  M.tap = hs.eventtap.new({ eventTypes.scrollWheel }, handleScroll):start()
  return M
end

function M.stop()
  M.running = false
  if M.applicationWatcher then
    M.applicationWatcher:stop()
    M.applicationWatcher = nil
  end
  if M.tap then
    M.tap:stop()
    M.tap = nil
  end
  heliumIsFrontmost = false
  resetScrollState()
  return M
end

return M
