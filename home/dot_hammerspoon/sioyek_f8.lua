-- sioyek ships `toggle_dark_mode <f8>` in keys.config, but its macOS menu bar
-- puts F8 on Help > Donate (the menu item reports AXMenuItemCmdVirtualKey 100).
-- AppKit matches menu key equivalents before Qt sees the key, so F8 always opens
-- the donation page and never reaches sioyek's keybinding system. Rebinding
-- `donate` in keys_user.config does not move it: the shortcut is set in sioyek's
-- code, not read from a config file.
--
-- So swallow F8 while sioyek is frontmost and drive View > Toggle custom color
-- mode through the accessibility API instead. That menu item IS the command, so
-- this does not depend on a keybinding surviving the menu bar.
local SIOYEK_BUNDLE_ID = "info.sioyek.sioyek"
local F8 = hs.keycodes.map.f8
local TOGGLE_ITEM_TITLE = "^Toggle custom color mode"

local service = {}

local function toggleCustomColor()
  local application = hs.application.get(SIOYEK_BUNDLE_ID)
  if not application then
    return
  end

  local element = hs.axuielement.applicationElement(application)
  local menuBar = element and element:attributeValue("AXMenuBar")
  if not menuBar then
    return
  end

  local target = nil
  local function find(node, depth)
    if target or depth > 3 then
      return
    end

    local children = node:attributeValue("AXChildren")
    if type(children) ~= "table" then
      return
    end

    for _, child in ipairs(children) do
      local title = child:attributeValue("AXTitle") or ""
      if title:match(TOGGLE_ITEM_TITLE) then
        target = child
      end
      find(child, depth + 1)
    end
  end

  find(menuBar, 0)

  if target then
    target:performAction("AXPress")
  end
end

function service.start()
  service.stop()

  service.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if event:getKeyCode() ~= F8 then
      return false
    end

    local flags = event:getFlags()
    if flags.cmd or flags.alt or flags.ctrl then
      return false
    end

    local application = hs.application.frontmostApplication()
    if not application or application:bundleID() ~= SIOYEK_BUNDLE_ID then
      return false
    end

    -- Deferred: the accessibility walk is too slow to run inside the tap, and a
    -- callback that overruns makes macOS disable the tap for timing out, which
    -- is what lets F8 slip through to the menu on a later press.
    hs.timer.doAfter(0, toggleCustomColor)
    return true
  end)

  service.tap:start()
  return service
end

function service.stop()
  if service.tap then
    service.tap:stop()
    service.tap = nil
  end
end

return service